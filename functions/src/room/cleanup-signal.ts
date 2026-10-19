/* eslint-disable require-jsdoc, valid-jsdoc, max-len */
import {currentControllerSeen, currentPresence} from "./current-presence.js";
import type {SessionRoom} from "./session-contract.js";

export interface CleanupSignal {
  roomInstanceId: string; allocationGeneration: number; revision: number;
  planKey: string; nextCheckAt: number | null;
}
type SignalRoom = SessionRoom & {allocationGeneration: number; cleanupSignal?: CleanupSignal;
  cleanupAt?: number; retainUntil?: number; cleanupPending?: boolean; terminalAt?: number};

export function cleanupDeadline(room: SignalRoom): number | null {
  if (room.status === "terminal") return room.cleanupPending ? room.terminalAt ?? 0 : null;
  if (room.status === "closed") return room.cleanupAt ?? 0;
  if (room.status === "finished" && typeof room.retainUntil === "number") return room.retainUntil;
  const seen = currentControllerSeen(room);
  return typeof seen === "number" ? seen + (room.status === "playing" || room.status === "finished" ? 15 : 3) * 60000 : null;
}

/** Called INSIDE every room-root CAS. Timestamp-only changes do not change this plan. */
export function refreshCleanupSignal(raw: unknown, previous?: CleanupSignal): unknown {
  if (!raw || typeof raw !== "object") return raw;
  const room = raw as SignalRoom;
  if (!room.roomInstanceId || !Number.isSafeInteger(room.allocationGeneration)) return raw;
  // Preserve the pre-existing minimal terminal tombstone once reconciliation finishes.
  if (room.status === "terminal" && room.cleanupPending === false) {
    delete room.cleanupSignal;
    return raw;
  }
  const planKey = JSON.stringify([room.roomInstanceId, room.allocationGeneration, room.status ?? null,
    room.controllerUid ?? null, room.controllerCurrentConnectionId ?? null, room.controllerConnectionSeq ?? null,
    currentPresence(room, room.controllerUid ?? "", "controller")?.connected ?? room.controllerPresence?.connected ?? null,
    room.cleanupAt ?? null, room.retainUntil ?? null, room.cleanupPending ?? null, room.terminalAt ?? null]);
  if (room.cleanupSignal?.planKey === planKey) return raw;
  room.cleanupSignal = {roomInstanceId: room.roomInstanceId, allocationGeneration: room.allocationGeneration,
    revision: Math.max(room.cleanupSignal?.revision ?? 0, previous?.revision ?? 0) + 1, planKey, nextCheckAt: cleanupDeadline(room)};
  return raw;
}
