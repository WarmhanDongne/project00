/* eslint-disable max-len, brace-style, block-spacing */

import {getDatabase} from "firebase-admin/database";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {finalCallProcessed, recordFinalCallCommand} from "./commands.js";
import {nextFinalCallPlayer, resolveFinalCallRound, startTurn} from "./game.js";
import {FinalCallRoom} from "./types.js";
import {FINAL_CALL_REGION, finalCallCommandId, finalCallRoomCode, finalCallUid, requireFinalCallGame} from "./validation.js";

type Data = {roomCode?: unknown; commandId?: unknown; cardIds?: unknown};

/** 현재 플레이어가 손패에서 실제 공개할 최종 점수 조합만 제출합니다. */
export const submitFinalCallHand = onCall<Data>(
  {region: FINAL_CALL_REGION},
  async (request) => {
    const uid = finalCallUid(request);
    const roomCode = finalCallRoomCode(request.data?.roomCode);
    const commandId = finalCallCommandId(request.data?.commandId);
    const cardIds = Array.isArray(request.data?.cardIds) ?
      request.data.cardIds.filter((value): value is string => typeof value === "string") : [];
    const roomRef = getDatabase().ref(`rooms/${roomCode}`);
    let response: Record<string, unknown> | null = null;
    const transaction = await roomRef.transaction((raw) => {
      if (raw === null) return raw;
      const room = raw as FinalCallRoom;
      const game = requireFinalCallGame(room);
      const previous = finalCallProcessed(game, commandId);
      if (previous) { response = previous; return room; }
      const isCallerSubmission = game.public.phase === "callerSubmit" &&
        game.public.callerUid === uid;
      const isFinalTurnSubmission = game.public.phase === "finalSubmit" &&
        game.public.finalTurnPendingUids.includes(uid);
      if (game.public.turnUid !== uid ||
          (!isCallerSubmission && !isFinalTurnSubmission)) {
        throw new HttpsError("failed-precondition", "현재 최종 손패를 제출할 수 없습니다.");
      }
      const handIds = Object.keys(game.private[uid]?.hand ?? {}).sort();
      const submittedIds = [...new Set(cardIds)];
      const sortedSubmittedIds = [...submittedIds].sort();
      const handIdSet = new Set(handIds);
      if (handIds.length !== 4 || submittedIds.length < 1 ||
          submittedIds.length > 4 ||
          sortedSubmittedIds.some((cardId) => !handIdSet.has(cardId))) {
        throw new HttpsError("invalid-argument", "현재 손패에서 점수 조합을 선택해주세요.");
      }
      const now = Date.now();
      const privateHand = game.private[uid]?.hand ?? {};
      game.server.finalSubmissions ??= {};
      game.server.finalSubmissions[uid] = submittedIds
        .map((cardId) => privateHand[cardId]);

      if (isFinalTurnSubmission) {
        game.public.finalTurnPendingUids = game.public.finalTurnPendingUids
          .filter((playerUid) => playerUid !== uid);
      }

      if (game.public.finalTurnPendingUids.length === 0) {
        resolveFinalCallRound(game, now, false);
      } else {
        game.public.phase = "finalTurns";
        const allowed = new Set(game.public.finalTurnPendingUids);
        startTurn(game, nextFinalCallPlayer(game.public.players, uid, allowed), now);
        game.public.revision += 1;
      }
      response = {success: true, type: "finalHandSubmitted", turnUid: game.public.turnUid};
      recordFinalCallCommand(game, commandId, uid, "finalHandSubmitted", now, response);
      return room;
    });
    if (!transaction.committed || !response) {
      throw new HttpsError("aborted", "최종 손패를 제출하지 못했습니다.");
    }
    return response;
  },
);
