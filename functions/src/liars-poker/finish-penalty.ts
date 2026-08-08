/* eslint-disable valid-jsdoc */

import {getDatabase} from "firebase-admin/database";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {processedResult, recordCommand} from "./common/commands.js";
import {findNextAlivePlayer} from "./common/next-turn.js";
import {RealtimeRoom} from "./common/types.js";
import {
  assertController,
  assertGameStatus,
  assertPlayerAlive,
  assertPlayerExists,
  assertRoomExists,
  parseCommandId,
  parseRoomCode,
  REGION,
  requireGame,
  requireUid,
} from "./common/validator.js";
import {finishGame} from "./finish-game.js";
import {restartRound} from "./restart-round.js";

type ResolvePenaltyData = {
  roomCode?: unknown;
  commandId?: unknown;
  result?: unknown;
};

/** 아이패드 룰렛이 반환한 생존 또는 탈락 결과를 게임에 반영합니다. */
export const resolveLiarsPokerPenalty = onCall<ResolvePenaltyData>(
  {region: REGION},
  async (request) => {
    const uid = requireUid(request);
    const roomCode = parseRoomCode(request.data?.roomCode);
    const commandId = parseCommandId(request.data?.commandId);
    const result = parseRouletteResult(request.data?.result);
    const roomRef = getDatabase().ref(`rooms/${roomCode}`);
    let response: Record<string, unknown> | null = null;

    const transaction = await roomRef.transaction((rawRoom) => {
      // 원격 데이터가 있어도 트랜잭션 첫 호출에는 null이 올 수 있습니다.
      // null을 그대로 반환하면 서버 값과 동기화된 뒤 다시 호출됩니다.
      if (rawRoom === null) return rawRoom;

      assertRoomExists(rawRoom);
      const room = rawRoom as RealtimeRoom;
      assertController(room, uid);
      const game = requireGame(room);
      const previousResult = processedResult(game, commandId);
      if (previousResult) {
        response = previousResult;
        return room;
      }

      assertGameStatus(game.public.status, "playing");
      if (game.public.phase !== "penalty") {
        throw new HttpsError(
          "failed-precondition",
          "현재 벌칙을 처리할 수 있는 단계가 아닙니다.",
        );
      }
      const targetUid = game.public.penaltyTargetUid;
      if (!targetUid) {
        throw new HttpsError("data-loss", "벌칙 대상이 없습니다.");
      }
      const target = game.public.players[targetUid];
      assertPlayerExists(target);
      assertPlayerAlive(target.status);

      const now = Date.now();
      if (result === "safe") {
        target.penaltyCount += 1;
      } else {
        target.status = "eliminated";
        target.remainingCardCount = 0;
        delete game.private[targetUid];
      }

      const alivePlayers = Object.values(game.public.players).filter(
        (player) => player.status === "alive",
      );
      if (alivePlayers.length === 1) {
        finishGame(game, alivePlayers[0].uid, now);
      } else {
        const starterUid = result === "safe" ? targetUid :
          findNextAlivePlayer(game.public.players, targetUid);
        restartRound(game, starterUid, now);
      }

      response = {
        success: true,
        type: "penaltyResolved",
        commandId,
        result,
        penaltyTargetUid: targetUid,
        status: game.public.status,
        // RTDB에서는 null 필드가 읽을 때 생략되므로 undefined일 수도 있습니다.
        winnerUid: game.public.winnerUid ?? null,
        round: game.public.round,
        turnUid: game.public.turnUid ?? null,
        revision: game.public.revision,
      };
      recordCommand(game, commandId, {
        uid,
        type: "penaltyResolved",
        createdAt: now,
        result: response,
      });
      return room;
    });

    if (!transaction.committed || !response) {
      throw new HttpsError("aborted", "벌칙 결과를 반영하지 못했습니다.");
    }
    return response;
  },
);

/** 프런트 룰렛의 허용된 결과만 반환합니다. */
function parseRouletteResult(value: unknown): "safe" | "eliminated" {
  if (value !== "safe" && value !== "eliminated") {
    throw new HttpsError("invalid-argument", "올바른 룰렛 결과가 아닙니다.");
  }
  return value;
}
