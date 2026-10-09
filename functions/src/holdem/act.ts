import {
  runGameCommandTransaction,
} from "../game-interruption/game-command-transaction.js";
/* eslint-disable max-len */

import {getDatabase} from "firebase-admin/database";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {processedHoldemResult, recordHoldemCommand} from "./common.js";
import {actInHoldemGame} from "./game.js";
import {HoldemRoom} from "./types.js";
import {
  assertHoldemRoom,
  HOLDEM_REGION,
  holdemHttpsError,
  parseHoldemAction,
  parseHoldemCommandId,
  parseHoldemRoomCode,
  parseHoldemStateVersion,
  requireHoldemGame,
  requireHoldemUid,
} from "./validation.js";

type Data = {roomCode?: unknown; commandId?: unknown; stateVersion?: unknown; action?: unknown; amount?: unknown; warmup?: unknown};

export const game_holdem_act = onCall<Data>({region: HOLDEM_REGION}, async (request) => {
  if (request.data?.warmup === true) return {success: true, type: "warmup"};
  const uid = requireHoldemUid(request);
  const roomCode = parseHoldemRoomCode(request.data?.roomCode);
  const commandId = parseHoldemCommandId(request.data?.commandId);
  const stateVersion = parseHoldemStateVersion(request.data?.stateVersion);
  const action = parseHoldemAction(request.data?.action, request.data?.amount);
  let response: Record<string, unknown> | null = null;
  try {
    const transaction = await runGameCommandTransaction(getDatabase().ref(`rooms/${roomCode}`), request, "game_holdem_act", (raw, transactionNow) => {
      assertHoldemRoom(raw);
      const room = raw as HoldemRoom;
      const game = requireHoldemGame(room);
      const previous = processedHoldemResult(game, commandId);
      if (previous) {
        response = previous;
        return room;
      }
      if (game.public.revision !== stateVersion) {
        throw new HttpsError("aborted", "게임 상태가 변경되었습니다. 최신 화면에서 다시 선택해주세요.");
      }
      response = actInHoldemGame(game, uid, action, transactionNow);
      recordHoldemCommand(game, commandId, {uid, type: "act", createdAt: transactionNow, result: response});
      return room;
    }, () => response);
    response = transaction.operationResult ?? response;
    if (!transaction.committed || !response) throw new HttpsError("aborted", "홀덤 행동을 반영하지 못했습니다.");
    return response;
  } catch (error) {
    throw holdemHttpsError(error);
  }
});
