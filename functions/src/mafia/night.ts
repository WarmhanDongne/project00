/* eslint-disable max-len, valid-jsdoc, require-jsdoc */

import {getDatabase} from "firebase-admin/database";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {mafiaProcessed, recordMafiaCommand} from "./commands.js";
import {resolveMafiaNight} from "./game.js";
import {mafiaRole} from "./roles.js";
import {MafiaGameState, MafiaRoom} from "./types.js";
import {
  assertMafiaAlive,
  assertMafiaController,
  assertMafiaPhase,
  MAFIA_REGION,
  mafiaCommandId,
  mafiaRoomCode,
  mafiaTargetUid,
  mafiaUid,
  requireMafiaGame,
} from "./validation.js";

/**
 * 고른 대상이 규칙에 맞는지 확인합니다.
 *
 * 역할 이름으로 분기하지 않고 행동 종류와 진영만 봅니다.
 */
function assertValidNightTarget(
  game: MafiaGameState,
  actorUid: string,
  targetUid: string,
): void {
  const role = mafiaRole(game.server.roles[actorUid]);
  if (!role || role.nightAction === "none") {
    throw new HttpsError("failed-precondition", "밤에 할 수 있는 행동이 없습니다.");
  }
  if (game.public.players[targetUid]?.status !== "alive") {
    throw new HttpsError("failed-precondition", "살아 있는 대상만 고를 수 있습니다.");
  }

  // 보호는 자기 자신도 고를 수 있습니다(의사 자가 치료 허용 — 미확정 규칙).
  if (targetUid === actorUid && role.nightAction !== "protect") {
    throw new HttpsError("failed-precondition", "자신을 고를 수 없습니다.");
  }

  // 같은 편을 제거 대상으로 고를 수 없습니다.
  if (role.nightAction === "eliminate") {
    const targetFaction = mafiaRole(game.server.roles[targetUid])?.faction;
    if (targetFaction === role.faction) {
      throw new HttpsError("failed-precondition", "같은 편을 고를 수 없습니다.");
    }
  }
}

/** 서로를 아는 동료들에게 내 선택을 복사합니다(마피아 실시간 공유). */
function shareSelectionWithAllies(
  game: MafiaGameState,
  actorUid: string,
  targetUid: string,
): void {
  const allies = game.private[actorUid]?.allyUids ?? [];
  for (const allyUid of allies) {
    const allyPrivate = game.private[allyUid];
    if (!allyPrivate) continue;
    allyPrivate.allySelections ??= {};
    allyPrivate.allySelections[actorUid] = targetUid;
  }
}

type SubmitData = {
  roomCode?: unknown;
  commandId?: unknown;
  targetUid?: unknown;
};

/**
 * 밤 행동 대상을 제출합니다(시안 P2~P4).
 *
 * 마감 전에는 여러 번 불러 바꿀 수 있습니다. 그래서 제출 인원은 세어 두는 값이
 * 아니라 **실제 제출 목록의 크기**로 계산합니다.
 *
 * 행동해야 하는 사람이 전원 제출하면 그 자리에서 밤을 해결합니다.
 */
export const game_mafia_submit_night_action = onCall<SubmitData>(
  {region: MAFIA_REGION},
  async (request) => {
    const uid = mafiaUid(request);
    const roomCode = mafiaRoomCode(request.data?.roomCode);
    const commandId = mafiaCommandId(request.data?.commandId);
    const targetUid = mafiaTargetUid(request.data?.targetUid);
    const roomRef = getDatabase().ref(`rooms/${roomCode}`);
    let response: Record<string, unknown> | null = null;

    const transaction = await roomRef.transaction((raw) => {
      if (raw === null) return raw;
      const room = raw as MafiaRoom;
      const game = requireMafiaGame(room);
      const previous = mafiaProcessed(game, commandId);
      if (previous) {
        response = previous;
        return room;
      }
      assertMafiaPhase(game, "night");
      assertMafiaAlive(game, uid);
      assertValidNightTarget(game, uid, targetUid);

      const now = Date.now();
      game.server.nightActions ??= {};
      game.server.nightActions[uid] = targetUid;
      game.private[uid] ??= {roleId: game.server.roles[uid]};
      game.private[uid].nightTargetUid = targetUid;
      shareSelectionWithAllies(game, uid, targetUid);

      const submitted = Object.keys(game.server.nightActions).length;
      game.public.nightSubmittedCount = submitted;
      game.public.revision += 1;
      game.public.updatedAt = now;

      const allSubmitted = submitted >= game.public.nightActorCount;
      if (allSubmitted) resolveMafiaNight(game, now);

      response = {
        success: true,
        targetUid,
        submittedCount: submitted,
        actorCount: game.public.nightActorCount,
        phase: game.public.phase,
      };
      recordMafiaCommand(game, commandId, uid, "nightAction", now, response);
      return room;
    });

    if (!transaction.committed || !response) {
      throw new HttpsError("aborted", "밤 행동을 저장하지 못했습니다.");
    }
    return response;
  },
);

type TimeoutData = {roomCode?: unknown; controllerSessionId?: unknown};

/**
 * 밤 제한시간이 끝났음을 알려 남은 사람 없이 해결합니다.
 *
 * 아무것도 고르지 않은 사람은 **그 밤에 아무 일도 하지 않은 것**으로 처리합니다.
 * (미조작 시 무작위 선택 여부는 미확정 규칙입니다)
 */
export const game_mafia_timeout_night = onCall<TimeoutData>(
  {region: MAFIA_REGION},
  async (request) => {
    const uid = mafiaUid(request);
    const roomCode = mafiaRoomCode(request.data?.roomCode);
    const roomRef = getDatabase().ref(`rooms/${roomCode}`);
    let response: Record<string, unknown> | null = null;

    const transaction = await roomRef.transaction((raw) => {
      if (raw === null) return raw;
      const room = raw as MafiaRoom;
      assertMafiaController(room, uid, request.data?.controllerSessionId);
      const game = requireMafiaGame(room);
      if (game.public.phase !== "night") {
        response = {success: true, phase: game.public.phase};
        return room;
      }
      const now = Date.now();
      const deadline = game.public.turnDeadlineAt;
      // 마감 전 호출은 무시합니다. 태블릿 시계가 앞서가도 밤이 잘리지 않습니다.
      if (deadline !== null && now < deadline) {
        response = {success: false, reason: "notExpired", phase: "night"};
        return room;
      }
      resolveMafiaNight(game, now);
      response = {success: true, phase: game.public.phase};
      return room;
    });

    if (!transaction.committed || !response) {
      throw new HttpsError("aborted", "밤을 마치지 못했습니다.");
    }
    return response;
  },
);
