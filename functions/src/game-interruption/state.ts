/* eslint-disable max-len, valid-jsdoc, require-jsdoc */

import {
  GameInterruptionReason,
  InterruptibleGameState,
  PublicGameInterruption,
} from "./types.js";

export const GAME_INTERRUPTION_VOTE_MS = 60000;
export const PLAYER_HEARTBEAT_STALE_MS = 20000;

type RoomPlayer = Record<string, unknown>;

export interface InterruptibleRoom {
  players?: Record<string, RoomPlayer>;
  game?: InterruptibleGameState;
}

export type StalePlayerResult =
  "disconnected" | "already-disconnected" | "heartbeat-recovered" |
  "not-stale" | "not-playing" | "player-missing";

/**
 * 태블릿의 stale 후보를 transaction의 최신 room 값으로 다시 검증합니다.
 * presence 변경과 게임 중단을 같은 transaction에서 수행하므로 늦은
 * onDisconnect·중복 callable은 revision을 다시 올리지 않습니다.
 */
export function disconnectStaleGamePlayer(
  room: InterruptibleRoom,
  playerUid: string,
  observedLastSeen: number,
  now: number,
  options: {minimumPlayerCount?: number} = {},
): StalePlayerResult {
  const game = room.game;
  if (!game || game.public.status !== "playing") return "not-playing";
  const player = room.players?.[playerUid];
  if (!player || player.role !== "player" || player.status !== "active") {
    return "player-missing";
  }
  if (player.isConnected !== true) return "already-disconnected";
  const latestLastSeen = finiteOrNull(player.lastSeen);
  if (latestLastSeen === null || latestLastSeen > observedLastSeen) {
    return "heartbeat-recovered";
  }
  if (now - latestLastSeen <= PLAYER_HEARTBEAT_STALE_MS) return "not-stale";

  player.isConnected = false;
  reconcileGamePlayerConnection(
    room,
    playerUid,
    true,
    false,
    now,
    options,
  );
  return "disconnected";
}

/**
 * 접속 이벤트와 트랜잭션 시점의 최신 presence를 함께 확인해 중단 상태를 갱신합니다.
 *
 * Cloud Functions 트리거는 false/true 이벤트가 매우 가깝게 발생하면 실행 순서가
 * 뒤바뀔 수 있습니다. false 이벤트를 처리할 때 이미 현재 값이 true라면 오래된
 * 단절 이벤트이므로 게임을 다시 멈추지 않습니다.
 */
export function reconcileGamePlayerConnection(
  room: InterruptibleRoom,
  playerUid: string,
  wasConnected: boolean,
  isConnected: boolean,
  now: number,
  options: {minimumPlayerCount?: number} = {},
): void {
  const game = room.game;
  if (!game || game.public.status !== "playing") return;

  if (isConnected) {
    // 첫 복구 이벤트가 두 번째 단절 뒤 도착할 수 있습니다.
    if (room.players?.[playerUid]?.isConnected !== true) return;
    const interruption = game.public.interruption;
    if (interruption?.playerUid === playerUid) {
      cancelGameInterruption(game, interruption.id, now);
    }
    return;
  }

  if (!wasConnected) return;
  if (room.players?.[playerUid]?.isConnected === true) return;
  beginGameInterruption(room, playerUid, "disconnected", now, options);
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
    playerCharacterId: stringValue(roomPlayer?.characterId) ||
      stringValue(publicPlayer.characterId) || "frog",
    reason,
    startedAt: now,
    deadlineAt: now + (options.durationMs ?? GAME_INTERRUPTION_VOTE_MS),
    eligibleVoterUids,
    requiredVotes,
    remainingPlayerCount: remainingAliveUids.length,
    minimumPlayerCount,
    canContinue,
  };

  const oldDeadline = finiteOrNull(game.public.turnDeadlineAt);
  game.server.interruption = {
    id: interruption.id,
    previousTurnRemainingMs: oldDeadline === null ?
      null : Math.max(0, oldDeadline - now),
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
    const remaining = finiteOrNull(saved.previousTurnRemainingMs);
    const controllerPause = game.server.controllerPause;
    if (controllerPause) {
      // 남아 있는 중단에 시간을 넘기고 마지막 원인이 해소될 때만 재개합니다.
      if (remaining !== null) controllerPause.previousTurnRemainingMs = remaining;
      game.public.turnDeadlineAt = null;
    } else {
      game.public.turnDeadlineAt = remaining === null ? null : now + remaining;
    }
  }
  delete game.server.interruption;
}

/**
 * 숫자로 계산해도 안전한 값만 통과시킵니다.
 *
 * RTDB는 `null`을 저장하지 않고 **키를 지웁니다.** 그래서 다시 읽으면
 * `undefined`가 되는데, 이것을 그대로 계산에 쓰면 `undefined - now`가 NaN이
 * 되고 RTDB가 쓰기를 거부합니다(`Data returned contains NaN`).
 *
 * 실제로 마피아 아침·개표 발표는 `turnDeadlineAt`이 없는 구간이라, 그때 나가면
 * `game_mafia_leave_game`이 이 NaN 때문에 실패했습니다(2026-08 수정).
 *
 * @param {unknown} value 검사할 값
 * @return {number|null} 유한한 숫자면 그 값, 아니면 null
 */
function finiteOrNull(value: unknown): number | null {
  return typeof value === "number" && Number.isFinite(value) ? value : null;
}

function stringValue(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}
