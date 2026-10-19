/* eslint-disable require-jsdoc, valid-jsdoc, max-len */
import {getDatabase, Reference} from "firebase-admin/database";
import {onValueWritten} from "firebase-functions/v2/database";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {logger} from "firebase-functions";
import {RoomAllocation, terminalRoom} from "./room-allocation.js";
import {runPrimedTransaction} from "./room-transaction.js";
import {applyRoomPresence, SessionRoom} from "./session-contract.js";
import {CleanupSignal, cleanupDeadline} from "./cleanup-signal.js";
import {unprojectedLosses} from "./current-presence.js";
import {RecoveryRoom, registerRecoveryFailure} from "../game-interruption/recovery-state.js";

export interface CleanupRoom extends RoomAllocation {
  controllerPresence?: {connected?: boolean; lastSeen?: number}; retainUntil?: number; cleanupAt?: number;
  cleanupPending?: boolean; terminalAt?: number;
  cleanupSignal?: CleanupSignal;
}
export interface CleanupJob {roomInstanceId: string; allocationGeneration: number; nextCheckAt: number; failures: number; signalRevision?: number}

export function roomCleanupDeadline(room: CleanupRoom): number | null {
  return cleanupDeadline(room as SessionRoom & {allocationGeneration: number});
}
export function sameCleanupTarget(left: {roomInstanceId?: string; allocationGeneration?: number} | null,
  right: {roomInstanceId?: string; allocationGeneration?: number}): boolean {
  return typeof right.roomInstanceId === "string" && Number.isSafeInteger(right.allocationGeneration) && left?.roomInstanceId === right.roomInstanceId && left?.allocationGeneration === right.allocationGeneration;
}
export function cleanupScanPage<T>(entries: Array<{code: string; room: T}>, cursor: string | null, limit = 100) {
  const page = entries.filter((entry) => entry.code !== cursor).slice(0, limit);
  return {page, nextCursor: page.length === limit ? page[page.length - 1].code : null};
}
/** An overlapping scan cannot overwrite a cursor advanced by a newer run. */
export async function advanceCleanupCursor(ref: Reference, observed: string | null, next: string | null): Promise<boolean> {
  const result = await runPrimedTransaction(ref, (raw) => raw === observed ? next : undefined);
  return result.committed;
}
async function enqueue(code: string, room: CleanupRoom): Promise<void> {
  const due = roomCleanupDeadline(room);
  if (due === null) return;
  await runPrimedTransaction(getDatabase().ref(`roomCleanupQueue/${code}`), (value) => {
    const raw = value as CleanupJob | null;
    if (raw && raw.allocationGeneration > room.allocationGeneration) return;
    const same = sameCleanupTarget(raw, room);
    const revision = room.cleanupSignal?.revision ?? 0;
    if (same && (raw!.signalRevision ?? 0) > revision) return;
    return {roomInstanceId: room.roomInstanceId, allocationGeneration: room.allocationGeneration,
      nextCheckAt: same && (raw!.failures ?? 0) > 0 ? Math.max(raw!.nextCheckAt, due) : due,
      failures: same ? raw!.failures ?? 0 : 0, signalRevision: revision};
  });
}

/** Re-read the current allocation: a late event can never enqueue a prior generation. */
export const syncRoomCleanupQueue = onValueWritten({ref: "/rooms/{roomCode}/cleanupSignal",
  region: "asia-southeast1", retry: true}, async (event) => {
  const signal = (await getDatabase().ref(`rooms/${event.params.roomCode}/cleanupSignal`).get()).val() as CleanupSignal | null;
  if (!signal || typeof signal.nextCheckAt !== "number") return;
  // Advisory index only: the due worker still validates identity and canonical time in R CAS.
  await enqueue(event.params.roomCode, {roomInstanceId: signal.roomInstanceId,
    allocationGeneration: signal.allocationGeneration, status: "closed", cleanupAt: signal.nextCheckAt, cleanupSignal: signal});
});

export async function reconcileTerminal(code: string, room: CleanupRoom): Promise<void> {
  const database = getDatabase();
  if (room.controllerUid && room.creationOperationId) {
    const uid = room.controllerUid;
    const op = room.creationOperationId;
    const observed = (await database.ref(`rooms/${code}`).get()).val() as CleanupRoom | null;
    const confirmedTerminal = sameCleanupTarget(observed, room) && observed?.status === "terminal";
    await runPrimedTransaction(database.ref(`roomCreateRequests/${uid}/${op}`), (value) => {
      const raw = value as RoomAllocation | null;
      if (!sameCleanupTarget(raw, room)) return;
      // Keep the durable replay marker. Unknown reserved intent is never compacted.
      if (!confirmedTerminal || !["created", "terminal"].includes(raw!.status)) {
        return {...raw, status: "terminal"};
      }
      return {roomCode: code, roomInstanceId: raw!.roomInstanceId,
        allocationGeneration: raw!.allocationGeneration, status: "terminal",
        ...(typeof raw!.createdAt === "number" ? {createdAt: raw!.createdAt} : {})};
    });
    await runPrimedTransaction(database.ref(`roomCreateSlots/${uid}`), (value) => {
      const raw = value as {operationId: string; roomInstanceId?: string; allocationGeneration?: number} | null;
      return raw?.operationId === op && (!raw.roomInstanceId || sameCleanupTarget(raw, room)) ? {...raw, status: "terminal"} : undefined;
    });
    // Preserve the recovery locator until request/slot reconciliation has succeeded.
    await runPrimedTransaction(database.ref(`controllerRooms/${uid}`), (raw) => sameCleanupTarget(raw as RoomAllocation | null, room) ? null : undefined);
  }
  await runPrimedTransaction(database.ref(`rooms/${code}`), (raw) => {
    if (!sameCleanupTarget(raw as CleanupRoom | null, room) || (raw as CleanupRoom).status !== "terminal") return;
    const current = raw as CleanupRoom;
    if (!current.cleanupPending) return;
    return {roomInstanceId: current.roomInstanceId, allocationGeneration: current.allocationGeneration,
      status: "terminal", terminalAt: current.terminalAt, cleanupPending: false};
  });
}

/** Indexed due work and a persistent key scan prevent terminal prefixes from starving live rooms. */
export const cleanupStaleRealtimeRooms = onSchedule({region: "asia-northeast3",
  schedule: "every 5 minutes", timeZone: "Asia/Seoul"}, async () => {
  const database = getDatabase();
  const now = Date.now();
  const cursorRef = database.ref("roomCleanupScan/cursor");
  const cursor = (await cursorRef.get()).val() as string | null;
  const scanQuery = database.ref("rooms").orderByKey();
  const scan = await (cursor ? scanQuery.startAt(cursor) : scanQuery).limitToFirst(101).get();
  const scans: Array<{code: string; room: CleanupRoom}> = [];
  scan.forEach((child) => {
    if (child.key && child.key !== cursor) scans.push({code: child.key, room: child.val()});
  });
  const page = cleanupScanPage(scans, cursor);
  for (const entry of page.page) {
    if (unprojectedLosses(entry.room as SessionRoom).length > 0) {
      await runPrimedTransaction(database.ref(`rooms/${entry.code}`), (raw) => {
        if (!sameCleanupTarget(raw as CleanupRoom | null, entry.room)) return;
        const room = raw as SessionRoom;
        let changed = false;
        for (const {uid, id} of unprojectedLosses(room)) {
          changed = applyRoomPresence(room, uid, id, (role, seen) =>
            registerRecoveryFailure(room as RecoveryRoom, uid, role, now, "disconnected", seen)) || changed;
        }
        return changed ? room : undefined;
      });
    }
    await enqueue(entry.code, entry.room);
  }
  const cursorAdvanced = await advanceCleanupCursor(cursorRef, cursor, page.nextCursor);
  const due = await database.ref("roomCleanupQueue").orderByChild("nextCheckAt").endAt(now).limitToFirst(300).get();
  let completed = 0; let deferred = 0; let failed = 0;
  let terminalReconciliations = 0; let staleJobs = 0;
  const jobs: Array<{code: string; job: CleanupJob}> = [];
  due.forEach((child) => {
    if (child.key) jobs.push({code: child.key, job: child.val()});
  });
  for (const {code, job} of jobs) {
    try {
      let terminal: CleanupRoom | null = null;
      let future: number | null = null;
      await runPrimedTransaction(database.ref(`rooms/${code}`), (raw) => {
        terminal = null; future = null;
        if (!sameCleanupTarget(raw as CleanupRoom | null, job)) return;
        const room = raw as CleanupRoom;
        if (room.status === "terminal") {
          terminal = room; return;
        }
        future = roomCleanupDeadline(room);
        if (future === null || future > now) return;
        terminal = terminalRoom(room, now) as CleanupRoom;
        return terminal;
      });
      if (terminal) {
        await reconcileTerminal(code, terminal);
        terminalReconciliations++;
      } else if (future === null) staleJobs++;
      await runPrimedTransaction(database.ref(`roomCleanupQueue/${code}`), (value) => {
        const raw = value as CleanupJob | null;
        if (!sameCleanupTarget(raw, job) || (raw!.signalRevision ?? 0) !== (job.signalRevision ?? 0) ||
          raw!.nextCheckAt !== job.nextCheckAt || raw!.failures !== job.failures) return;
        return future !== null && future > now ? {...raw, nextCheckAt: future} : null;
      });
      if (future !== null && future > now) deferred++; else completed++;
    } catch {
      failed++;
      await runPrimedTransaction(database.ref(`roomCleanupQueue/${code}`), (value) => {
        const raw = value as CleanupJob | null;
        return sameCleanupTarget(raw, job) && (raw!.signalRevision ?? 0) === (job.signalRevision ?? 0) &&
          raw!.nextCheckAt === job.nextCheckAt && raw!.failures === job.failures ?
          {...raw, failures: (raw!.failures ?? 0) + 1,
            nextCheckAt: now + Math.min(30, 2 ** Math.min(raw!.failures ?? 0, 5)) * 60000} : undefined;
      });
    }
  }
  logger.info("Room cleanup", {completed, deferred, failed, scanned: page.page.length,
    terminalReconciliations, staleJobs, cursorAdvanced, queueLimitReached: jobs.length === 300,
    oldestDueAgeMs: jobs.reduce((age, {job}) => Math.max(age, now - job.nextCheckAt), 0),
    durationMs: Date.now() - now});
});
