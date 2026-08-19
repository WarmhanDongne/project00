/* eslint-disable max-len, brace-style, block-spacing */

import {getDatabase} from "firebase-admin/database";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {finalCallProcessed, recordFinalCallCommand} from "./commands.js";
import {orderedAlivePlayers, resolveFinalCallRound, startTurn} from "./game.js";
import {FinalCallRoom} from "./types.js";
import {assertFinalCallTurn, FINAL_CALL_REGION, finalCallCommandId,
  finalCallRoomCode, finalCallUid, requireFinalCallGame} from "./validation.js";

type Data = {roomCode?: unknown; commandId?: unknown};

export const game_final_call_declare = onCall<Data>({region: FINAL_CALL_REGION}, async (request) => {
  const uid = finalCallUid(request);
  const roomCode = finalCallRoomCode(request.data?.roomCode);
  const commandId = finalCallCommandId(request.data?.commandId);
  const roomRef = getDatabase().ref(`rooms/${roomCode}`);
  let response: Record<string, unknown> | null = null;
  const transaction = await roomRef.transaction((raw) => {
    if (raw === null) return raw;
    const room = raw as FinalCallRoom;
    const game = requireFinalCallGame(room);
    const previous = finalCallProcessed(game, commandId);
    if (previous) { response = previous; return room; }
    assertFinalCallTurn(game, uid);
    // Realtime Database는 null 필드를 저장하지 않아 읽을 때 undefined가 됩니다.
    if (game.public.phase !== "playing" || game.public.pendingDrawUid) {
      throw new HttpsError("failed-precondition", "현재 CALL을 선언할 수 없습니다.");
    }
    const pending = orderedAlivePlayers(game.public.players)
      .map((player) => player.uid).filter((playerUid) => playerUid !== uid);
    const now = Date.now();
    game.public.callerUid = uid;
    game.public.finalTurnPendingUids = pending;
    if (pending.length === 0) {
      resolveFinalCallRound(game, now, false);
    } else {
      game.public.phase = "callerSubmit";
      startTurn(game, uid, now);
      game.public.revision += 1;
    }
    response = {success: true, type: "called", callerUid: uid,
      turnUid: game.public.turnUid};
    recordFinalCallCommand(game, commandId, uid, "called", now, response);
    return room;
  });
  if (!transaction.committed || !response) {
    throw new HttpsError("aborted", "CALL을 처리하지 못했습니다.");
  }
  return response;
});
