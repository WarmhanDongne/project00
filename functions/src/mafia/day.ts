/* eslint-disable max-len */

import {getDatabase} from "firebase-admin/database";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {mafiaProcessed, recordMafiaCommand} from "./commands.js";
import {alivePlayers, beginMafiaVoting} from "./game.js";
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
 * 토론 조기 종료에 **한 표**를 보탭니다(시안 P6의 `토론 종료 하기` = `n/m`).
 *
 * 확정 규칙: 살아 있는 사람의 **과반수**가 누르면 토론이 끝나고 투표로
 * 넘어갑니다. 버튼은 실시간으로 `누른 사람 수 / 생존자 수`를 보여 줍니다.
 * 한 번 누르면 취소할 수 없습니다.
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
      // 이미 투표로 넘어갔으면 성공으로 답합니다(재시도 안전).
      if (game.public.phase !== "day") {
        response = {success: true, phase: game.public.phase};
        return room;
      }
      assertMafiaPhase(game, "day");
      assertMafiaAlive(game, uid);

      const now = Date.now();
      game.server.discussionSkipVotes ??= {};
      const alreadyVoted = game.server.discussionSkipVotes[uid] === true;
      game.server.discussionSkipVotes[uid] = true;
      game.private[uid] ??= {roleId: game.server.roles[uid]};
      game.private[uid].discussionSkipVoted = true;

      const aliveCount = alivePlayers(game.public.players).length;
      const skipCount = Object.keys(game.server.discussionSkipVotes).length;
      game.public.discussionSkipCount = skipCount;
      game.public.revision += 1;
      game.public.updatedAt = now;

      // 과반수 = 절반 초과. 10명이면 6명부터 끝납니다.
      const majority = skipCount * 2 > aliveCount;
      if (majority) beginMafiaVoting(game, now);

      response = {
        success: true,
        alreadyVoted,
        skipCount,
        aliveCount,
        phase: game.public.phase,
      };
      recordMafiaCommand(game, commandId, uid, "skipDiscussion", now, response);
      return room;
    });

    if (!transaction.committed || !response) {
      throw new HttpsError("aborted", "토론 종료 의사를 저장하지 못했습니다.");
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
