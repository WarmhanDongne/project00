/* eslint-disable max-len */

import {getDatabase} from "firebase-admin/database";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {nextFinalCallPlayer, prepareFinalCallRound} from "./game.js";
import {FinalCallRoom} from "./types.js";
import {assertFinalCallController, FINAL_CALL_REGION, finalCallRoomCode,
  finalCallUid, requireFinalCallGame} from "./validation.js";

type Data = {roomCode?: unknown; controllerSessionId?: unknown};

export const startFinalCallNextRound = onCall<Data>(
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
      if (game.public.phase !== "roundResult" || game.public.status !== "playing") {
        throw new HttpsError("failed-precondition", "다음 라운드를 시작할 수 없습니다.");
      }
      const starter = nextFinalCallPlayer(game.public.players, game.server.roundStarterUid);
      prepareFinalCallRound(game, starter, game.public.round + 1, Date.now());
      response = {success: true, round: game.public.round, turnUid: starter};
      return room;
    });
    if (!transaction.committed || !response) {
      throw new HttpsError("aborted", "다음 라운드를 시작하지 못했습니다.");
    }
    return response;
  },
);
