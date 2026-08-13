/* eslint-disable valid-jsdoc */

import {LiarsPokerGameState} from "./common/types.js";

/** 마지막 생존자를 승자로 기록하고 게임을 종료합니다. */
export function finishGame(
  game: LiarsPokerGameState,
  winnerUid: string,
  now: number,
): void {
  game.public.status = "finished";
  game.public.finishReason = "winner";
  game.public.phase = "finished";
  game.public.turnUid = null;
  game.public.turnDeadlineAt = null;
  game.public.penaltyTargetUid = null;
  game.public.winnerUid = winnerUid;
  game.public.revision += 1;
  game.public.updatedAt = now;
  game.public.finishedAt = now;
  game.server.lastPlayCards = null;
}
