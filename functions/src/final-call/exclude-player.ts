/* eslint-disable max-len, brace-style, valid-jsdoc, require-jsdoc */

import {HttpsError} from "firebase-functions/v2/https";

import {
  orderedAlivePlayers,
  removeFinalTurnPendingPlayer,
  resolveFinalCallRound,
  startTurn,
} from "./game.js";
import {FinalCallGameState} from "./types.js";

/** 투표가 승인된 플레이어를 게임에서 제외하고 다음 유효 상태를 만듭니다. */
export function excludeFinalCallPlayer(
  game: FinalCallGameState,
  uid: string,
  now: number,
): void {
  const leavingPlayer = game.public.players[uid];
  if (!leavingPlayer || leavingPlayer.status !== "alive") return;

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
  delete game.server.finalSubmissions?.[uid];
  game.public.finalTurnPendingUids = removeFinalTurnPendingPlayer(
    game.public.finalTurnPendingUids,
    uid,
  );
  if (game.public.pendingDrawUid === uid) {
    game.public.pendingDrawUid = null;
    game.public.pendingDrawSource = null;
  }
  const alive = orderedAlivePlayers(game.public.players);

  // Final Call은 4인 2대2 고정 게임이므로 한 명이라도 제외되면 진행할 수 없습니다.
  if (alive.length < 4) {
    finishFinalCallForInsufficientPlayers(game, now);
  } else if (wasCurrentTurn &&
      (game.public.phase === "finalTurns" ||
       game.public.phase === "finalSubmit")) {
    if (game.public.finalTurnPendingUids.length === 0) {
      resolveFinalCallRound(game, now, false);
    } else {
      const allowed = new Set(game.public.finalTurnPendingUids);
      const nextUid = followingUids.find((playerUid) => allowed.has(playerUid));
      if (!nextUid) throw new HttpsError("data-loss", "다음 플레이어를 찾을 수 없습니다.");
      startTurn(game, nextUid, now);
    }
  } else if (wasCurrentTurn && game.public.phase === "callerSubmit") {
    if (game.public.finalTurnPendingUids.length === 0) {
      resolveFinalCallRound(game, now, false);
    } else {
      game.public.phase = "finalTurns";
      const nextUid = followingUids.find((playerUid) =>
        game.public.finalTurnPendingUids.includes(playerUid));
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
}

export function finishFinalCallForInsufficientPlayers(
  game: FinalCallGameState,
  now: number,
): void {
  game.public.status = "finished";
  game.public.finishReason = "insufficientPlayers";
  game.public.phase = "finished";
  game.public.winnerUid = null;
  game.public.winnerUids = [];
  game.public.winningTeam = null;
  game.public.turnUid = null;
  game.public.turnDeadlineAt = null;
  game.public.callerUid = null;
  game.public.pendingDrawUid = null;
  game.public.pendingDrawSource = null;
  game.public.finalTurnPendingUids = [];
  game.public.finishedAt = now;
  game.private = {};
  delete game.server.pendingHands;
  delete game.server.finalSubmissions;
  delete game.public.roundResult;
  delete game.public.resultRevealCompletedAt;
}
