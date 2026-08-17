import {getDatabase} from "firebase-admin/database";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {beginGameInterruption} from "../game-interruption/state.js";
import {orderedAlivePlayers} from "./game.js";
import {FinalCallRoom} from "./types.js";
import {
  FINAL_CALL_REGION,
  finalCallRoomCode,
  finalCallUid,
  requireFinalCallGame,
} from "./validation.js";

type Data = {roomCode?: unknown};

/** 방에서는 즉시 나가되, 진행 가능한 게임은 남은 플레이어 투표 뒤 제외합니다. */
export const leaveFinalCallGame = onCall<Data>(
  {region: FINAL_CALL_REGION},
  async (request) => {
    const uid = finalCallUid(request);
    const roomCode = finalCallRoomCode(request.data?.roomCode);
    const roomRef = getDatabase().ref(`rooms/${roomCode}`);
    let response: Record<string, unknown> | null = null;
    const transaction = await roomRef.transaction((raw) => {
      if (raw === null) return raw;
      const room = raw as FinalCallRoom;
      const roomPlayer = room.players?.[uid];
      if (!roomPlayer && !room.game?.public.players[uid]) {
        response = {success: true, alreadyLeft: true};
        return room;
      }
      delete room.players?.[uid];
      if (!room.game || room.game.public.gameType !== "final_call") {
        response = {success: true};
        return room;
      }

      const game = requireFinalCallGame(room, {allowInterruption: true});
      const leavingPlayer = game.public.players[uid];
      if (!leavingPlayer || leavingPlayer.status !== "alive" ||
          game.public.status === "finished") {
        response = {success: true};
        return room;
      }

      const now = Date.now();
      const remainingCount = orderedAlivePlayers(game.public.players)
        .filter((player) => player.uid !== uid).length;
      beginGameInterruption(
        room,
        uid,
        "left",
        now,
        remainingCount < 2 ? {durationMs: 4000} : {},
      );
      response = {
        success: true,
        status: game.public.status,
        interruptionId: game.public.interruption?.id ?? null,
      };
      return room;
    });
    if (!transaction.committed || !response) {
      throw new HttpsError("aborted", "게임 퇴장을 처리하지 못했습니다.");
    }
    return response;
  },
);
