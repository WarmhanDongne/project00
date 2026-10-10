/* eslint-disable require-jsdoc, valid-jsdoc, max-len */
import {HttpsError} from "firebase-functions/v2/https";
import {assertRoomTarget, SessionRoom} from "../room/session-contract.js";

export interface GameContext {
  gameInstanceId: string;
  phaseSeq: number;
  turnSeq: number;
  dataSeq: number;
  resumeEpoch: number;
}

export interface RecoveryCause {
  incidentId: string;
  uid: string;
  role: "player" | "controller";
  reason: "disconnected" | "preparationFailed";
  startedAt: number;
  deadlineAt?: number;
  extended: boolean;
  awaitingDecision: boolean;
  canContinue?: boolean;
}

export interface RecoveryPublic {
  paused: boolean;
  pauseId: string;
  pausedAt: number;
  causes: Record<string, RecoveryCause>;
}

interface PreparedReport extends GameContext {
  connectionId: string;
  connectionSeq: number;
}

export type RecoveryTimer = {kind: "none"} | {kind: "remaining"; remainingMs: number; phaseSeq: number; turnSeq: number};
export function recoveryTimer(deadline: unknown, now: number, phaseSeq: number, turnSeq: number): RecoveryTimer {
  return typeof deadline === "number" && Number.isFinite(deadline) ?
    {kind: "remaining", remainingMs: Math.max(0, deadline - now), phaseSeq, turnSeq} : {kind: "none"};
}
interface RecoveryServer {
  startedAt: number;
  timer: RecoveryTimer;
  ready: Record<string, PreparedReport>;
}

export interface RecoveryGame {
  public: Partial<GameContext> & {
    status: string;
    revision: number;
    updatedAt: number;
    turnDeadlineAt?: number | null;
    players: Record<string, {status: string; [key: string]: unknown}>;
    recovery?: RecoveryPublic;
    [key: string]: unknown;
  };
  private?: Record<string, Record<string, unknown>>;
  server: {
    recovery?: RecoveryServer;
    recoveryReports?: Record<string, {connectionId: string; reportSeq: number}>;
    [key: string]: unknown;
  };
}

export interface RecoveryRoom extends SessionRoom {
  selectedGame?: string;
  game?: RecoveryGame;
}

export function gameContext(game: RecoveryGame): GameContext {
  const pub = game.public;
  if (!pub.gameInstanceId) throw new HttpsError("failed-precondition", "게임 세션이 없습니다.");
  return {
    gameInstanceId: pub.gameInstanceId, phaseSeq: pub.phaseSeq ?? 0,
    turnSeq: pub.turnSeq ?? 0, dataSeq: pub.dataSeq ?? 0, resumeEpoch: pub.resumeEpoch ?? 0,
  };
}

export function requiredRecoveryKeys(room: RecoveryRoom): string[] {
  const keys = room.controllerUid ? [`controller:${room.controllerUid}`] : [];
  for (const [uid, player] of Object.entries(room.game?.public.players ?? {})) {
    if (player.status === "alive" && room.players?.[uid]?.status === "active") keys.push(`player:${uid}`);
  }
  return keys;
}

export function privateRequired(game: RecoveryGame): boolean {
  return !((game.public.gameType === "liars_poker" || game.public.gameType === "final_call") &&
    game.public.phase === "dealing");
}

function sameContext(a: Partial<GameContext>, b: GameContext): boolean {
  return a.gameInstanceId === b.gameInstanceId && a.phaseSeq === b.phaseSeq &&
    a.turnSeq === b.turnSeq && a.dataSeq === b.dataSeq && a.resumeEpoch === b.resumeEpoch;
}

function touch(game: RecoveryGame, now: number): void {
  game.public.revision += 1;
  game.public.updatedAt = now;
}

export function beginRecoveryPause(
  room: RecoveryRoom, now: number, observedAt: number = now,
): void {
  const game = room.game;
  if (!game || game.public.status !== "playing" || game.public.recovery?.paused) return;
  const timerReferenceAt = Number.isFinite(observedAt) && observedAt >= 0 && observedAt <= now ? observedAt : now;
  game.public.resumeEpoch = (game.public.resumeEpoch ?? 0) + 1;
  const pauseId = `${game.public.gameInstanceId}-${game.public.resumeEpoch}`;
  const deadline = game.public.turnDeadlineAt;
  game.server.recovery = {
    startedAt: now,
    timer: recoveryTimer(deadline, timerReferenceAt, game.public.phaseSeq ?? 0, game.public.turnSeq ?? 0),
    ready: {},
  };
  game.public.recovery = {paused: true, pauseId, pausedAt: now, causes: {}};
  game.public.turnDeadlineAt = null;
  touch(game, now);
}

export function registerRecoveryFailure(
  room: RecoveryRoom, uid: string, role: "player" | "controller", now: number,
  reason: RecoveryCause["reason"] = "disconnected",
  observedAt: number = now,
): "paused" | "localOnly" | "ignored" {
  const game = room.game;
  if (!game || game.public.status !== "playing") return "ignored";
  const key = `${role}:${uid}`;
  if (!requiredRecoveryKeys(room).includes(key)) return "localOnly";
  beginRecoveryPause(room, now, observedAt);
  const recovery = game.public.recovery!;
  recovery.causes ??= {};
  delete game.server.recovery?.ready?.[key];
  if (!recovery.causes[key]) {
    recovery.causes[key] = {
      uid, role, reason, incidentId: `${recovery.pauseId}-${role}-${uid}-${now}`,
      startedAt: now, extended: false, awaitingDecision: false,
      ...(role === "player" ? {deadlineAt: now + 60000} : {}),
    };
    touch(game, now);
  }
  return "paused";
}

export function reportStaleController(
  room: RecoveryRoom, observedLastSeen: unknown, now: number,
): Record<string, unknown> {
  if (!Number.isSafeInteger(observedLastSeen) || (observedLastSeen as number) < 0) {
    throw new HttpsError("invalid-argument", "올바른 진행 기기 heartbeat 시각이 필요합니다.");
  }
  const uid = room.controllerUid;
  const connectionId = room.controllerCurrentConnectionId;
  const connectionSeq = room.controllerConnectionSeq;
  const connection = uid && connectionId ? room.connections?.[uid]?.[connectionId] : undefined;
  if (!uid || !connectionId || !Number.isSafeInteger(connectionSeq) || !connection ||
      connection.connectionSeq !== connectionSeq ||
      room.controllerPresence?.lastSeen !== observedLastSeen ||
      connection.lastSeen !== observedLastSeen) {
    return {status: "staleContext"};
  }
  if (connection.connected !== true || room.controllerPresence?.connected === false ||
      room.controllerConnected === false) {
    return {status: "alreadyDisconnected"};
  }
  if (now - (observedLastSeen as number) <= 20000) return {status: "notStale"};
  connection.connected = false;
  room.controllerConnected = false;
  room.controllerPresence = {connected: false, lastSeen: observedLastSeen as number};
  registerRecoveryFailure(room, uid, "controller", now, "disconnected", connection.lastSeen);
  return {status: "disconnected"};
}

export function clearFinishedRecovery(game: RecoveryGame): void {
  if (game.public.status !== "finished") return;
  delete game.public.recovery;
  delete game.server.recovery;
  delete game.server.recoveryReports;
  game.public.turnDeadlineAt = null;
}

export interface RecoveryReportInput extends Partial<GameContext> {
  uid: string;
  role: "player" | "controller";
  roomInstanceId: string;
  membershipId?: string;
  connectionId: string;
  connectionSeq: number;
  reportSeq: number;
  state: "ready" | "failed";
  screenUsable?: boolean;
  assetsReady?: boolean;
}

export function assertRecoveryConnection(room: RecoveryRoom, input: {
  uid: string; role: "player" | "controller"; membershipId?: string;
  connectionId: string; connectionSeq: number;
}, requireConnected = true): void {
  if ((room.status === "closed" || room.status === "terminal")) throw new HttpsError("failed-precondition", "종료된 방입니다.");
  const controller = input.role === "controller";
  const player = room.players?.[input.uid];
  const connection = room.connections?.[input.uid]?.[input.connectionId];
  if ((controller ? room.controllerUid !== input.uid ||
      room.controllerCurrentConnectionId !== input.connectionId || room.controllerConnectionSeq !== input.connectionSeq :
    !player || player.status !== "active" || player.membershipId !== input.membershipId ||
      player.currentConnectionId !== input.connectionId || player.connectionSeq !== input.connectionSeq) ||
      !connection || connection.roomInstanceId !== room.roomInstanceId ||
      connection.connectionSeq !== input.connectionSeq ||
      (requireConnected && connection.connected !== true)) {
    throw new HttpsError("permission-denied", "만료된 접속입니다.", {reason: "staleConnection"});
  }
}

/** Failed reports deliberately do not require current public/private data. */
export function applyRecoveryReport(room: RecoveryRoom, input: RecoveryReportInput, now: number): Record<string, unknown> {
  assertRoomTarget(room, input.roomInstanceId);
  assertRecoveryConnection(room, input);
  const game = room.game;
  if (!game || game.public.status !== "playing") return {status: "stale"};
  if (input.gameInstanceId !== game.public.gameInstanceId) return {status: "stale"};
  if (!Number.isSafeInteger(input.reportSeq) || input.reportSeq < 1) {
    throw new HttpsError("invalid-argument", "올바른 준비 보고 순서가 필요합니다.");
  }
  const key = `${input.role}:${input.uid}`;
  const previous = game.server.recoveryReports?.[key];
  if (previous?.connectionId === input.connectionId && previous.reportSeq >= input.reportSeq) {
    return {status: "ignored", context: gameContext(game)};
  }
  game.server.recoveryReports ??= {};
  game.server.recoveryReports[key] = {connectionId: input.connectionId, reportSeq: input.reportSeq};
  if (input.state === "failed") {
    const outcome = registerRecoveryFailure(room, input.uid, input.role, now, "preparationFailed");
    return {status: "accepted", outcome, context: gameContext(game)};
  }
  const context = gameContext(game);
  if (!sameContext(input, context) || input.screenUsable !== true || input.assetsReady !== true) {
    return {status: "staleContext", context};
  }
  if (input.role === "player" && requiredRecoveryKeys(room).includes(key) && privateRequired(game)) {
    const privateContext = game.private?.[input.uid]?._context as Partial<GameContext> | undefined;
    if (!privateContext || privateContext.gameInstanceId !== context.gameInstanceId ||
        privateContext.phaseSeq !== context.phaseSeq || privateContext.turnSeq !== context.turnSeq ||
        privateContext.dataSeq !== context.dataSeq) return {status: "dataMissing", context};
  }
  if (game.public.recovery?.paused && game.server.recovery) {
    game.server.recovery.ready ??= {};
    game.public.recovery.causes ??= {};
    game.server.recovery.ready[key] = {...context, connectionId: input.connectionId, connectionSeq: input.connectionSeq};
    delete game.public.recovery.causes[key];
    tryResumeRecovery(room, now);
    touch(game, now);
  }
  return {status: "accepted", paused: game.public.recovery?.paused === true, context: gameContext(game)};
}

export function tryResumeRecovery(room: RecoveryRoom, now: number): boolean {
  const game = room.game;
  const saved = game?.server.recovery;
  if (!game || game.public.status !== "playing" || !game.public.recovery?.paused || !saved ||
      Object.keys(game.public.recovery.causes ?? {}).length > 0) return false;
  const context = gameContext(game);
  for (const key of requiredRecoveryKeys(room)) {
    const report = saved.ready?.[key];
    if (!report || !sameContext(report, context)) return false;
    const split = key.indexOf(":");
    const role = key.slice(0, split) as "controller" | "player";
    const uid = key.slice(split + 1);
    try {
      assertRecoveryConnection(room, {uid, role, membershipId: room.players?.[uid]?.membershipId,
        connectionId: report.connectionId, connectionSeq: report.connectionSeq});
    } catch {
      return false;
    }
  }
  if (!saved.timer || (saved.timer.kind !== "none" && saved.timer.kind !== "remaining")) return false;
  game.public.turnDeadlineAt = saved.timer.kind === "none" ? null : now + saved.timer.remainingMs;
  game.public.recovery.paused = false;
  delete game.server.recovery;
  touch(game, now);
  return true;
}

export function expireRecoveryCauses(room: RecoveryRoom, now: number): number {
  let changed = 0;
  for (const cause of Object.values(room.game?.public.recovery?.causes ?? {})) {
    if (cause.deadlineAt !== undefined && now >= cause.deadlineAt && !cause.awaitingDecision) {
      cause.awaitingDecision = true;
      changed += 1;
    }
  }
  if (changed && room.game) touch(room.game, now);
  return changed;
}

export function extendRecoveryCause(room: RecoveryRoom, targetUid: string, incidentId: string, now: number): Record<string, unknown> {
  const cause = room.game?.public.recovery?.causes?.[`player:${targetUid}`];
  if (!cause || cause.incidentId !== incidentId) return {status: "alreadyResolved"};
  if (cause.deadlineAt === undefined || now < cause.deadlineAt || cause.extended) {
    return {status: "notAllowed", deadlineAt: cause.deadlineAt};
  }
  cause.extended = true;
  cause.deadlineAt = now + 30000;
  cause.awaitingDecision = false;
  touch(room.game!, now);
  return {status: "extended", deadlineAt: cause.deadlineAt};
}
