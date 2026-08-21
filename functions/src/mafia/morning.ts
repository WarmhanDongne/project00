/* eslint-disable max-len */

import {getDatabase} from "firebase-admin/database";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {advanceMafiaAfterDeaths} from "./game.js";
import {MafiaRoom} from "./types.js";
import {
  assertMafiaController,
  MAFIA_REGION,
  mafiaRoomCode,
  mafiaUid,
  requireMafiaGame,
} from "./validation.js";

type Data = {roomCode?: unknown; controllerSessionId?: unknown};

/**
 * 태블릿의 아침 발표 연출이 끝났음을 알립니다(시안 T3).
 *
 * 여기서 **첫 번째 승패 판정**을 합니다. 끝나지 않았으면 낮 토론으로 넘어갑니다.
 */
export const game_mafia_complete_morning = onCall<Data>(
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
      // 이미 지나간 단계면 그대로 성공으로 답합니다(재시도 안전).
      if (game.public.phase !== "morning") {
        response = {success: true, phase: game.public.phase};
        return room;
      }
      const winner = advanceMafiaAfterDeaths(game, "day", Date.now());
      response = {success: true, phase: game.public.phase, winner};
      return room;
    });

    if (!transaction.committed || !response) {
      throw new HttpsError("aborted", "아침 발표를 마치지 못했습니다.");
    }
    return response;
  },
);
