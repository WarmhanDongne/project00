/* eslint-disable max-len, valid-jsdoc, require-jsdoc */

import {getDatabase} from "firebase-admin/database";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {mafiaProcessed, recordMafiaCommand} from "./commands.js";
import {
  advanceMafiaNightStage,
  beginMafiaNightStage,
  bumpNightActionCue,
  canActInNightStage,
  mafiaAbilityUsesLeft,
  nextMafiaNightStage,
  recordImmediateInvestigation,
  resolveMafiaNight,
} from "./game.js";
import {mafiaRole} from "./roles.js";
import {
  MafiaGameState,
  MafiaRoom,
} from "./types.js";
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
 * 역할 이름으로 분기하지 않고 행동 종류·대상 범위·진영만 봅니다.
 *
 * ⚠️ **거절 메시지로 신분이 새지 않게** 주의해야 합니다. "같은 편을 고를 수
 * 없습니다"는 동료를 이미 아는 역할(마피아)에게만 보낼 수 있습니다. 동료를
 * 모르는 역할(짐승인간·연쇄살인마)에게 같은 말을 하면 그 순간 대상의 진영을
 * 알려 주는 셈입니다. 그런 경우는 제출을 받아 두고 밤 해결에서 조용히
 * 불발시킵니다([resolveMafiaNight]).
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

  // 확정(2026-08): 지금 열린 1~4, 5~8, 9~14 순위 구간의 역할만
  // 고를 수 있습니다.
  if (!canActInNightStage(game, actorUid)) {
    throw new HttpsError("failed-precondition", "아직 고를 수 없습니다.");
  }

  // 남은 사용 횟수가 없으면 이 밤에는 아무것도 할 수 없습니다(자경단원).
  const usesLeft = mafiaAbilityUsesLeft(game, actorUid);
  if (usesLeft !== null && usesLeft <= 0) {
    throw new HttpsError("failed-precondition", "능력을 모두 사용했습니다.");
  }

  // 대상 범위는 역할이 정합니다. 영매·도둑은 **사망자**를 고릅니다.
  const targetStatus = game.public.players[targetUid]?.status;
  if (role.nightTargetScope === "dead") {
    if (targetStatus !== "dead") {
      throw new HttpsError("failed-precondition", "죽은 사람만 고를 수 있습니다.");
    }
  } else if (targetStatus !== "alive") {
    throw new HttpsError("failed-precondition", "살아 있는 대상만 고를 수 있습니다.");
  }

  // 보호는 자기 자신도 고를 수 있습니다(의사 자가 치료 허용 — 미확정 규칙).
  if (targetUid === actorUid && role.nightAction !== "protect") {
    throw new HttpsError("failed-precondition", "자신을 고를 수 없습니다.");
  }

  // 동료를 **이미 아는** 역할만 같은 편 제거를 막습니다(위 주의 참고).
  if (role.nightAction === "eliminate" && role.knowsAllies) {
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
      // 구간의 마감이 지났으면 더 받지 않습니다. 구간을 넘기는 일은 태블릿의
      // timeout_night 호출이 합니다.
      const deadline = game.public.turnDeadlineAt;
      if (deadline !== null && now > deadline) {
        throw new HttpsError(
          "failed-precondition",
          "행동 시간이 끝났습니다.",
        );
      }
      // 확정(2026-08): 직업 효과음은 **선택을 완료한 순간** 태블릿에서 울립니다.
      // 넣기 전에 불러야 '첫 제출'인지 알 수 있습니다.
      bumpNightActionCue(game, uid);
      game.server.nightActions ??= {};
      game.server.nightActions[uid] = targetUid;
      game.private[uid] ??= {roleId: game.server.roles[uid]};
      game.private[uid].nightTargetUid = targetUid;
      shareSelectionWithAllies(game, uid, targetUid);
      // 조사류 결과는 제출한 순간 보여 줍니다(확정 흐름: 선택 완료 → 결과 →
      // 확인). 밤이 끝날 때 최종값으로 한 번 더 덮어씁니다.
      recordImmediateInvestigation(game, uid, targetUid, Date.now());

      const submitted = Object.keys(game.server.nightActions).length;
      game.public.nightSubmittedCount = submitted;
      game.public.revision += 1;
      game.public.updatedAt = now;

      // 확정(2026-08): 이 구간에서 기다릴 사람이 다 냈으면 남은 시간을 버리고
      // 다음 순위 구간을 엽니다. 빈 구간은 즉시 건너뛰고, 모든 행동이
      // 끝나면 10초 뒤 아침입니다. 밤 자체를 여기서 끝내지는 않습니다 — 해결은
      // 마감을 받은 timeout_night이 합니다.
      advanceMafiaNightStage(game, now);

      response = {
        success: true,
        targetUid,
        submittedCount: submitted,
        actorCount: game.public.nightActorCount,
        nightStage: game.public.nightStage ?? null,
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
      // 구간의 마감입니다. 아직 마무리 구간이 아니면 다음 구간을 엽니다.
      const stage = game.public.nightStage ?? "wrapUp";
      if (stage !== "wrapUp") {
        beginMafiaNightStage(
          game,
          nextMafiaNightStage(stage),
          now,
        );
        // 다음 구간에 기다릴 사람이 없으면 곧장 더 넘어갑니다.
        advanceMafiaNightStage(game, now);
        response = {
          success: true,
          phase: game.public.phase,
          nightStage: game.public.nightStage ?? null,
        };
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
