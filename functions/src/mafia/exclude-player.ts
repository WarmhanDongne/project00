/* eslint-disable max-len, valid-jsdoc, require-jsdoc */

import {
  alivePlayers,
  checkMafiaWinner,
  finishMafiaGame,
  killMafiaPlayer,
  resolveMafiaVoting,
} from "./game.js";
import {actsAtNight, MAFIA_MIN_PLAYERS} from "./roles.js";
import {MafiaGameState} from "./types.js";

/**
 * 투표가 승인된 플레이어를 게임에서 제외하고 다음 유효 상태를 만듭니다.
 *
 * 마피아는 턴제가 아니라 단계제이므로, 제외로 **그 단계가 끝나 버리는 경우**만
 * 신경 쓰면 됩니다. 마지막으로 남은 밤 행동자나 투표자가 빠지면 그 자리에서
 * 단계를 해결해야 게임이 멈추지 않습니다.
 */
export function excludeMafiaPlayer(
  game: MafiaGameState,
  uid: string,
  now: number,
): void {
  const leaving = game.public.players[uid];
  if (!leaving || leaving.status !== "alive") return;

  // 사망 처리와 같은 길을 씁니다. 관전 화면을 볼 수 있게 신분표도 넘겨 줍니다.
  killMafiaPlayer(game, uid, "left", now);

  // 남긴 선택을 지웁니다. 지우지 않으면 없는 사람의 표가 개표에 섞입니다.
  delete game.server.nightActions?.[uid];
  delete game.server.votes?.[uid];
  for (const entry of Object.values(game.private)) {
    delete entry.allySelections?.[uid];
  }

  const alive = alivePlayers(game.public.players);
  if (alive.length < MAFIA_MIN_PLAYERS) {
    finishMafiaForInsufficientPlayers(game, now);
    return;
  }

  // 인원이 줄었으니 승패가 이미 결정됐을 수 있습니다.
  const winner = checkMafiaWinner(game);
  if (winner) {
    finishMafiaGame(
      game,
      winner,
      winner === "mafia" ? "mafiaWin" : "citizenWin",
      now,
    );
    return;
  }

  // 남은 사람 기준으로 단계 인원을 다시 셉니다.
  if (game.public.phase === "night") {
    game.public.nightActorCount = alive
      .filter((player) => actsAtNight(game.server.roles[player.uid])).length;
    game.public.nightSubmittedCount =
      Object.keys(game.server.nightActions ?? {}).length;
    // 확정(2026-08): 남은 행동자가 없어져도 밤은 마감까지 유지합니다.
  } else if (game.public.phase === "voting") {
    game.public.voteEligibleCount = alive.length;
    game.public.voteSubmittedCount = Object.keys(game.server.votes ?? {}).length;
    game.public.voteSubmittedUids = Object.keys(game.server.votes ?? {});
    if (game.public.voteSubmittedCount >= game.public.voteEligibleCount) {
      resolveMafiaVoting(game, now);
      return;
    }
  }

  game.public.revision += 1;
  game.public.updatedAt = now;
}

/** 최소 인원을 채우지 못해 게임을 끝냅니다. */
export function finishMafiaForInsufficientPlayers(
  game: MafiaGameState,
  now: number,
): void {
  finishMafiaGame(game, null, "insufficientPlayers", now);
  game.public.nightSubmittedCount = 0;
  game.public.nightActorCount = 0;
  game.public.voteSubmittedCount = 0;
  game.public.voteEligibleCount = 0;
  delete game.public.morningResult;
  delete game.public.voteResult;
  delete game.server.nightActions;
  delete game.server.votes;
}
