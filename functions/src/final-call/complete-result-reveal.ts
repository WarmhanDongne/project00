/* eslint-disable max-len */

import {getDatabase} from "firebase-admin/database";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {FinalCallRoom} from "./types.js";
import {
  assertFinalCallController,
  FINAL_CALL_REGION,
  finalCallRoomCode,
  finalCallUid,
  requireFinalCallGame,
} from "./validation.js";

type Data = {roomCode?: unknown; controllerSessionId?: unknown};

/** 태블릿의 최종 공개 연출이 끝난 뒤 휴대폰 결과 화면을 해제합니다. */
export const completeFinalCallResultReveal = onCall<Data>(
  {region: FINAL_CALL_REGION},
  async (request) => {
    const uid = finalCallUid(request);
    const roomCode = finalCallRoomCode(request.data?.roomCode);
    const roomRef = getDatabase().ref(`rooms/${roomCode}`);
    let response: Record<string, unknown> | null = null;

    const transaction = await roomRef.transaction((raw) => {
      if (raw === null) return raw;
      const room = raw as FinalCallRoom;
      assertFinalCallController(room, uid, request.data?.controllerSessionId);
      const game = requireFinalCallGame(room);

      if (game.public.status !== "finished") {
        throw new HttpsError(
          "failed-precondition",
          "최종 결과 공개를 완료할 상태가 아닙니다.",
        );
      }
      if (game.public.resultRevealCompletedAt) {
        response = {
          success: true,
          completedAt: game.public.resultRevealCompletedAt,
        };
        return room;
      }

      const now = Date.now();
      game.public.resultRevealCompletedAt = now;
      game.public.revision += 1;
      game.public.updatedAt = now;
      response = {success: true, completedAt: now};
      return room;
    });

    if (!transaction.committed || !response) {
      throw new HttpsError("aborted", "최종 결과 공개를 완료하지 못했습니다.");
    }
    return response;
  },
);
