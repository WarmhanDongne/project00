/* eslint-disable max-len */

import {getDatabase} from "firebase-admin/database";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {startTurn} from "./game.js";
import {FinalCallRoom} from "./types.js";
import {
  assertFinalCallController,
  FINAL_CALL_REGION,
  finalCallRoomCode,
  finalCallUid,
  requireFinalCallGame,
} from "./validation.js";

type Data = {roomCode?: unknown; controllerSessionId?: unknown};

export const completeFinalCallDealing = onCall<Data>(
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
      if (game.public.phase !== "dealing") {
        response = {success: true, phase: game.public.phase};
        return room;
      }
      game.private = game.server.pendingHands ?? {};
      delete game.server.pendingHands;
      game.public.phase = "playing";
      game.public.revision += 1;
      startTurn(game, game.public.turnUid ?? game.server.roundStarterUid, Date.now());
      response = {success: true, phase: "playing", turnUid: game.public.turnUid};
      return room;
    });
    if (!transaction.committed || !response) {
      throw new HttpsError("aborted", "카드 배분을 완료하지 못했습니다.");
    }
    return response;
  },
);
