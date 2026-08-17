/* eslint-disable max-len, brace-style, block-spacing */

import {getDatabase} from "firebase-admin/database";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {finalCallProcessed, recordFinalCallCommand} from "./commands.js";
import {nextFinalCallPlayer, resolveFinalCallRound, startTurn} from "./game.js";
import {FinalCallCard, FinalCallRoom} from "./types.js";
import {
  assertFinalCallTurn,
  FINAL_CALL_REGION,
  finalCallCommandId,
  finalCallRoomCode,
  finalCallUid,
  requireFinalCallGame,
} from "./validation.js";

type Data = {roomCode?: unknown; commandId?: unknown; replaceCardId?: unknown};

export const completeFinalCallTurn = onCall<Data>(
  {region: FINAL_CALL_REGION},
  async (request) => {
    const uid = finalCallUid(request);
    const roomCode = finalCallRoomCode(request.data?.roomCode);
    const commandId = finalCallCommandId(request.data?.commandId);
    const replaceCardId = typeof request.data?.replaceCardId === "string" ?
      request.data.replaceCardId : null;
    const roomRef = getDatabase().ref(`rooms/${roomCode}`);
    let response: Record<string, unknown> | null = null;
    const transaction = await roomRef.transaction((raw) => {
      if (raw === null) return raw;
      const room = raw as FinalCallRoom;
      const game = requireFinalCallGame(room);
      const previous = finalCallProcessed(game, commandId);
      if (previous) { response = previous; return room; }
      assertFinalCallTurn(game, uid);
      if (game.public.pendingDrawUid !== uid) {
        throw new HttpsError("failed-precondition", "먼저 카드를 가져와야 합니다.");
      }
      const privatePlayer = game.private[uid];
      const drawnCard = privatePlayer?.pendingDraw;
      if (!privatePlayer || !drawnCard) throw new HttpsError("data-loss", "가져온 카드가 없습니다.");

      let discarded: FinalCallCard = drawnCard;
      if (replaceCardId !== null) {
        const replaced = privatePlayer.hand[replaceCardId];
        if (!replaced) throw new HttpsError("invalid-argument", "교체할 손패가 없습니다.");
        delete privatePlayer.hand[replaceCardId];
        privatePlayer.hand[drawnCard.id] = drawnCard;
        discarded = replaced;
      }
      delete privatePlayer.pendingDraw;
      game.public.discardCard = discarded;
      game.public.pendingDrawUid = null;
      game.public.pendingDrawSource = null;
      const now = Date.now();

      if (game.server.deck.length === 0) {
        resolveFinalCallRound(game, now, true);
      } else if (game.public.phase === "finalTurns") {
        // =======================마지막 교체 후 최종 조합 선택==============================
        // CALL하지 않은 플레이어도 마지막 교체를 마친 뒤 같은 턴에서 최종
        // 점수 조합을 직접 선택합니다. 제출이 끝나기 전에는 다음 플레이어로
        // 넘기지 않습니다.
        game.public.phase = "finalSubmit";
        startTurn(game, uid, now);
        game.public.revision += 1;
      } else {
        startTurn(game, nextFinalCallPlayer(game.public.players, uid), now);
        game.public.revision += 1;
      }
      game.public.updatedAt = now;
      response = {success: true, type: "turnCompleted", phase: game.public.phase,
        turnUid: game.public.turnUid};
      recordFinalCallCommand(game, commandId, uid, "turnCompleted", now, response);
      return room;
    });
    if (!transaction.committed || !response) {
      throw new HttpsError("aborted", "카드 교체를 완료하지 못했습니다.");
    }
    return response;
  },
);
