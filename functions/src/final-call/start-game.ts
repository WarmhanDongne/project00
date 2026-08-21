/* eslint-disable max-len */

import {getDatabase} from "firebase-admin/database";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {createFinalCallPlayers, createInitialFinalCallGame} from "./game.js";
import {FinalCallRoom} from "./types.js";
import {
  assertFinalCallController,
  FINAL_CALL_REGION,
  finalCallRoomCode,
  finalCallUid,
} from "./validation.js";

type StartData = {
  roomCode?: unknown;
  restart?: unknown;
  controllerSessionId?: unknown;
};

export const game_final_call_start_game = onCall<StartData>(
  {region: FINAL_CALL_REGION},
  async (request) => {
    const uid = finalCallUid(request);
    const roomCode = finalCallRoomCode(request.data?.roomCode);
    const restart = request.data?.restart === true;
    const roomRef = getDatabase().ref(`rooms/${roomCode}`);
    const room = (await roomRef.get()).val() as FinalCallRoom | null;
    if (!room) throw new HttpsError("not-found", "방을 찾을 수 없습니다.");
    assertFinalCallController(room, uid, request.data?.controllerSessionId);
    if (room.selectedGame !== "final_call") {
      throw new HttpsError("failed-precondition", "Final Call이 선택되지 않았습니다.");
    }
    if (!restart && room.status !== "seating") {
      throw new HttpsError(
        "failed-precondition",
        "자리 배치를 시작한 뒤 게임을 시작해주세요.",
      );
    }
    const players = await createFinalCallPlayers(room.players);
    const game = createInitialFinalCallGame(players, Date.now());
    const transaction = await roomRef.child("game").transaction((current) => {
      if (current?.public?.status === "playing" && !restart) return;
      return game;
    });
    if (!transaction.committed) {
      throw new HttpsError("already-exists", "이미 게임이 진행 중입니다.");
    }
    return {success: true, roomCode, turnUid: game.public.turnUid};
  },
);
