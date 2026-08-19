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

/** 방과 참가자는 유지하고 현재 Final Call 게임만 수동 종료합니다. */
export const game_final_call_end_game = onCall<Data>(
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
      const game = requireFinalCallGame(room, {allowInterruption: true});
      const now = Date.now();

      game.public.status = "finished";
      game.public.finishReason = "manual";
      game.public.phase = "finished";
      game.public.turnUid = null;
      game.public.turnDeadlineAt = null;
      game.public.callerUid = null;
      game.public.pendingDrawUid = null;
      game.public.pendingDrawSource = null;
      game.public.finalTurnPendingUids = [];
      game.public.winnerUid = null;
      game.public.winnerUids = [];
      game.public.winningTeam = null;
      game.public.revision += 1;
      game.public.updatedAt = now;
      game.public.finishedAt = now;
      game.private = {};
      delete game.server.pendingHands;
      delete game.server.finalSubmissions;
      delete game.server.interruption;
      delete game.public.interruption;

      response = {
        success: true,
        type: "gameEnded",
        revision: game.public.revision,
      };
      return room;
    });

    if (!transaction.committed || !response) {
      throw new HttpsError("aborted", "게임을 종료하지 못했습니다.");
    }
    return response;
  },
);
