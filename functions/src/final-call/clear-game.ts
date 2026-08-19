/* eslint-disable max-len */

import {getDatabase} from "firebase-admin/database";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {FinalCallRoom} from "./types.js";
import {
  assertFinalCallController,
  FINAL_CALL_REGION,
  finalCallRoomCode,
  finalCallUid,
} from "./validation.js";

type Data = {roomCode?: unknown; controllerSessionId?: unknown};

/** 방과 참가자는 유지하고 현재 Final Call `game` 노드만 삭제합니다. */
export const game_final_call_clear_game = onCall<Data>(
  {region: FINAL_CALL_REGION},
  async (request) => {
    const uid = finalCallUid(request);
    const roomCode = finalCallRoomCode(request.data?.roomCode);
    const roomRef = getDatabase().ref(`rooms/${roomCode}`);
    const roomSnapshot = await roomRef.get();
    if (!roomSnapshot.exists()) {
      throw new HttpsError("not-found", "방을 찾을 수 없습니다.");
    }

    const room = roomSnapshot.val() as FinalCallRoom;
    assertFinalCallController(room, uid, request.data?.controllerSessionId);

    const gameRef = roomRef.child("game");
    let alreadyCleared = false;
    const transaction = await gameRef.transaction((rawGame) => {
      if (rawGame === null) {
        alreadyCleared = true;
        return rawGame;
      }

      const game = rawGame as NonNullable<FinalCallRoom["game"]>;
      if (game.public?.gameType !== "final_call") {
        throw new HttpsError(
          "failed-precondition",
          "현재 방의 게임은 Final Call이 아닙니다.",
        );
      }
      if (game.public.status !== "finished") {
        throw new HttpsError(
          "failed-precondition",
          "게임 종료 후에만 게임 정보를 정리할 수 있습니다.",
        );
      }

      // game 노드만 null로 만들어 방·참가자·선택 게임은 그대로 유지합니다.
      return null;
    });

    if (!transaction.committed && !alreadyCleared) {
      throw new HttpsError("aborted", "게임 정보를 정리하지 못했습니다.");
    }
    return {success: true, alreadyCleared, roomCode};
  },
);
