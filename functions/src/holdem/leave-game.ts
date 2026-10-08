/* eslint-disable max-len */

import {getDatabase} from "firebase-admin/database";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {beginGameInterruption} from "../game-interruption/state.js";
import {runPrimedTransaction} from "../room/room-transaction.js";
import {HoldemRoom} from "./types.js";
import {assertHoldemRoom, HOLDEM_REGION, holdemHttpsError, parseHoldemRoomCode, requireHoldemGame, requireHoldemUid} from "./validation.js";

type Data = {roomCode?: unknown};

export const game_holdem_leave_game = onCall<Data>({region: HOLDEM_REGION}, async (request) => {
  const uid = requireHoldemUid(request);
  const roomCode = parseHoldemRoomCode(request.data?.roomCode);
  let response: Record<string, unknown> | null = null;
  try {
    const transaction = await runPrimedTransaction(getDatabase().ref(`rooms/${roomCode}`), (raw) => {
      assertHoldemRoom(raw);
      const room = raw as HoldemRoom;
      const game = requireHoldemGame(room, true);
      const roomPlayer = room.players?.[uid];
      const player = game.public.players[uid];
      if (!roomPlayer && !player) {
        response = {success: true, type: "alreadyLeft"};
        return room;
      }
      if (!player || player.status === "eliminated" || game.public.status === "finished") {
        delete room.players?.[uid];
        response = {success: true, type: "playerLeft", gameEnded: true};
        return room;
      }
      if (room.players?.[uid]) room.players[uid].isConnected = false;
      beginGameInterruption(room, uid, "left", Date.now(), {minimumPlayerCount: 2});
      response = {success: true, type: "playerLeft", gameEnded: false, interruptionId: game.public.interruption?.id ?? null};
      return room;
    });
    if (!transaction.committed || !response) throw new HttpsError("aborted", "게임에서 퇴장하지 못했습니다.");
    return response;
  } catch (error) {
    throw holdemHttpsError(error);
  }
});
