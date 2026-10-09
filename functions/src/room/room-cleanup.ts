/* eslint-disable require-jsdoc, valid-jsdoc, max-len */
import {getDatabase} from "firebase-admin/database";
import {onValueWritten} from "firebase-functions/v2/database";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {logger} from "firebase-functions";
import {RoomAllocation, terminalRoom} from "./room-allocation.js";
import {runPrimedTransaction} from "./room-transaction.js";

export interface CleanupRoom extends RoomAllocation {
  controllerPresence?: {lastSeen?: number}; retainUntil?: number; cleanupAt?: number;
  cleanupPending?: boolean; terminalAt?: number;
}
export interface CleanupJob {roomInstanceId: string; allocationGeneration: number; nextCheckAt: number; failures: number}

export function roomCleanupDeadline(room: CleanupRoom): number | null {
  if (room.status === "terminal") return room.cleanupPending ? room.terminalAt ?? 0 : null;
  if (room.status === "closed") return room.cleanupAt ?? 0;
  if (room.status === "finished") {
    return room.retainUntil ??
    (room.controllerPresence?.lastSeen ? room.controllerPresence.lastSeen + 15 * 60000 : null);
  }
  const seen = room.controllerPresence?.lastSeen;
  return typeof seen === "number" ? seen + (room.status === "playing" ? 15 : 3) * 60000 : null;
}
export function sameCleanupTarget(left: {roomInstanceId?: string; allocationGeneration?: number} | null,
  right: {roomInstanceId?: string; allocationGeneration?: number}): boolean {
  return typeof right.roomInstanceId === "string" && Number.isSafeInteger(right.allocationGeneration) && left?.roomInstanceId === right.roomInstanceId && left?.allocationGeneration === right.allocationGeneration;
}
export function cleanupScanPage(entries: Array<{code: string; room: CleanupRoom}>, cursor: string | null) {
  const page = entries.filter((entry) => entry.code !== cursor).slice(0, 100);
  return {page, nextCursor: page.length === 100 ? page[page.length - 1].code : null};
}
async function enqueue(code: string, room: CleanupRoom): Promise<void> {
  const due = roomCleanupDeadline(room);
  if (due === null) return;
  await getDatabase().ref(`roomCleanupQueue/${code}`).transaction((raw) => {
    if (raw && raw.allocationGeneration > room.allocationGeneration) return;
    return {roomInstanceId: room.roomInstanceId, allocationGeneration: room.allocationGeneration,
      nextCheckAt: due, failures: sameCleanupTarget(raw, room) ? raw.failures ?? 0 : 0};
  });
}

/** Re-read the current allocation: a late event can never enqueue a prior generation. */
export const syncRoomCleanupQueue = onValueWritten({ref: "/rooms/{roomCode}",
  region: "asia-southeast1", retry: true}, async (event) => {
  const room = (await getDatabase().ref(`rooms/${event.params.roomCode}`).get()).val() as CleanupRoom | null;
  if (room) await enqueue(event.params.roomCode, room);
});

export async function reconcileTerminal(code: string, room: CleanupRoom): Promise<void> {
  const database = getDatabase();
  if (room.controllerUid && room.creationOperationId) {
    const uid = room.controllerUid;
    const op = room.creationOperationId;
    await database.ref(`roomCreateRequests/${uid}/${op}`).transaction((raw) =>
      sameCleanupTarget(raw, room) ? {...raw, status: "terminal"} : undefined);
    await database.ref(`controllerRooms/${uid}`).transaction((raw) => sameCleanupTarget(raw, room) ? null : undefined);
    await database.ref(`roomCreateSlots/${uid}`).transaction((raw) => raw?.operationId === op &&
      (!raw.roomInstanceId || sameCleanupTarget(raw, room)) ? {...raw, status: "terminal"} : undefined);
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
  const scan = await database.ref("rooms").orderByKey().startAt(cursor ?? "").limitToFirst(101).get();
  const scans: Array<{code: string; room: CleanupRoom}> = [];
  scan.forEach((child) => {
    if (child.key && child.key !== cursor) scans.push({code: child.key, room: child.val()});
  });
  const page = cleanupScanPage(scans, cursor);
  for (const entry of page.page) await enqueue(entry.code, entry.room);
  await cursorRef.set(page.nextCursor);
  const due = await database.ref("roomCleanupQueue").orderByChild("nextCheckAt").endAt(now).limitToFirst(300).get();
  let completed = 0; let deferred = 0; let failed = 0;
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
      if (terminal) await reconcileTerminal(code, terminal);
      await database.ref(`roomCleanupQueue/${code}`).transaction((raw) => {
        if (!sameCleanupTarget(raw, job)) return;
        return future !== null && future > now ? {...raw, nextCheckAt: future} : null;
      });
      if (future !== null && future > now) deferred++; else completed++;
    } catch {
      failed++;
      await database.ref(`roomCleanupQueue/${code}`).transaction((raw) => sameCleanupTarget(raw, job) ?
        {...raw, failures: (raw.failures ?? 0) + 1,
          nextCheckAt: now + Math.min(30, 2 ** Math.min(raw.failures ?? 0, 5)) * 60000} : undefined);
    }
  }
  logger.info("Room cleanup", {completed, deferred, failed, scanned: scans.length});
});
