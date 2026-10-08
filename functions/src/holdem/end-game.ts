/* eslint-disable max-len */

import {getDatabase} from "firebase-admin/database";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {runPrimedTransaction} from "../room/room-transaction.js";
import {endHoldemGame} from "./game.js";
import {HoldemRoom} from "./types.js";
import {assertHoldemController, assertHoldemRoom, HOLDEM_REGION, holdemHttpsError, parseHoldemRoomCode, requireHoldemGame, requireHoldemUid} from "./validation.js";

type Data = {roomCode?: unknown; controllerSessionId?: unknown};

export const game_holdem_end_game = onCall<Data>({region: HOLDEM_REGION}, async (request) => {
  const uid = requireHoldemUid(request);
  const roomCode = parseHoldemRoomCode(request.data?.roomCode);
  let response: Record<string, unknown> | null = null;
  try {
    const transaction = await runPrimedTransaction(getDatabase().ref(`rooms/${roomCode}`), (raw) => {
      assertHoldemRoom(raw);
      const room = raw as HoldemRoom;
      assertHoldemController(room, uid, request.data?.controllerSessionId);
      const game = requireHoldemGame(room, true);
      endHoldemGame(game, Date.now());
      response = {success: true, type: "gameEnded", revision: game.public.revision};
      return room;
    });
    if (!transaction.committed || !response) throw new HttpsError("aborted", "게임을 종료하지 못했습니다.");
    return response;
  } catch (error) {
    throw holdemHttpsError(error);
  }
});
