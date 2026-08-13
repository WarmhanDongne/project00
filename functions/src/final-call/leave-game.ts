/* eslint-disable max-len, brace-style, block-spacing */

import {getDatabase} from "firebase-admin/database";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {orderedAlivePlayers, resolveFinalCallRound, startTurn} from "./game.js";
import {FinalCallRoom} from "./types.js";
import {FINAL_CALL_REGION, finalCallRoomCode, finalCallUid, requireFinalCallGame} from "./validation.js";

type Data = {roomCode?: unknown};

/** 플레이어를 방과 게임에서 제거하고 필요한 경우 다음 턴을 결정합니다. */
export const leaveFinalCallGame = onCall<Data>(
  {region: FINAL_CALL_REGION},
  async (request) => {
    const uid = finalCallUid(request);
    const roomCode = finalCallRoomCode(request.data?.roomCode);
    const roomRef = getDatabase().ref(`rooms/${roomCode}`);
    let response: Record<string, unknown> | null = null;
    const transaction = await roomRef.transaction((raw) => {
      if (raw === null) return raw;
      const room = raw as FinalCallRoom;
      const roomPlayer = room.players?.[uid];
      if (!roomPlayer) {
        response = {success: true, alreadyLeft: true};
        return room;
      }
      delete room.players?.[uid];
      if (!room.game || room.game.public.gameType !== "final_call") {
        response = {success: true};
        return room;
      }

      const game = requireFinalCallGame(room);
      const leavingPlayer = game.public.players[uid];
      if (!leavingPlayer) {
        response = {success: true};
        return room;
      }
      const wasCurrentTurn = game.public.turnUid === uid;
      const orderedBeforeLeave = orderedAlivePlayers(game.public.players);
      const leavingIndex = orderedBeforeLeave.findIndex((player) => player.uid === uid);
      const followingUids = leavingIndex < 0 ? [] : [
        ...orderedBeforeLeave.slice(leavingIndex + 1),
        ...orderedBeforeLeave.slice(0, leavingIndex),
      ].map((player) => player.uid).filter((playerUid) => playerUid !== uid);
      leavingPlayer.status = "eliminated";
      leavingPlayer.lives = 0;
      delete game.private[uid];
      delete game.server.pendingHands?.[uid];
      game.public.finalTurnPendingUids = game.public.finalTurnPendingUids
        .filter((playerUid) => playerUid !== uid);
      if (game.public.pendingDrawUid === uid) {
        game.public.pendingDrawUid = null;
        game.public.pendingDrawSource = null;
      }
      const now = Date.now();
      const alive = orderedAlivePlayers(game.public.players);

      if (alive.length <= 1) {
        game.public.status = "finished";
        game.public.phase = "finished";
        game.public.winnerUid = alive[0]?.uid ?? null;
        game.public.turnUid = null;
        game.public.turnDeadlineAt = null;
        game.public.finishedAt = now;
      } else if (wasCurrentTurn && game.public.phase === "finalTurns") {
        if (game.public.finalTurnPendingUids.length === 0) {
          resolveFinalCallRound(game, now, false);
        } else {
          const allowed = new Set(game.public.finalTurnPendingUids);
          const nextUid = followingUids.find((playerUid) => allowed.has(playerUid));
          if (!nextUid) throw new HttpsError("data-loss", "다음 플레이어를 찾을 수 없습니다.");
          startTurn(game, nextUid, now);
        }
      } else if (wasCurrentTurn && game.public.phase === "playing") {
        const nextUid = followingUids[0];
        if (!nextUid) throw new HttpsError("data-loss", "다음 플레이어를 찾을 수 없습니다.");
        startTurn(game, nextUid, now);
      } else if (wasCurrentTurn && game.public.phase === "dealing") {
        game.public.turnUid = alive[0].uid;
      }
      game.public.revision += 1;
      game.public.updatedAt = now;
      response = {success: true, status: game.public.status, turnUid: game.public.turnUid};
      return room;
    });
    if (!transaction.committed || !response) {
      throw new HttpsError("aborted", "게임 퇴장을 처리하지 못했습니다.");
    }
    return response;
  },
);
