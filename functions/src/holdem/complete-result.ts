/* eslint-disable max-len */

import {getDatabase} from "firebase-admin/database";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {runPrimedTransaction} from "../room/room-transaction.js";
import {completeHoldemResult} from "./game.js";
import {HoldemRoom} from "./types.js";
import {assertHoldemController, assertHoldemRoom, HOLDEM_REGION, holdemHttpsError, parseHoldemRoomCode, requireHoldemGame, requireHoldemUid} from "./validation.js";

type Data = {roomCode?: unknown; controllerSessionId?: unknown; warmup?: unknown};

export const game_holdem_complete_result = onCall<Data>({region: HOLDEM_REGION}, async (request) => {
  if (request.data?.warmup === true) return {success: true, type: "warmup"};
  const uid = requireHoldemUid(request);
  const roomCode = parseHoldemRoomCode(request.data?.roomCode);
  let response: Record<string, unknown> | null = null;
  try {
    const transaction = await runPrimedTransaction(getDatabase().ref(`rooms/${roomCode}`), (raw) => {
      assertHoldemRoom(raw);
      const room = raw as HoldemRoom;
      assertHoldemController(room, uid, request.data?.controllerSessionId);
      response = completeHoldemResult(requireHoldemGame(room), Date.now());
      return room;
    });
    if (!transaction.committed || !response) throw new HttpsError("aborted", "핸드 결과를 완료하지 못했습니다.");
    return response;
  } catch (error) {
    throw holdemHttpsError(error);
  }
});
