/* eslint-disable max-len, brace-style, block-spacing */

import {getDatabase} from "firebase-admin/database";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {finalCallProcessed, recordFinalCallCommand} from "./commands.js";
import {resolveFinalCallRound} from "./game.js";
import {FinalCallRoom} from "./types.js";
import {
  assertFinalCallTurn,
  FINAL_CALL_REGION,
  finalCallCommandId,
  finalCallRoomCode,
  finalCallUid,
  requireFinalCallGame,
} from "./validation.js";

type Data = {roomCode?: unknown; commandId?: unknown; source?: unknown};

export const game_final_call_draw_card = onCall<Data>(
  {region: FINAL_CALL_REGION},
  async (request) => {
    const uid = finalCallUid(request);
    const roomCode = finalCallRoomCode(request.data?.roomCode);
    const commandId = finalCallCommandId(request.data?.commandId);
    const source = request.data?.source;
    if (source !== "deck" && source !== "discard") {
      throw new HttpsError("invalid-argument", "카드를 가져올 위치를 선택해주세요.");
    }
    const roomRef = getDatabase().ref(`rooms/${roomCode}`);
    let response: Record<string, unknown> | null = null;
    const transaction = await roomRef.transaction((raw) => {
      if (raw === null) return raw;
      const room = raw as FinalCallRoom;
      const game = requireFinalCallGame(room);
      const previous = finalCallProcessed(game, commandId);
      if (previous) { response = previous; return room; }
      assertFinalCallTurn(game, uid);
      if (game.public.phase !== "playing" && game.public.phase !== "finalTurns") {
        throw new HttpsError("failed-precondition", "현재 카드를 가져올 수 없습니다.");
      }
      // Realtime Database는 null 필드를 저장하지 않아 읽을 때 undefined가 됩니다.
      if (game.public.pendingDrawUid) {
        throw new HttpsError("failed-precondition", "이미 가져온 카드를 처리해주세요.");
      }
      const privatePlayer = game.private[uid];
      if (!privatePlayer) throw new HttpsError("data-loss", "손패가 없습니다.");
      if (source === "deck" && game.server.deck.length === 0) {
        resolveFinalCallRound(game, Date.now(), true);
        response = {success: true, type: "automaticCall"};
        recordFinalCallCommand(game, commandId, uid, "automaticCall", Date.now(), response);
        return room;
      }
      const card = source === "deck" ? game.server.deck.pop() : game.public.discardCard;
      if (!card) throw new HttpsError("data-loss", "가져올 카드가 없습니다.");
      privatePlayer.pendingDraw = card;
      game.public.pendingDrawUid = uid;
      game.public.pendingDrawSource = source;
      game.public.deckRemainingCount = game.server.deck.length;
      game.public.turnDeadlineAt = Date.now() + 30000;
      game.public.revision += 1;
      game.public.updatedAt = Date.now();
      response = {success: true, type: "cardDrawn", source, card};
      recordFinalCallCommand(game, commandId, uid, "cardDrawn", Date.now(), response);
      return room;
    });
    if (!transaction.committed || !response) {
      throw new HttpsError("aborted", "카드를 가져오지 못했습니다.");
    }
    return response;
  },
);
