/* eslint-disable linebreak-style */
import {getDatabase} from "firebase-admin/database";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {processedResult, recordCommand} from "./common/commands.js";
import {
  countPlayersWithCards,
  findNextAlivePlayer,
  findNextPlayerWithCards,
} from "./common/next-turn.js";
import {restartRound} from "./restart-round.js";
import {
  LAST_CARD_CHALLENGE_DURATION_MS,
  RealtimeRoom,
  TURN_DURATION_MS,
} from "./common/types.js";
import {
  assertGameStatus,
  assertPlayerAlive,
  assertPlayerExists,
  assertPlayerTurn,
  assertRoomExists,
  parseCardIds,
  parseCommandId,
  parseRoomCode,
  REGION,
  requireGame,
  requireUid,
} from "./common/validator.js";

type SubmitCardsData = {
  roomCode?: unknown;
  commandId?: unknown;
  cardIds?: unknown;
  warmup?: unknown;
};

/** 현재 플레이어의 손패에서 1~3장을 제출합니다. */
export const game_liars_poker_submit_cards = onCall<SubmitCardsData>(
  {region: REGION},
  async (request) => {
    const uid = requireUid(request);
    if (request.data?.warmup === true) {
      return {success: true, type: "warmup"};
    }
    const roomCode = parseRoomCode(request.data?.roomCode);
    const commandId = parseCommandId(request.data?.commandId);
    const cardIds = parseCardIds(request.data?.cardIds);
    const roomRef = getDatabase().ref(`rooms/${roomCode}`);
    let response: Record<string, unknown> | null = null;

    const transaction = await roomRef.transaction((rawRoom) => {
      // 원격 데이터가 있어도 트랜잭션 첫 호출에는 null이 올 수 있습니다.
      // null을 그대로 반환하면 서버 값과 동기화된 뒤 다시 호출됩니다.
      if (rawRoom === null) return rawRoom;

      assertRoomExists(rawRoom);
      const room = rawRoom as RealtimeRoom;
      const game = requireGame(room);
      const previousResult = processedResult(game, commandId);
      if (previousResult) {
        response = previousResult;
        return room;
      }

      assertGameStatus(game.public.status, "playing");
      if (game.public.phase !== "playing") {
        throw new HttpsError(
          "failed-precondition",
          "현재 카드를 제출할 수 있는 단계가 아닙니다.",
        );
      }
      const player = game.public.players[uid];
      assertPlayerExists(player);
      assertPlayerAlive(player.status);
      assertPlayerTurn(game.public.turnUid ?? "", uid);
      if (
        player.remainingCardCount > 0 &&
        countPlayersWithCards(game.public.players) === 1
      ) {
        throw new HttpsError(
          "failed-precondition",
          "잔여카드를 가진 마지막 플레이어는 카드를 제출할 수 없습니다. LIAR 또는 FOLD를 선택해주세요.",
        );
      }

      const privatePlayer = game.private[uid];
      const hand = privatePlayer?.hand;
      if (!hand) {
        throw new HttpsError("data-loss", "플레이어 손패가 없습니다.");
      }
      const submittedCards = cardIds.map((cardId) => hand[cardId]);
      if (submittedCards.some((card) => !card)) {
        throw new HttpsError(
          "failed-precondition",
          "보유하지 않은 카드가 포함되어 있습니다.",
        );
      }

      for (const cardId of cardIds) delete hand[cardId];
      const remainingCardCount = Object.keys(hand).length;
      const now = Date.now();
      player.remainingCardCount = remainingCardCount;

      // 카드를 다 쓴 플레이어는 턴에서 빼고 손패가 남은 사람들끼리 진행합니다.
      // FOLD는 이번 라운드 제출 횟수와 무관하며, 실제 잔여카드를 가진 생존자가
      // 정확히 한 명이 된 순간에만 그 플레이어에게 열립니다.
      const isLastCardChallenge = remainingCardCount === 0 &&
        countPlayersWithCards(game.public.players) === 1;
      const nextTurnUid = findNextPlayerWithCards(game.public.players, uid);

      const lastPlay = {
        playId: commandId,
        round: game.public.round,
        playerUid: uid,
        cardCount: submittedCards.length,
        declaredRank: game.public.table,
        revealed: false,
        submittedAt: now,
      };

      game.public.lastPlay = lastPlay;
      game.public.roundPlays ??= {};
      game.public.roundPlays[lastPlay.playId] = lastPlay;
      game.server.lastPlayCards = submittedCards;

      if (nextTurnUid === null) {
        // 이어서 카드를 낼 사람이 사라진 예외 상태에서는 새 라운드를 엽니다.
        restartRound(game, findNextAlivePlayer(game.public.players, uid), now);
      } else {
        game.public.phase = isLastCardChallenge ?
          "lastCardChallenge" : "playing";
        game.public.turnUid = nextTurnUid;
        game.public.turnDeadlineAt = now +
          (isLastCardChallenge ?
            LAST_CARD_CHALLENGE_DURATION_MS : TURN_DURATION_MS);
        game.public.isFirstTurnReady = true;
        game.public.revision += 1;
        game.public.updatedAt = now;
      }

      response = {
        success: true,
        type: "cardsSubmitted",
        commandId,
        nextTurnUid: game.public.turnUid,
        remainingCardCount,
        phase: game.public.phase,
        revision: game.public.revision,
      };
      recordCommand(game, commandId, {
        uid,
        type: "cardsSubmitted",
        createdAt: now,
        result: response,
      });
      return room;
    });

    if (!transaction.committed || !response) {
      throw new HttpsError("aborted", "카드를 제출하지 못했습니다.");
    }
    return response;
  },
);
