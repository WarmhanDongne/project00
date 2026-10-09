import {
  runGameCommandTransaction,
} from "../game-interruption/game-command-transaction.js";
/* eslint-disable max-len */

import {getDatabase} from "firebase-admin/database";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {timeoutHoldemTurn} from "./game.js";
import {HoldemRoom} from "./types.js";
import {
  assertHoldemController,
  assertHoldemRoom,
  HOLDEM_REGION,
  holdemHttpsError,
  parseHoldemRoomCode,
  requireHoldemGame,
  requireHoldemUid,
} from "./validation.js";

type Data = {roomCode?: unknown; controllerSessionId?: unknown; warmup?: unknown};

export const game_holdem_timeout_turn = onCall<Data>({region: HOLDEM_REGION}, async (request) => {
  if (request.data?.warmup === true) return {success: true, type: "warmup"};
  const uid = requireHoldemUid(request);
  const roomCode = parseHoldemRoomCode(request.data?.roomCode);
  let response: Record<string, unknown> | null = null;
  try {
    const transaction = await runGameCommandTransaction(getDatabase().ref(`rooms/${roomCode}`), request, "game_holdem_timeout_turn", (raw, transactionNow) => {
      assertHoldemRoom(raw);
      const room = raw as HoldemRoom;
      assertHoldemController(room, uid, request.data?.controllerSessionId);
      response = timeoutHoldemTurn(requireHoldemGame(room), transactionNow);
      return room;
    }, () => response);
    response = transaction.operationResult ?? response;
    if (!transaction.committed || !response) throw new HttpsError("aborted", "턴 시간 초과를 처리하지 못했습니다.");
    return response;
  } catch (error) {
    throw holdemHttpsError(error);
  }
});
