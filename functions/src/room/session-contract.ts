/* eslint-disable valid-jsdoc, require-jsdoc, max-len */

import {createHash} from "node:crypto";
import {HttpsError} from "firebase-functions/v2/https";

export interface SessionPlayer {
  membershipId?: string;
  currentConnectionId?: string;
  connectionSeq?: number;
  role?: string;
  status?: string;
  isConnected?: boolean;
  lastSeen?: number;
  [key: string]: unknown;
}

export interface RoomConnection {
  roomInstanceId: string;
  membershipId?: string;
  connectionSeq: number;
  connected: boolean;
  lastSeen: number;
}

interface RoomOperation {
  uid: string;
  kind: string;
  fingerprint: string;
  result: Record<string, unknown>;
  appliedAt: number;
}

export interface SessionRoom {
  roomInstanceId?: string;
  membershipRevision?: number;
  status?: string;
  controllerUid?: string;
  controllerSessionId?: string;
  controllerCurrentConnectionId?: string;
  controllerConnectionSeq?: number;
  controllerConnected?: boolean;
  controllerPresence?: {connected?: boolean; lastSeen?: number};
  players?: Record<string, SessionPlayer>;
  connections?: Record<string, Record<string, RoomConnection>>;
  sessionOperations?: Record<string, RoomOperation>;
}

export function parseSessionId(value: unknown, label: string): string {
  if (typeof value !== "string" || !/^[A-Za-z0-9_-]{8,128}$/.test(value)) {
    throw new HttpsError("invalid-argument", `${label} 정보가 필요합니다.`);
  }
  return value;
}

export function assertRoomTarget(room: SessionRoom, roomInstanceId: unknown): void {
  if (!room.roomInstanceId || room.roomInstanceId !== roomInstanceId) {
    throw new HttpsError("failed-precondition", "다른 방 세션입니다.", {reason: "staleContext"});
  }
}

function canonical(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(canonical);
  if (value !== null && typeof value === "object") {
    return Object.fromEntries(Object.entries(value as Record<string, unknown>)
      .filter(([, entry]) => entry !== undefined)
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([key, entry]) => [key, canonical(entry)]));
  }
  return value;
}

export function operationFingerprint(payload: unknown): string {
  return createHash("sha256").update(JSON.stringify(canonical(payload))).digest("hex");
}

export function roomOperationResult(
  room: SessionRoom, uid: string, operationId: string,
  kind?: string, payload?: unknown,
): Record<string, unknown> | null {
  const operation = room.sessionOperations?.[operationId];
  if (!operation) return null;
  if (operation.uid !== uid || (kind !== undefined &&
      (operation.kind !== kind || operation.fingerprint !== operationFingerprint(payload)))) {
    throw new HttpsError("permission-denied", "다른 요청에 사용한 작업 ID입니다.");
  }
  return operation.result;
}

export function recordRoomOperation(
  room: SessionRoom, uid: string, operationId: string, kind: string,
  payload: unknown, result: Record<string, unknown>, now: number,
): void {
  roomOperationResult(room, uid, operationId, kind, payload);
  room.sessionOperations ??= {};
  room.sessionOperations[operationId] = {
    uid, kind, fingerprint: operationFingerprint(payload), result, appliedAt: now,
  };
}

export interface AllocateConnectionInput {
  uid: string;
  role: "player" | "controller";
  operationId: string;
  roomInstanceId: string;
  membershipId?: string;
  expectedConnectionSeq: number;
  connectionId: string;
  now: number;
  operationPayload?: Record<string, unknown>;
}

/** Same operation replays its outcome without binding an obsolete transport. */
export function allocateRoomConnection(
  room: SessionRoom, input: AllocateConnectionInput,
): Record<string, unknown> {
  const {uid, role, operationId, now} = input;
  assertRoomTarget(room, input.roomInstanceId);
  const payload = input.operationPayload ?? {
    roomInstanceId: input.roomInstanceId, membershipId: input.membershipId,
    expectedConnectionSeq: input.expectedConnectionSeq, role,
  };
  const saved = roomOperationResult(room, uid, operationId, "connect", payload);
  if (saved) return saved;
  if (room.status === "closed" || room.status === "terminal") {
    throw new HttpsError("failed-precondition", "종료된 방입니다.");
  }
  const player = room.players?.[uid];
  const controller = role === "controller";
  if (controller ? room.controllerUid !== uid :
    !player || player.status !== "active" || player.membershipId !== input.membershipId) {
    throw new HttpsError("permission-denied", "현재 방 참가 자격이 없습니다.");
  }
  const previousSeq = (controller ? room.controllerConnectionSeq : player?.connectionSeq) ?? 0;
  if (!Number.isSafeInteger(input.expectedConnectionSeq) ||
      input.expectedConnectionSeq !== previousSeq) {
    throw new HttpsError("aborted", "접속 세대가 변경되었습니다.", {reason: "staleConnection"});
  }
  const connectionSeq = previousSeq + 1;
  room.connections ??= {};
  room.connections[uid] ??= {};
  // Old onDisconnect registrations only ever write their own connection node.
  room.connections[uid][input.connectionId] = {
    roomInstanceId: input.roomInstanceId, connectionSeq, connected: true, lastSeen: now,
    ...(controller ? {} : {membershipId: input.membershipId}),
  };
  if (controller) {
    room.controllerCurrentConnectionId = input.connectionId;
    room.controllerConnectionSeq = connectionSeq;
    room.controllerConnected = true;
    room.controllerPresence = {connected: true, lastSeen: now};
  } else if (player) {
    player.currentConnectionId = input.connectionId;
    player.connectionSeq = connectionSeq;
    player.isConnected = true;
    player.lastSeen = now;
  }
  const result = {
    status: "applied", roomInstanceId: input.roomInstanceId,
    connectionId: input.connectionId, connectionSeq,
    ...(controller ? {} : {membershipId: input.membershipId}),
  };
  recordRoomOperation(room, uid, operationId, "connect", payload, result, now);
  return result;
}

/** Returns false for old connections, memberships, and reused room codes. */
export function applyRoomPresence(room: SessionRoom, uid: string, connectionId: string): boolean {
  if (room.status === "closed" || room.status === "terminal") return false;
  const connection = room.connections?.[uid]?.[connectionId];
  if (!connection || connection.roomInstanceId !== room.roomInstanceId) return false;
  if (room.controllerUid === uid && room.controllerCurrentConnectionId === connectionId &&
      room.controllerConnectionSeq === connection.connectionSeq) {
    room.controllerConnected = connection.connected;
    room.controllerPresence = {connected: connection.connected, lastSeen: connection.lastSeen};
    return true;
  }
  const player = room.players?.[uid];
  if (!player || player.status !== "active" || player.currentConnectionId !== connectionId ||
      player.connectionSeq !== connection.connectionSeq ||
      player.membershipId !== connection.membershipId) return false;
  player.isConnected = connection.connected;
  player.lastSeen = connection.lastSeen;
  return true;
}

export function leaveRoomMembership(room: SessionRoom, input: {
  uid: string; roomInstanceId: string; membershipId: string; operationId: string; now: number;
}, beforeRemove?: () => void): Record<string, unknown> {
  assertRoomTarget(room, input.roomInstanceId);
  const payload = {roomInstanceId: input.roomInstanceId, membershipId: input.membershipId};
  const saved = roomOperationResult(room, input.uid, input.operationId, "leave", payload);
  if (saved) return saved;
  const player = room.players?.[input.uid];
  const result = {status: player && player.membershipId !== input.membershipId ? "stale" : "applied"};
  if (player?.membershipId === input.membershipId) {
    beforeRemove?.();
    delete room.players?.[input.uid];
    room.membershipRevision = (room.membershipRevision ?? 0) + 1;
  }
  recordRoomOperation(room, input.uid, input.operationId, "leave", payload, result, input.now);
  return result;
}
