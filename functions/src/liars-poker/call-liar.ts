import {getDatabase} from "firebase-admin/database";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {processedResult, recordCommand} from "./common/commands.js";
import {countPlayersWithCards} from "./common/next-turn.js";
import {RealtimeRoom} from "./common/types.js";
import {
  assertGameStatus,
  assertPlayerAlive,
  assertPlayerExists,
  assertPlayerTurn,
  assertRoomExists,
  parseCommandId,
  parseRoomCode,
  REGION,
  requireGame,
  requireUid,
} from "./common/validator.js";

type CallLiarData = {
  roomCode?: unknown;
  commandId?: unknown;
  warmup?: unknown;
};

/** 현재 플레이어가 직전 제출에 대해 라이어를 선언합니다. */
export const callLiarsPoker = onCall<CallLiarData>(
  {region: REGION},
  async (request) => {
    const uid = requireUid(request);
    if (request.data?.warmup === true) {
      return {success: true, type: "warmup"};
    }
    const roomCode = parseRoomCode(request.data?.roomCode);
    const commandId = parseCommandId(request.data?.commandId);
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
      if (
        game.public.phase !== "playing" &&
        game.public.phase !== "lastCardChallenge"
      ) {
        throw new HttpsError(
          "failed-precondition",
          "현재 라이어를 선언할 수 있는 단계가 아닙니다.",
        );
      }
      const challenger = game.public.players[uid];
      assertPlayerExists(challenger);
      assertPlayerAlive(challenger.status);
      assertPlayerTurn(game.public.turnUid ?? "", uid);
      if (
        game.public.phase === "lastCardChallenge" &&
        (challenger.remainingCardCount <= 0 ||
          countPlayersWithCards(game.public.players) !== 1)
      ) {
        throw new HttpsError(
          "failed-precondition",
          "마지막 미제출 플레이어만 이 선택을 할 수 있습니다.",
        );
      }

      const lastPlay = game.public.lastPlay;
      const actualCards = game.server.lastPlayCards;
      if (!lastPlay || !actualCards || actualCards.length === 0) {
        throw new HttpsError(
          "failed-precondition",
          "라이어를 선언할 직전 제출이 없습니다.",
        );
      }

      const truthful = actualCards.every(
        (card) => card.rank === game.public.table || card.rank === "JOKER",
      );
      const penaltyTargetUid = truthful ? uid : lastPlay.playerUid;
      const alivePlayerCount = Object.values(game.public.players).filter(
        (player) => player.status === "alive",
      ).length;
      // 카드를 가진 사람이 둘만 남은 1대1 상황에서 LIAR 판정에 실패하면 이번
      // 룰렛부터 한 단계 높은 탈락 확률을 적용합니다. FOLD 안내 문구가 이
      // 규칙을 그대로 알리고 있으므로, lastCardChallenge 단계에서도 동일하게
      // 적용해야 안내와 실제 동작이 어긋나지 않습니다.
      const shouldIncreasePenaltyBeforeRoulette =
        (alivePlayerCount === 2 ||
          game.public.phase === "lastCardChallenge") && truthful;
      const now = Date.now();
      const actualRanks = actualCards.map((card) => card.rank);

      // 1대1에서 LIAR 판정에 실패하면 이번 룰렛부터 한 단계 높아진
      // 탈락 확률을 적용합니다. 생존 후에는 중복 증가하지 않습니다.
      if (shouldIncreasePenaltyBeforeRoulette) {
        challenger.penaltyCount += 1;
        game.server.penaltyCountIncrementedBeforeRoulette = true;
      } else {
        delete game.server.penaltyCountIncrementedBeforeRoulette;
      }

      game.public.phase = "penalty";
      game.public.turnUid = null;
      game.public.turnDeadlineAt = null;
      game.public.penaltyTargetUid = penaltyTargetUid;
      delete game.public.penaltyResult;
      const revealedLastPlay = {
        ...lastPlay,
        revealed: true,
        actualRanks,
      };
      game.public.lastPlay = revealedLastPlay;
      game.public.roundPlays ??= {};
      game.public.roundPlays[lastPlay.playId] = revealedLastPlay;
      game.public.revision += 1;
      game.public.updatedAt = now;

      response = {
        success: true,
        type: "liarCalled",
        commandId,
        truthful,
        challengerUid: uid,
        challengedUid: lastPlay.playerUid,
        penaltyTargetUid,
        actualRanks,
        revision: game.public.revision,
      };
      recordCommand(game, commandId, {
        uid,
        type: "liarCalled",
        createdAt: now,
        result: response,
      });
      return room;
    });

    if (!transaction.committed || !response) {
      throw new HttpsError("aborted", "라이어 판정을 처리하지 못했습니다.");
    }
    return response;
  },
);
