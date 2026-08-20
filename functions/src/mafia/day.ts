/* eslint-disable max-len */

import {getDatabase} from "firebase-admin/database";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {mafiaProcessed, recordMafiaCommand} from "./commands.js";
import {beginMafiaVoting} from "./game.js";
import {MafiaRoom} from "./types.js";
import {
  assertMafiaAlive,
  assertMafiaController,
  assertMafiaPhase,
  MAFIA_REGION,
  mafiaCommandId,
  mafiaRoomCode,
  mafiaUid,
  requireMafiaGame,
} from "./validation.js";

type EndData = {roomCode?: unknown; commandId?: unknown};

/**
 * 자유 토론을 제한시간보다 먼저 끝냅니다(시안 P6의 `토론 종료 하기`).
 *
 * ⚠️ **미확정 규칙**: 지금은 살아 있는 사람 누구나 끝낼 수 있습니다. 시안에서
 * 버튼이 모든 휴대폰에 조건 없이 놓여 있어 그렇게 두었습니다. 방장만 또는
 * 과반 동의로 바꾸려면 이 함수의 조건만 고치면 됩니다.
 */
export const game_mafia_end_discussion = onCall<EndData>(
  {region: MAFIA_REGION},
  async (request) => {
    const uid = mafiaUid(request);
    const roomCode = mafiaRoomCode(request.data?.roomCode);
    const commandId = mafiaCommandId(request.data?.commandId);
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
      // 이미 투표로 넘어갔으면 성공으로 답합니다. 여러 사람이 동시에 눌러도
      // 첫 번째만 실제로 넘기고 나머지는 조용히 성공합니다.
      if (game.public.phase !== "day") {
        response = {success: true, phase: game.public.phase};
        return room;
      }
      assertMafiaPhase(game, "day");
      assertMafiaAlive(game, uid);

      const now = Date.now();
      beginMafiaVoting(game, now);
      response = {success: true, phase: game.public.phase, endedBy: uid};
      recordMafiaCommand(game, commandId, uid, "endDiscussion", now, response);
      return room;
    });

    if (!transaction.committed || !response) {
      throw new HttpsError("aborted", "토론을 끝내지 못했습니다.");
    }
    return response;
  },
);

type TimeoutData = {roomCode?: unknown; controllerSessionId?: unknown};

/** 토론 제한시간이 끝났음을 알려 투표로 넘어갑니다. */
export const game_mafia_timeout_day = onCall<TimeoutData>(
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
      if (game.public.phase !== "day") {
        response = {success: true, phase: game.public.phase};
        return room;
      }
      const now = Date.now();
      const deadline = game.public.turnDeadlineAt;
      // 마감 전 호출은 무시합니다. 태블릿 시계가 앞서가도 토론이 잘리지 않습니다.
      if (deadline !== null && now < deadline) {
        response = {success: false, reason: "notExpired", phase: "day"};
        return room;
      }
      beginMafiaVoting(game, now);
      response = {success: true, phase: game.public.phase};
      return room;
    });

    if (!transaction.committed || !response) {
      throw new HttpsError("aborted", "토론을 마치지 못했습니다.");
    }
    return response;
  },
);
