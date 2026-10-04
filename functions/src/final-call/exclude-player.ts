/* eslint-disable max-len, brace-style, valid-jsdoc, require-jsdoc */

import {FinalCallGameState} from "./types.js";

/** 투표가 승인된 플레이어를 게임에서 제외하고 다음 유효 상태를 만듭니다. */
export function excludeFinalCallPlayer(
  game: FinalCallGameState,
  uid: string,
  now: number,
): void {
  const leavingPlayer = game.public.players[uid];
  if (!leavingPlayer || leavingPlayer.status !== "alive") return;

  leavingPlayer.status = "eliminated";
  leavingPlayer.lives = 0;
  // 하트 소진에 의한 팀 탈락과 실제 퇴장은 다릅니다. 실제 퇴장으로
  // 2인 팀 구성이 깨지면 4·6인 모두 기존 인원 부족 종료 규칙을 유지합니다.
  finishFinalCallForInsufficientPlayers(game, now);
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
