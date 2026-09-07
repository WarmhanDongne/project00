/* eslint-disable valid-jsdoc */

import {randomInt} from "node:crypto";

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
  controllerSessionId?: unknown;
  commandId?: unknown;
  resolutionId?: unknown;
};

type PreparePenaltyData = {
  roomCode?: unknown;
  controllerSessionId?: unknown;
  commandId?: unknown;
};

/** 서버가 벌칙 결과를 먼저 추첨하고 태블릿 연출 완료까지 보관합니다. */
export const game_liars_poker_prepare_penalty = onCall<PreparePenaltyData>(
  {region: REGION},
  async (request) => {
    const uid = requireUid(request);
    const roomCode = parseRoomCode(request.data?.roomCode);
    const commandId = parseCommandId(request.data?.commandId);
    const roomRef = getDatabase().ref(`rooms/${roomCode}`);
    let response: Record<string, unknown> | null = null;

    const transaction = await roomRef.transaction((rawRoom) => {
      if (rawRoom === null) return rawRoom;
      assertRoomExists(rawRoom);
      const room = rawRoom as RealtimeRoom;
      assertController(room, uid, request.data?.controllerSessionId);
      const game = requireGame(room);
      assertGameStatus(game.public.status, "playing");
      if (game.public.phase !== "penalty") {
        throw new HttpsError(
          "failed-precondition",
          "현재 벌칙을 추첨할 수 있는 단계가 아닙니다.",
        );
      }
      const targetUid = game.public.penaltyTargetUid;
      if (!targetUid) throw new HttpsError("data-loss", "벌칙 대상이 없습니다.");
      const target = game.public.players[targetUid];
      assertPlayerExists(target);
      assertPlayerAlive(target.status);

      // 네트워크 응답을 잃고 새 commandId로 다시 요청해도 이미 뽑은 값을
      // 재사용합니다. 같은 벌칙에서 원하는 결과가 나올 때까지 재추첨할 수 없습니다.
      const pending = game.server.pendingPenaltyResolution;
      if (pending && pending.targetUid === targetUid) {
        response = {
          success: true,
          resolutionId: pending.resolutionId,
          result: pending.result,
        };
        return room;
      }

      const result = drawPenaltyResult(target.penaltyCount);
      game.server.pendingPenaltyResolution = {
        resolutionId: commandId,
        targetUid,
        result,
        createdAt: Date.now(),
      };
      response = {success: true, resolutionId: commandId, result};
      return room;
    });

    if (!transaction.committed || !response) {
      throw new HttpsError("aborted", "벌칙 결과를 추첨하지 못했습니다.");
    }
    return response;
  },
);

/** 태블릿 룰렛 연출이 끝난 뒤 서버가 보관한 결과를 게임에 반영합니다. */
export const game_liars_poker_resolve_penalty = onCall<ResolvePenaltyData>(
  {region: REGION},
  async (request) => {
    const uid = requireUid(request);
    const roomCode = parseRoomCode(request.data?.roomCode);
    const commandId = parseCommandId(request.data?.commandId);
    const resolutionId = parseCommandId(request.data?.resolutionId);
    if (resolutionId !== commandId) {
      throw new HttpsError("invalid-argument", "벌칙 처리 식별자가 일치하지 않습니다.");
    }
    const roomRef = getDatabase().ref(`rooms/${roomCode}`);
    let response: Record<string, unknown> | null = null;

    const transaction = await roomRef.transaction((rawRoom) => {
      // 원격 데이터가 있어도 트랜잭션 첫 호출에는 null이 올 수 있습니다.
      // null을 그대로 반환하면 서버 값과 동기화된 뒤 다시 호출됩니다.
      if (rawRoom === null) return rawRoom;

      assertRoomExists(rawRoom);
      const room = rawRoom as RealtimeRoom;
      assertController(room, uid, request.data?.controllerSessionId);
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
      const pending = game.server.pendingPenaltyResolution;
      if (
        !pending ||
        pending.resolutionId !== resolutionId ||
        pending.targetUid !== targetUid
      ) {
        throw new HttpsError(
          "failed-precondition",
          "서버에서 추첨한 벌칙 결과가 없습니다. 다시 추첨해주세요.",
        );
      }
      const result = pending.result;

      const now = Date.now();
      if (result === "safe") {
        if (game.server.penaltyCountIncrementedBeforeRoulette !== true) {
          target.penaltyCount += 1;
        }
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
      // 새 라운드나 승리 상태로 전환된 뒤에도 모든 휴대폰이 룰렛 결과를
      // 동일하게 표시할 수 있도록 공개 결과를 잠시 보존합니다.
      game.public.penaltyResult = {
        targetUid,
        result,
        resolvedAt: now,
      };
      delete game.server.penaltyCountIncrementedBeforeRoulette;
      delete game.server.pendingPenaltyResolution;

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

/** 화면의 룰렛 칸 비율과 같은 서버 확률로 결과를 뽑습니다. */
export function drawPenaltyResult(
  attemptCount: number,
  nextInt: (maxExclusive: number) => number = randomInt,
): "safe" | "eliminated" {
  const [eliminatedSections, totalSections] = attemptCount <= 0 ?
    [4, 16] : attemptCount === 1 ? [5, 15] : [11, 12];
  return nextInt(totalSections) < eliminatedSections ? "eliminated" : "safe";
}
