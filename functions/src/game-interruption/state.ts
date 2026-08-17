/* eslint-disable max-len, valid-jsdoc, require-jsdoc */

import {
  GameInterruptionReason,
  InterruptibleGameState,
  PublicGameInterruption,
} from "./types.js";

export const GAME_INTERRUPTION_VOTE_MS = 60000;

type RoomPlayer = Record<string, unknown>;

export interface InterruptibleRoom {
  players?: Record<string, RoomPlayer>;
  game?: InterruptibleGameState;
}

/** 진행 상태를 멈추고 모든 게임이 공유하는 공개 중단 상태를 만듭니다. */
export function beginGameInterruption(
  room: InterruptibleRoom,
  playerUid: string,
  reason: GameInterruptionReason,
  now: number,
  options: {durationMs?: number; minimumPlayerCount?: number} = {},
): PublicGameInterruption | null {
  const game = room.game;
  if (!game || game.public.status !== "playing") return null;
  if (game.public.players[playerUid]?.status !== "alive") return null;

  const current = game.public.interruption;
  if (current) return current.playerUid === playerUid ? current : null;

  const remainingAliveUids = Object.entries(game.public.players)
    .filter(([uid, player]) => uid !== playerUid && player.status === "alive")
    .map(([uid]) => uid);
  const eligibleVoterUids = remainingAliveUids.filter((uid) => {
    const roomPlayer = room.players?.[uid];
    return roomPlayer && roomPlayer.isConnected !== false;
  });
  const minimumPlayerCount = Math.max(1, options.minimumPlayerCount ?? 2);
  const canContinue = remainingAliveUids.length >= minimumPlayerCount;
  const requiredVotes = canContinue ? Math.floor(eligibleVoterUids.length / 2) + 1 : 0;
  const roomPlayer = room.players?.[playerUid];
  const publicPlayer = game.public.players[playerUid] as Record<string, unknown>;
  const interruption: PublicGameInterruption = {
    id: `${playerUid}-${now}`,
    playerUid,
    playerNickname: stringValue(roomPlayer?.nickname) ||
      stringValue(publicPlayer.nickname) || "플레이어",
    playerProfileImageUrl: stringValue(roomPlayer?.profileImageUrl) ||
      stringValue(publicPlayer.profileImageUrl),
    reason,
    startedAt: now,
    deadlineAt: now + (options.durationMs ?? GAME_INTERRUPTION_VOTE_MS),
    eligibleVoterUids,
    requiredVotes,
    remainingPlayerCount: remainingAliveUids.length,
    minimumPlayerCount,
    canContinue,
  };

  const oldDeadline = game.public.turnDeadlineAt;
  game.server.interruption = {
    id: interruption.id,
    previousTurnRemainingMs: oldDeadline === null ? null : Math.max(0, oldDeadline - now),
  };
  game.public.turnDeadlineAt = null;
  game.public.interruption = interruption;
  game.public.revision += 1;
  game.public.updatedAt = now;
  return interruption;
}

/** 연결 복구 시 기존 턴의 남은 시간만 복원합니다. */
export function cancelGameInterruption(
  game: InterruptibleGameState,
  interruptionId: string,
  now: number,
): boolean {
  const interruption = game.public.interruption;
  if (!interruption || interruption.id !== interruptionId) return false;
  restoreTurnDeadline(game, interruptionId, now);
  delete game.public.interruption;
  game.public.revision += 1;
  game.public.updatedAt = now;
  return true;
}

/** 플레이어 제외가 끝난 뒤 보관해 둔 턴 시간을 복원합니다. */
export function completeGameInterruption(
  game: InterruptibleGameState,
  interruptionId: string,
  now: number,
): void {
  restoreTurnDeadline(game, interruptionId, now);
  delete game.public.interruption;
}

function restoreTurnDeadline(
  game: InterruptibleGameState,
  interruptionId: string,
  now: number,
): void {
  const saved = game.server.interruption;
  if (saved?.id === interruptionId && game.public.status === "playing") {
    game.public.turnDeadlineAt = saved.previousTurnRemainingMs === null ?
      null : now + saved.previousTurnRemainingMs;
  }
  delete game.server.interruption;
}

function stringValue(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}
