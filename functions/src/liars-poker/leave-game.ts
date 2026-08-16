import {getDatabase} from "firebase-admin/database";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {beginGameInterruption} from "../game-interruption/state.js";
import {RealtimeRoom} from "./common/types.js";
import {
  assertRoomExists,
  parseRoomCode,
  REGION,
  requireGame,
  requireUid,
} from "./common/validator.js";

type LeaveGameData = {roomCode?: unknown};

/** 방에서는 즉시 나가되, 진행 가능한 게임은 남은 플레이어 투표 뒤 제외합니다. */
export const leaveLiarsPokerGame = onCall<LeaveGameData>(
  {region: REGION},
  async (request) => {
    const uid = requireUid(request);
    const roomCode = parseRoomCode(request.data?.roomCode);
    const roomRef = getDatabase().ref(`rooms/${roomCode}`);
    let response: Record<string, unknown> | null = null;

    const transaction = await roomRef.transaction((rawRoom) => {
      if (rawRoom === null) return rawRoom;
      assertRoomExists(rawRoom);
      const room = rawRoom as RealtimeRoom;
      const game = requireGame(room, {allowInterruption: true});
      const roomPlayer = room.players?.[uid];
      const gamePlayer = game.public.players[uid];
      if (!roomPlayer && !gamePlayer) {
        response = {success: true, type: "alreadyLeft", gameEnded: false};
        return room;
      }
      delete room.players?.[uid];
      if (!gamePlayer || gamePlayer.status !== "alive" ||
          game.public.status === "finished") {
        response = {success: true, type: "playerLeft", gameEnded: true};
        return room;
      }

      const now = Date.now();
      const remainingCount = Object.entries(game.public.players).filter(
        ([playerUid, player]) => playerUid !== uid && player.status === "alive",
      ).length;
      beginGameInterruption(
        room,
        uid,
        "left",
        now,
        remainingCount < 2 ? {durationMs: 4000} : {},
      );
      response = {
        success: true,
        type: "playerLeft",
        gameEnded: false,
        remainingPlayerCount: remainingCount,
        interruptionId: game.public.interruption?.id ?? null,
      };
      return room;
    });

    if (!transaction.committed || !response) {
      throw new HttpsError("aborted", "게임에서 퇴장하지 못했습니다.");
    }
    return response;
  },
);
