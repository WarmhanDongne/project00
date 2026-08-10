import {getDatabase} from "firebase-admin/database";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {processedResult, recordCommand} from "./common/commands.js";
import {findNextAlivePlayer} from "./common/next-turn.js";
import {RealtimeRoom} from "./common/types.js";
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
export const submitLiarsPokerCards = onCall<SubmitCardsData>(
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
      const nextTurnUid = findNextAlivePlayer(game.public.players, uid);
      const now = Date.now();
      const lastPlay = {
        playId: commandId,
        round: game.public.round,
        playerUid: uid,
        cardCount: submittedCards.length,
        declaredRank: game.public.table,
        revealed: false,
        submittedAt: now,
      };

      player.remainingCardCount = remainingCardCount;
      game.public.phase = remainingCardCount === 0 ?
        "lastCardChallenge" : "playing";
      game.public.turnUid = nextTurnUid;
      game.public.lastPlay = lastPlay;
      game.public.roundPlays ??= {};
      game.public.roundPlays[lastPlay.playId] = lastPlay;
      game.public.revision += 1;
      game.public.updatedAt = now;
      game.server.lastPlayCards = submittedCards;

      response = {
        success: true,
        type: "cardsSubmitted",
        commandId,
        nextTurnUid,
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
