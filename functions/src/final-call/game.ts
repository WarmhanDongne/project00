/* eslint-disable valid-jsdoc, max-len, require-jsdoc */

import {randomInt} from "node:crypto";

import {getFirestore} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/v2/https";

import {
  FINAL_CALL_CARDS_PER_PLAYER,
  FINAL_CALL_TURN_MS,
  FinalCallCard,
  FinalCallColor,
  FinalCallGameState,
  FinalCallPlayer,
  FinalCallPrivatePlayer,
  FinalCallRoom,
} from "./types.js";

const COLORS: FinalCallColor[] = ["red", "blue", "yellow", "green"];

/** 4색 1~10 총 40장의 덱을 섞어서 반환합니다. */
export function createFinalCallDeck(): FinalCallCard[] {
  const deck: FinalCallCard[] = [];
  for (const color of COLORS) {
    for (let value = 1; value <= 10; value += 1) {
      deck.push({id: `${color}_${value}`, color, value});
    }
  }
  for (let index = deck.length - 1; index > 0; index -= 1) {
    const swapIndex = randomInt(index + 1);
    [deck[index], deck[swapIndex]] = [deck[swapIndex], deck[index]];
  }
  return deck;
}

/** 로비 참가자를 Final Call 공개 플레이어로 변환합니다. */
export async function createFinalCallPlayers(
  roomPlayers: FinalCallRoom["players"],
): Promise<Record<string, FinalCallPlayer>> {
  if (!roomPlayers) {
    throw new HttpsError("failed-precondition", "참가 플레이어가 없습니다.");
  }

  const profileUrls = new Map<string, string>();
  await Promise.all(Object.entries(roomPlayers).map(async ([uid, value]) => {
    const roomUrl = typeof value.profileImageUrl === "string" ?
      value.profileImageUrl.trim() : "";
    if (roomUrl) {
      profileUrls.set(uid, roomUrl);
      return;
    }
    try {
      const snapshot = await getFirestore().collection("users").doc(uid).get();
      const url = snapshot.data()?.profileImageUrl;
      if (typeof url === "string") profileUrls.set(uid, url.trim());
    } catch (error) {
      console.warn("Final Call profile lookup failed", error);
    }
  }));

  const players: Record<string, FinalCallPlayer> = {};
  for (const [uid, value] of Object.entries(roomPlayers)) {
    if (value.role !== "player" || value.status !== "active") continue;
    if (!Number.isInteger(value.seatIndex)) {
      throw new HttpsError(
        "failed-precondition",
        "모든 플레이어의 자리를 먼저 지정해주세요.",
      );
    }
    players[uid] = {
      uid,
      nickname: typeof value.nickname === "string" ? value.nickname : "Player",
      profileImageUrl: profileUrls.get(uid) ?? "",
      seatIndex: value.seatIndex as number,
      status: "alive",
      lives: 3,
    };
  }
  assertValidSeats(players);
  return players;
}

/** 새 라운드의 손패, 덱, 공개 카드를 생성합니다. */
export function prepareFinalCallRound(
  game: FinalCallGameState,
  starterUid: string,
  round: number,
  now: number,
): void {
  const deck = createFinalCallDeck();
  const pendingHands: Record<string, FinalCallPrivatePlayer> = {};
  for (const player of orderedAlivePlayers(game.public.players)) {
    const hand: Record<string, FinalCallCard> = {};
    for (let count = 0; count < FINAL_CALL_CARDS_PER_PLAYER; count += 1) {
      const card = deck.pop();
      if (!card) throw new Error("Final Call 덱이 부족합니다.");
      hand[card.id] = card;
    }
    pendingHands[player.uid] = {hand};
  }
  const discardCard = deck.pop();
  if (!discardCard) throw new Error("Final Call 공개 카드가 없습니다.");

  game.public.phase = "dealing";
  game.public.round = round;
  game.public.turnUid = starterUid;
  game.public.turnDeadlineAt = null;
  game.public.callerUid = null;
  game.public.deckRemainingCount = deck.length;
  game.public.discardCard = discardCard;
  game.public.pendingDrawUid = null;
  game.public.pendingDrawSource = null;
  game.public.finalTurnPendingUids = [];
  delete game.public.roundResult;
  delete game.public.resultRevealCompletedAt;
  game.public.revision += 1;
  game.public.updatedAt = now;
  game.private = {};
  game.server.deck = deck;
  game.server.pendingHands = pendingHands;
  game.server.finalSubmissions = {};
  game.server.roundStarterUid = starterUid;
}

/** 손패의 같은 색 합과 같은 숫자 합 중 높은 점수를 계산합니다. */
export function calculateFinalCallScore(cards: FinalCallCard[]): number {
  const colorTotals = new Map<FinalCallColor, number>();
  const valueTotals = new Map<number, number>();
  for (const card of cards) {
    colorTotals.set(card.color, (colorTotals.get(card.color) ?? 0) + card.value);
    valueTotals.set(card.value, (valueTotals.get(card.value) ?? 0) + card.value);
  }
  return Math.max(0, ...colorTotals.values(), ...valueTotals.values());
}

/** 제한 시간 종료 시 자동 제출할 수 있는 가장 높은 점수 조합을 반환합니다. */
export function selectBestFinalCallCombination(
  cards: FinalCallCard[],
): FinalCallCard[] {
  if (cards.length === 0) return [];

  const candidates: FinalCallCard[][] = [];
  for (const color of COLORS) {
    const sameColor = cards.filter((card) => card.color === color);
    if (sameColor.length > 0) candidates.push(sameColor);
  }

  const values = [...new Set(cards.map((card) => card.value))]
    .sort((left, right) => right - left);
  for (const value of values) {
    candidates.push(cards.filter((card) => card.value === value));
  }

  candidates.sort((left, right) => {
    const scoreDifference = calculateFinalCallScore(right) -
      calculateFinalCallScore(left);
    if (scoreDifference !== 0) return scoreDifference;
    return right.length - left.length;
  });
  return candidates[0];
}

/** 라운드를 판정하고 생명, 탈락, 승리 상태를 갱신합니다. */
export function resolveFinalCallRound(
  game: FinalCallGameState,
  now: number,
  automaticCall: boolean,
): void {
  const revealedHands: Record<string, FinalCallCard[]> = {};
  const scores: Record<string, number> = {};
  for (const player of orderedAlivePlayers(game.public.players)) {
    const fullHand = Object.values(game.private[player.uid]?.hand ?? {});
    const submitted = automaticCall ?
      selectBestFinalCallCombination(fullHand) :
      game.server.finalSubmissions?.[player.uid];
    if (!submitted || submitted.length === 0) {
      throw new Error(`${player.uid}의 최종 제출 카드를 찾을 수 없습니다.`);
    }
    // 일반 CALL은 플레이어가 직접 고른 카드만, 덱 소진 자동 CALL은 서버가
    // 고른 최고 조합만 공개합니다. 제출하지 않은 손패는 공개 데이터에 넣지
    // 않으므로 태블릿에서도 계속 비공개 상태로 유지됩니다.
    const cards = submitted;
    revealedHands[player.uid] = cards;
    scores[player.uid] = calculateFinalCallScore(cards);
  }

  const lowestScore = Math.min(...Object.values(scores));
  const lowestUids = Object.keys(scores).filter((uid) => scores[uid] === lowestScore);
  const lifeLosses: Record<string, number> = {};
  for (const uid of lowestUids) {
    const loss = !automaticCall && game.public.callerUid === uid ? 2 : 1;
    lifeLosses[uid] = loss;
    const player = game.public.players[uid];
    player.lives = Math.max(0, player.lives - loss);
    if (player.lives === 0) player.status = "eliminated";
  }

  game.public.roundResult = {
    scores,
    lifeLosses,
    lowestUids,
    revealedHands,
    callerUid: automaticCall ? null : game.public.callerUid,
    automaticCall,
    resolvedAt: now,
  };
  delete game.public.resultRevealCompletedAt;
  game.public.turnUid = null;
  game.public.turnDeadlineAt = null;
  game.public.pendingDrawUid = null;
  game.public.pendingDrawSource = null;
  game.public.finalTurnPendingUids = [];
  game.public.revision += 1;
  game.public.updatedAt = now;

  const alive = orderedAlivePlayers(game.public.players);
  if (alive.length === 1) {
    game.public.status = "finished";
    game.public.phase = "finished";
    game.public.winnerUid = alive[0].uid;
    game.public.finishedAt = now;
  } else {
    game.public.phase = "roundResult";
  }
}

/** 좌석 순서의 다음 생존 플레이어를 반환합니다. */
export function nextFinalCallPlayer(
  players: Record<string, FinalCallPlayer>,
  currentUid: string,
  allowedUids?: Set<string>,
): string {
  const ordered = orderedAlivePlayers(players);
  const currentIndex = ordered.findIndex((player) => player.uid === currentUid);
  if (currentIndex < 0) throw new Error("현재 플레이어를 찾을 수 없습니다.");
  for (let offset = 1; offset <= ordered.length; offset += 1) {
    const candidate = ordered[(currentIndex + offset) % ordered.length];
    if (!allowedUids || allowedUids.has(candidate.uid)) return candidate.uid;
  }
  return currentUid;
}

export function orderedAlivePlayers(
  players: Record<string, FinalCallPlayer>,
): FinalCallPlayer[] {
  return Object.values(players)
    .filter((player) => player.status === "alive")
    .sort((left, right) => left.seatIndex - right.seatIndex);
}

/**
 * RTDB는 빈 배열을 저장하면 해당 경로를 제거할 수 있으므로, 누락된 최종 턴
 * 대기 목록도 빈 목록으로 취급합니다.
 */
export function removeFinalTurnPendingPlayer(
  pendingUids: readonly string[] | undefined,
  uid: string,
): string[] {
  return (pendingUids ?? []).filter((playerUid) => playerUid !== uid);
}

function assertValidSeats(players: Record<string, FinalCallPlayer>): void {
  const seats = Object.values(players).map((player) => player.seatIndex);
  const valid = seats.length >= 2 && seats.length <= 4 &&
    new Set(seats).size === seats.length &&
    seats.every((seat) => seat >= 0 && seat < seats.length);
  if (!valid) {
    throw new HttpsError(
      "failed-precondition",
      "Final Call은 2~4명의 자리를 중복 없이 지정해야 합니다.",
    );
  }
}

/** 첫 라운드 상태를 생성합니다. */
export function createInitialFinalCallGame(
  players: Record<string, FinalCallPlayer>,
  now: number,
): FinalCallGameState {
  const ordered = orderedAlivePlayers(players);
  const starter = ordered[randomInt(ordered.length)];
  const placeholder: FinalCallCard = {id: "placeholder", color: "red", value: 1};
  const game: FinalCallGameState = {
    public: {
      gameType: "final_call",
      status: "playing",
      phase: "dealing",
      round: 0,
      revision: 0,
      turnUid: starter.uid,
      turnDeadlineAt: null,
      callerUid: null,
      deckRemainingCount: 0,
      discardCard: placeholder,
      pendingDrawUid: null,
      pendingDrawSource: null,
      finalTurnPendingUids: [],
      players,
      winnerUid: null,
      startedAt: now,
      updatedAt: now,
    },
    private: {},
    server: {
      deck: [],
      finalSubmissions: {},
      processedCommands: {},
      roundStarterUid: starter.uid,
    },
  };
  prepareFinalCallRound(game, starter.uid, 1, now);
  return game;
}

export function startTurn(game: FinalCallGameState, uid: string, now: number): void {
  game.public.turnUid = uid;
  game.public.turnDeadlineAt = now + FINAL_CALL_TURN_MS;
  game.public.updatedAt = now;
}
