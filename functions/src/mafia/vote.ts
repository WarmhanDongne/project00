/* eslint-disable max-len */

import {getDatabase} from "firebase-admin/database";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {mafiaProcessed, recordMafiaCommand} from "./commands.js";
import {
  advanceMafiaAfterDeaths,
  isMafiaVoteBanned,
  resolveMafiaVoting,
} from "./game.js";
import {MafiaRoom} from "./types.js";
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

type SubmitData = {
  roomCode?: unknown;
  commandId?: unknown;
  targetUid?: unknown;
};

/**
 * 낮 투표를 제출합니다(시안 P7).
 *
 * 비밀 투표입니다. **누가 누구를 찍었는지는 server에만 둡니다.** public에는
 * 제출 인원수만 담고, 개표 결과는 득표수만 공개합니다.
 *
 * ⚠️ **미확정 규칙**: 지금은 한 번 내면 바꿀 수 없습니다(시안의 제출 후 대기
 * 화면과 맞춤). 변경을 허용하려면 아래 중복 검사만 지우면 됩니다.
 */
export const game_mafia_submit_vote = onCall<SubmitData>(
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
      assertMafiaPhase(game, "voting");
      assertMafiaAlive(game, uid);
      if (game.server.votes?.[uid]) {
        throw new HttpsError("failed-precondition", "이미 투표했습니다.");
      }
      // 마담에게 유혹당하면 이번 낮에는 투표할 수 없습니다.
      if (isMafiaVoteBanned(game, uid)) {
        throw new HttpsError(
          "failed-precondition",
          "이번 낮에는 투표할 수 없습니다.",
        );
      }
      if (game.public.players[targetUid]?.status !== "alive") {
        throw new HttpsError("failed-precondition", "살아 있는 대상만 고를 수 있습니다.");
      }

      const now = Date.now();
      game.server.votes ??= {};
      game.server.votes[uid] = targetUid;
      game.private[uid] ??= {roleId: game.server.roles[uid]};
      game.private[uid].voteTargetUid = targetUid;

      const submitted = Object.keys(game.server.votes).length;
      game.public.voteSubmittedCount = submitted;
      // 누가 냈는지만 공개합니다(어디에 냈는지는 server에만 둡니다).
      game.public.voteSubmittedUids = Object.keys(game.server.votes);
      game.public.revision += 1;
      game.public.updatedAt = now;

      // 전원이 내면 그 자리에서 개표합니다.
      if (submitted >= game.public.voteEligibleCount) {
        resolveMafiaVoting(game, now);
      }

      response = {
        success: true,
        submittedCount: submitted,
        eligibleCount: game.public.voteEligibleCount,
        phase: game.public.phase,
      };
      recordMafiaCommand(game, commandId, uid, "vote", now, response);
      return room;
    });

    if (!transaction.committed || !response) {
      throw new HttpsError("aborted", "투표를 저장하지 못했습니다.");
    }
    return response;
  },
);

type TimeoutData = {roomCode?: unknown; controllerSessionId?: unknown};

/**
 * 투표 제한시간이 끝났음을 알려 개표합니다.
 *
 * 내지 않은 사람은 **기권**으로 처리합니다(확정 규칙: 타임아웃 = 기권).
 */
export const game_mafia_timeout_vote = onCall<TimeoutData>(
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
      if (game.public.phase !== "voting") {
        response = {success: true, phase: game.public.phase};
        return room;
      }
      const now = Date.now();
      const deadline = game.public.turnDeadlineAt;
      if (deadline !== null && now < deadline) {
        response = {success: false, reason: "notExpired", phase: "voting"};
        return room;
      }
      resolveMafiaVoting(game, now);
      response = {success: true, phase: game.public.phase};
      return room;
    });

    if (!transaction.committed || !response) {
      throw new HttpsError("aborted", "개표하지 못했습니다.");
    }
    return response;
  },
);

type CompleteData = {roomCode?: unknown; controllerSessionId?: unknown};

/**
 * 태블릿의 개표·처형 발표 연출이 끝났음을 알립니다(시안 T6·T7).
 *
 * 여기서 **두 번째 승패 판정**을 합니다. 끝나지 않았으면 다음 밤으로 넘어갑니다.
 */
export const game_mafia_complete_vote_result = onCall<CompleteData>(
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
      if (game.public.phase !== "voteResult") {
        response = {success: true, phase: game.public.phase};
        return room;
      }
      const winner = advanceMafiaAfterDeaths(game, "night", Date.now());
      response = {success: true, phase: game.public.phase, winner};
      return room;
    });

    if (!transaction.committed || !response) {
      throw new HttpsError("aborted", "개표 발표를 마치지 못했습니다.");
    }
    return response;
  },
);
