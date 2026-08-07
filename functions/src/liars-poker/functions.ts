/* eslint-disable valid-jsdoc */
import { randomInt } from "node:crypto";

import {
  CallableRequest,
  HttpsError,
  onCall,
} from "firebase-functions/v2/https";
import {
  FieldValue,
  getFirestore,
  Transaction,
} from "firebase-admin/firestore";

import {
  CARDS_PER_PLAYER,
  createShuffledDeck,
  isTruthfulPlay,
  MAX_PLAYERS,
  MIN_PLAYERS,
  nextActivePlayerId,
  randomTableRank,
} from "./rules.js";
import {
  LIARS_POKER_GAME_IDS,
  LIARS_POKER_RANKS,
  LiarsPokerCard,
  LiarsPokerPlayer,
  LiarsPokerRank,
  PublicPlay,
} from "./types.js";

const REGION = "asia-northeast3";

type PlayerSeatInput = {
  uid?: unknown;
  seatIndex?: unknown;
};

type StartMatchData = {
  roomCode?: unknown;
  playerSeats?: unknown;
};

type MatchActionData = {
  roomCode?: unknown;
  matchId?: unknown;
  actionId?: unknown;
};

type SubmitCardsData = MatchActionData & {
  cardIds?: unknown;
};

/** 인증된 호출자의 UID를 반환합니다. */
function requireUid(request: CallableRequest<unknown>): string {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
  }
  return uid;
}

/** 방 코드를 정규화하고 검증합니다. */
function parseRoomCode(value: unknown): string {
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", "방 코드가 필요합니다.");
  }
  const roomCode = value.trim().toUpperCase();
  if (!/^[A-Z0-9]{5}$/.test(roomCode)) {
    throw new HttpsError("invalid-argument", "올바른 방 코드가 아닙니다.");
  }
  return roomCode;
}

/** Firestore 문서 및 액션 식별자를 검증합니다. */
function parseId(value: unknown, fieldName: string): string {
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", `${fieldName} 값이 필요합니다.`);
  }
  const id = value.trim();
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(id)) {
    throw new HttpsError(
      "invalid-argument",
      `${fieldName} 값이 올바르지 않습니다.`,
    );
  }
  return id;
}

/** 한 턴에 제출하는 1~3개의 카드 ID를 검증합니다. */
function parseCardIds(value: unknown): string[] {
  if (!Array.isArray(value) || value.length < 1 || value.length > 3) {
    throw new HttpsError(
      "invalid-argument",
      "카드는 한 번에 1~3장 제출해야 합니다.",
    );
  }

  const cardIds = value.map((cardId) => parseId(cardId, "cardId"));
  if (new Set(cardIds).size !== cardIds.length) {
    throw new HttpsError(
      "invalid-argument",
      "같은 카드를 중복 제출할 수 없습니다.",
    );
  }
  return cardIds;
}

/** 매치 문서의 공개 플레이어 목록을 읽습니다. */
function parsePlayers(value: unknown): LiarsPokerPlayer[] {
  if (!Array.isArray(value)) {
    throw new HttpsError("data-loss", "플레이어 정보가 없습니다.");
  }
  return value as LiarsPokerPlayer[];
}

/** 매치 문서의 테이블 랭크를 검증합니다. */
function parseTableRank(value: unknown): LiarsPokerRank {
  if (
    typeof value === "string" &&
    LIARS_POKER_RANKS.includes(value as LiarsPokerRank)
  ) {
    return value as LiarsPokerRank;
  }
  throw new HttpsError("data-loss", "테이블 카드 정보가 없습니다.");
}

/** 클라이언트가 전달한 좌석을 참가자 UID와 대조합니다. */
function parsePlayerSeats(
  value: unknown,
  playerIds: string[],
): Map<string, number> {
  if (value === undefined || value === null) {
    return new Map(playerIds.map((uid, index) => [uid, index]));
  }
  if (!Array.isArray(value) || value.length !== playerIds.length) {
    throw new HttpsError(
      "invalid-argument",
      "플레이어 수와 좌석 정보 수가 같아야 합니다.",
    );
  }

  const seats = new Map<string, number>();
  for (const rawSeat of value as PlayerSeatInput[]) {
    if (
      typeof rawSeat !== "object" ||
      rawSeat === null ||
      typeof rawSeat.uid !== "string" ||
      !Number.isInteger(rawSeat.seatIndex)
    ) {
      throw new HttpsError(
        "invalid-argument",
        "플레이어 좌석 정보가 올바르지 않습니다.",
      );
    }
    seats.set(rawSeat.uid, rawSeat.seatIndex as number);
  }

  const playerIdSet = new Set(playerIds);
  const seatIndexes = [...seats.values()];
  const validPlayers =
    seats.size === playerIds.length &&
    [...seats.keys()].every((uid) => playerIdSet.has(uid));
  const validSeats =
    new Set(seatIndexes).size === playerIds.length &&
    seatIndexes.every((seat) => seat >= 0 && seat < playerIds.length);
  if (!validPlayers || !validSeats) {
    throw new HttpsError(
      "invalid-argument",
      "좌석은 참가 플레이어마다 중복 없이 지정해야 합니다.",
    );
  }
  return seats;
}

export const startLiarsPokerMatch = onCall<StartMatchData>(
  { region: REGION },
  async (request: CallableRequest<StartMatchData>) => {
    const uid = requireUid(request);
    const roomCode = parseRoomCode(request.data?.roomCode);
    const db = getFirestore();
    const roomRef = db.collection("rooms").doc(roomCode);
    const playersQuery = roomRef.collection("players").orderBy("joinedAt");
    const matchRef = roomRef.collection("matches").doc();

    await db.runTransaction(async (transaction: Transaction) => {
      const roomSnapshot = await transaction.get(roomRef);
      const playerSnapshot = await transaction.get(playersQuery);

      if (!roomSnapshot.exists) {
        throw new HttpsError("not-found", "방을 찾을 수 없습니다.");
      }
      const room = roomSnapshot.data();
      if (!room) {
        throw new HttpsError("data-loss", "방 정보를 읽을 수 없습니다.");
      }
      if (room.hostUid !== uid) {
        throw new HttpsError(
          "permission-denied",
          "방장만 게임을 시작할 수 있습니다.",
        );
      }
      if (room.status !== "waiting") {
        throw new HttpsError(
          "failed-precondition",
          "이미 게임이 진행 중입니다.",
        );
      }
      if (!LIARS_POKER_GAME_IDS.has(room.selectedGameId)) {
        throw new HttpsError(
          "failed-precondition",
          "라이어스 포커 게임이 선택되지 않았습니다.",
        );
      }

      const activePlayers = playerSnapshot.docs.filter((document: any) => {
        const player = document.data();
        return player.status === "active" && player.role === "player";
      });
      if (
        activePlayers.length < MIN_PLAYERS ||
        activePlayers.length > MAX_PLAYERS
      ) {
        throw new HttpsError(
          "failed-precondition",
          `플레이어는 ${MIN_PLAYERS}~${MAX_PLAYERS}명이어야 합니다.`,
        );
      }

      const playerIds = activePlayers.map((player: any) => player.id);
      const seats = parsePlayerSeats(request.data?.playerSeats, playerIds);
      const players: LiarsPokerPlayer[] = activePlayers.map((player: any) => {
        const data = player.data();
        const seatIndex = seats.get(player.id);
        if (seatIndex === undefined) {
          throw new HttpsError(
            "data-loss",
            "플레이어 좌석 정보를 찾을 수 없습니다.",
          );
        }
        return {
          uid: player.id,
          nickname:
            typeof data.nickname === "string" ? data.nickname : "사용자",
          profileImageUrl:
            typeof data.profileImageUrl === "string"
              ? data.profileImageUrl
              : "",
          seatIndex,
          remainingCardCount: CARDS_PER_PLAYER,
          eliminated: false,
        };
      });

      const deck = createShuffledDeck(players.length);
      const tableRank = randomTableRank();
      const firstPlayer = players[randomInt(players.length)];

      for (let index = 0; index < players.length; index += 1) {
        const hand = deck.slice(
          index * CARDS_PER_PLAYER,
          (index + 1) * CARDS_PER_PLAYER,
        );
        transaction.set(matchRef.collection("hands").doc(players[index].uid), {
          uid: players[index].uid,
          cards: hand,
          updatedAt: FieldValue.serverTimestamp(),
        });
      }

      transaction.set(matchRef, {
        gameId: "liars_poker",
        status: "playing",
        phase: "playing",
        round: 1,
        turnNumber: 1,
        version: 1,
        currentPlayerId: firstPlayer.uid,
        previousPlayerId: null,
        tableCard: tableRank,
        players,
        lastPlay: null,
        challenge: null,
        penaltyPlayerId: null,
        winnerId: null,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.set(matchRef.collection("events").doc(), {
        type: "matchStarted",
        playerId: firstPlayer.uid,
        round: 1,
        createdAt: FieldValue.serverTimestamp(),
      });
      transaction.update(roomRef, {
        currentMatchId: matchRef.id,
        status: "playing",
        updatedAt: FieldValue.serverTimestamp(),
      });
    });

    return { success: true, roomCode, matchId: matchRef.id };
  },
);

export const submitLiarsPokerCards = onCall<SubmitCardsData>(
  { region: REGION },
  async (request: CallableRequest<SubmitCardsData>) => {
    const uid = requireUid(request);
    const roomCode = parseRoomCode(request.data?.roomCode);
    const matchId = parseId(request.data?.matchId, "matchId");
    const actionId = parseId(request.data?.actionId, "actionId");
    const cardIds = parseCardIds(request.data?.cardIds);
    const db = getFirestore();
    const matchRef = db
      .collection("rooms")
      .doc(roomCode)
      .collection("matches")
      .doc(matchId);
    const handRef = matchRef.collection("hands").doc(uid);
    const actionRef = matchRef.collection("processedActions").doc(actionId);

    const result = await db.runTransaction(async (transaction: Transaction) => {
      const matchSnapshot = await transaction.get(matchRef);
      const handSnapshot = await transaction.get(handRef);
      const actionSnapshot = await transaction.get(actionRef);
      if (actionSnapshot.exists) {
        return actionSnapshot.data();
      }
      if (!matchSnapshot.exists || !handSnapshot.exists) {
        throw new HttpsError("not-found", "진행 중인 게임을 찾을 수 없습니다.");
      }

      const match = matchSnapshot.data();
      if (!match) {
        throw new HttpsError("data-loss", "게임 정보를 읽을 수 없습니다.");
      }
      if (match.status !== "playing" || match.phase !== "playing") {
        throw new HttpsError(
          "failed-precondition",
          "현재 카드를 제출할 수 없는 상태입니다.",
        );
      }
      if (match.currentPlayerId !== uid) {
        throw new HttpsError(
          "permission-denied",
          "현재 플레이어의 턴이 아닙니다.",
        );
      }

      const players = parsePlayers(match.players);
      const hand = handSnapshot.get("cards") as LiarsPokerCard[];
      const cardsById = new Map(hand.map((card) => [card.id, card]));
      const submittedCards = cardIds.map((cardId) => cardsById.get(cardId));
      if (submittedCards.some((card) => card === undefined)) {
        throw new HttpsError(
          "failed-precondition",
          "보유하지 않은 카드가 포함되어 있습니다.",
        );
      }
      const actualCards = submittedCards as LiarsPokerCard[];
      const remainingCards = hand.filter((card) => !cardIds.includes(card.id));
      const nextPlayerId = nextActivePlayerId(players, uid);
      const tableRank = parseTableRank(match.tableCard);
      const round = typeof match.round === "number" ? match.round : 1;
      const publicPlay: PublicPlay = {
        playId: actionId,
        playerId: uid,
        cardCount: actualCards.length,
        declaredRank: tableRank,
        revealed: false,
      };
      const updatedPlayers = players.map((player) =>
        player.uid === uid
          ? { ...player, remainingCardCount: remainingCards.length }
          : player,
      );
      const roundRef = matchRef.collection("rounds").doc(String(round));
      const publicPlayRef = roundRef.collection("plays").doc(actionId);
      const secretPlayRef = roundRef.collection("secretPlays").doc(actionId);
      const eventRef = matchRef.collection("events").doc();
      const actionResult = {
        success: true,
        type: "cardsSubmitted",
        actionId,
        nextPlayerId,
      };

      transaction.update(handRef, {
        cards: remainingCards,
        updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.set(publicPlayRef, {
        ...publicPlay,
        createdAt: FieldValue.serverTimestamp(),
      });
      transaction.set(secretPlayRef, {
        playerId: uid,
        cards: actualCards,
        createdAt: FieldValue.serverTimestamp(),
      });
      transaction.update(matchRef, {
        players: updatedPlayers,
        previousPlayerId: uid,
        currentPlayerId: nextPlayerId,
        lastPlay: publicPlay,
        turnNumber: FieldValue.increment(1),
        version: FieldValue.increment(1),
        updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.set(eventRef, {
        type: "cardsSubmitted",
        playerId: uid,
        cardCount: actualCards.length,
        nextPlayerId,
        createdAt: FieldValue.serverTimestamp(),
      });
      transaction.set(actionRef, {
        uid,
        ...actionResult,
        createdAt: FieldValue.serverTimestamp(),
      });
      return actionResult;
    });

    return result;
  },
);

export const challengeLiarsPoker = onCall<MatchActionData>(
  { region: REGION },
  async (request: CallableRequest<MatchActionData>) => {
    const uid = requireUid(request);
    const roomCode = parseRoomCode(request.data?.roomCode);
    const matchId = parseId(request.data?.matchId, "matchId");
    const actionId = parseId(request.data?.actionId, "actionId");
    const db = getFirestore();
    const matchRef = db
      .collection("rooms")
      .doc(roomCode)
      .collection("matches")
      .doc(matchId);
    const actionRef = matchRef.collection("processedActions").doc(actionId);

    const result = await db.runTransaction(async (transaction: Transaction) => {
      const matchSnapshot = await transaction.get(matchRef);
      const actionSnapshot = await transaction.get(actionRef);
      if (actionSnapshot.exists) return actionSnapshot.data();
      if (!matchSnapshot.exists) {
        throw new HttpsError("not-found", "진행 중인 게임을 찾을 수 없습니다.");
      }

      const match = matchSnapshot.data();
      if (!match) {
        throw new HttpsError("data-loss", "게임 정보를 읽을 수 없습니다.");
      }
      if (match.status !== "playing" || match.phase !== "playing") {
        throw new HttpsError(
          "failed-precondition",
          "현재 라이어를 선언할 수 없는 상태입니다.",
        );
      }
      if (match.currentPlayerId !== uid) {
        throw new HttpsError(
          "permission-denied",
          "현재 플레이어의 턴이 아닙니다.",
        );
      }

      const lastPlay = match.lastPlay as PublicPlay | null;
      if (!lastPlay || !match.previousPlayerId) {
        throw new HttpsError(
          "failed-precondition",
          "의심할 수 있는 직전 제출이 없습니다.",
        );
      }
      const round = typeof match.round === "number" ? match.round : 1;
      const roundRef = matchRef.collection("rounds").doc(String(round));
      const secretPlayRef = roundRef
        .collection("secretPlays")
        .doc(lastPlay.playId);
      const publicPlayRef = roundRef.collection("plays").doc(lastPlay.playId);
      const secretSnapshot = await transaction.get(secretPlayRef);
      if (!secretSnapshot.exists) {
        throw new HttpsError("data-loss", "제출 카드 정보를 찾을 수 없습니다.");
      }

      const cards = secretSnapshot.get("cards") as LiarsPokerCard[];
      const tableRank = parseTableRank(match.tableCard);
      const truthful = isTruthfulPlay(cards, tableRank);
      const challengedPlayerId = match.previousPlayerId as string;
      const loserId = truthful ? uid : challengedPlayerId;
      const actualRanks = cards.map((card) => card.rank);
      const challenge = {
        challengerId: uid,
        challengedPlayerId,
        loserId,
        truthful,
        actualRanks,
      };
      const penaltyRef = roundRef.collection("penalties").doc(actionId);
      const eventRef = matchRef.collection("events").doc();
      const actionResult = {
        success: true,
        type: "liarChallenged",
        actionId,
        loserId,
        truthful,
        actualRanks,
      };

      transaction.update(publicPlayRef, {
        revealed: true,
        actualRanks,
        updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.set(penaltyRef, {
        ...challenge,
        status: "pending",
        createdAt: FieldValue.serverTimestamp(),
      });
      transaction.update(matchRef, {
        phase: "penalty",
        challenge,
        penaltyPlayerId: loserId,
        lastPlay: { ...lastPlay, revealed: true, actualRanks },
        version: FieldValue.increment(1),
        updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.set(eventRef, {
        type: "liarChallenged",
        ...challenge,
        createdAt: FieldValue.serverTimestamp(),
      });
      transaction.set(actionRef, {
        uid,
        ...actionResult,
        createdAt: FieldValue.serverTimestamp(),
      });
      return actionResult;
    });

    return result;
  },
);
