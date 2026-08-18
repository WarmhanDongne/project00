/* eslint-disable max-len, brace-style, block-spacing */

import {getDatabase} from "firebase-admin/database";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {assertControllerSession} from "../room/controller-session.js";
import {nextFinalCallPlayer, resolveFinalCallRound,
  selectBestFinalCallCombination, startTurn} from "./game.js";
import {FinalCallCard, FinalCallRoom} from "./types.js";
import {FINAL_CALL_REGION, finalCallRoomCode, finalCallUid, requireFinalCallGame} from "./validation.js";

type Data = {roomCode?: unknown; controllerSessionId?: unknown};

/** 30초가 지난 현재 턴의 카드를 자동으로 버리고 다음 턴을 시작합니다. */
export const timeoutFinalCallTurn = onCall<Data>(
  {region: FINAL_CALL_REGION},
  async (request) => {
    const requesterUid = finalCallUid(request);
    const roomCode = finalCallRoomCode(request.data?.roomCode);
    const roomRef = getDatabase().ref(`rooms/${roomCode}`);
    let response: Record<string, unknown> | null = null;
    const transaction = await roomRef.transaction((raw) => {
      if (raw === null) return raw;
      const room = raw as FinalCallRoom;
      const game = requireFinalCallGame(room);
      const controllerUid = room.controllerUid ?? room.hostUid;
      const turnUid = game.public.turnUid;
      if (requesterUid !== controllerUid && requesterUid !== turnUid) {
        throw new HttpsError("permission-denied", "현재 턴을 종료할 권한이 없습니다.");
      }
      if (requesterUid === controllerUid) {
        assertControllerSession(room, requesterUid, request.data?.controllerSessionId);
      }
      const deadline = game.public.turnDeadlineAt;
      const now = Date.now();
      if (!turnUid || deadline === null || now < deadline) {
        response = {success: true, ignored: true};
        return room;
      }
      if (game.public.phase === "callerSubmit") {
        if (game.public.callerUid !== turnUid) {
          throw new HttpsError("data-loss", "CALL 선언자를 확인할 수 없습니다.");
        }
        game.server.finalSubmissions ??= {};
        game.server.finalSubmissions[turnUid] = selectBestFinalCallCombination(
          Object.values(game.private[turnUid]?.hand ?? {}),
        );
        if (game.public.finalTurnPendingUids.length === 0) {
          resolveFinalCallRound(game, now, false);
        } else {
          game.public.phase = "finalTurns";
          const allowed = new Set(game.public.finalTurnPendingUids);
          startTurn(game, nextFinalCallPlayer(game.public.players, turnUid, allowed), now);
          game.public.revision += 1;
        }
        response = {success: true, type: "callerHandAutoSubmitted", turnUid: game.public.turnUid};
        return room;
      }
      if (game.public.phase === "finalSubmit") {
        game.server.finalSubmissions ??= {};
        game.server.finalSubmissions[turnUid] = selectBestFinalCallCombination(
          Object.values(game.private[turnUid]?.hand ?? {}),
        );
        game.public.finalTurnPendingUids = game.public.finalTurnPendingUids
          .filter((uid) => uid !== turnUid);
        if (game.public.finalTurnPendingUids.length === 0) {
          resolveFinalCallRound(game, now, false);
        } else {
          game.public.phase = "finalTurns";
          const allowed = new Set(game.public.finalTurnPendingUids);
          startTurn(game, nextFinalCallPlayer(game.public.players, turnUid, allowed), now);
          game.public.revision += 1;
        }
        response = {success: true, type: "finalHandAutoSubmitted", turnUid: game.public.turnUid};
        return room;
      }
      if (game.public.phase !== "playing" && game.public.phase !== "finalTurns") {
        response = {success: true, ignored: true};
        return room;
      }

      const privatePlayer = game.private[turnUid];
      if (!privatePlayer) throw new HttpsError("data-loss", "현재 플레이어의 손패가 없습니다.");
      let discarded: FinalCallCard | undefined = privatePlayer.pendingDraw;
      if (!discarded) {
        if (game.server.deck.length === 0) {
          resolveFinalCallRound(game, now, true);
          response = {success: true, type: "automaticCall"};
          return room;
        }
        discarded = game.server.deck.pop();
      }
      if (!discarded) throw new HttpsError("data-loss", "자동으로 버릴 카드가 없습니다.");
      delete privatePlayer.pendingDraw;
      game.public.discardCard = discarded;
      game.public.deckRemainingCount = game.server.deck.length;
      game.public.pendingDrawUid = null;
      game.public.pendingDrawSource = null;

      if (game.server.deck.length === 0) {
        resolveFinalCallRound(game, now, true);
      } else if (game.public.phase === "finalTurns") {
        // 마지막 교체 시간이 끝나도 제출 단계를 생략하지 않습니다.
        // 자동으로 새 카드를 버린 뒤 같은 플레이어에게 최종 조합을 고를
        // 별도의 30초를 부여합니다.
        game.public.phase = "finalSubmit";
        startTurn(game, turnUid, now);
        game.public.revision += 1;
      } else {
        startTurn(game, nextFinalCallPlayer(game.public.players, turnUid), now);
        game.public.revision += 1;
      }
      game.public.updatedAt = now;
      response = {success: true, type: "turnTimedOut", turnUid: game.public.turnUid};
      return room;
    });
    if (!transaction.committed || !response) {
      throw new HttpsError("aborted", "제한 시간 종료를 처리하지 못했습니다.");
    }
    return response;
  },
);
