/* eslint-disable require-jsdoc, valid-jsdoc, max-len */
import {getDatabase} from "firebase-admin/database";
import {operationFingerprint} from "../room/session-contract.js";
import {CleanupRoom, reconcileTerminal, sameCleanupTarget} from "../room/room-cleanup.js";
import {runPrimedTransaction} from "../room/room-transaction.js";

// Match closeRoom's retention; retries must not extend an already closed room.
const CLOSED_ROOM_RETENTION_MS = 60 * 1000;

/** Close only the captured owned allocation, then reconcile its matching records. */
export async function closeAccountHostedRoom(uid: string, now: number): Promise<string | null> {
  const database = getDatabase();
  const mappingRef = database.ref(`controllerRooms/${uid}`);
  const mapping = (await mappingRef.get()).val();
  const legacy = typeof mapping === "string";
  const code = legacy ? mapping : mapping?.roomCode;
  if (typeof code !== "string" || !/^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{5}$/.test(code)) return null;
  const roomRef = database.ref(`rooms/${code}`);
  const observed = (await roomRef.get()).val() as CleanupRoom | null;
  if (!observed || typeof observed.roomInstanceId !== "string" || !Number.isSafeInteger(observed.allocationGeneration)) return null;
  if (!legacy && !sameCleanupTarget(observed, mapping)) return null;
  // A modern server mapping can also identify an already compacted terminal room.
  const canClose = (room: CleanupRoom) => room.controllerUid === uid ||
    (!legacy && room.controllerUid === undefined && room.status === "terminal");
  if (!canClose(observed)) return null;
  let closed: CleanupRoom | null = null;
  await runPrimedTransaction(roomRef, (raw) => {
    closed = null;
    const room = raw as CleanupRoom | null;
    if (!sameCleanupTarget(room, observed)) return;
    if (!canClose(room!)) return;
    if (room!.status === "terminal" || room!.status === "closed") {
      closed = room; return;
    }
    closed = {...room!, status: "closed", controllerConnected: false,
      controllerPresence: {connected: false, lastSeen: now}, cleanupAt: now + CLOSED_ROOM_RETENTION_MS};
    return closed;
  });
  if (!closed) return null;
  // No UID-wide request deletion: unrelated/unknown reserved intent is deferred.
  await reconcileTerminal(code, closed);
  await runPrimedTransaction(mappingRef, (raw) =>
    operationFingerprint(raw) === operationFingerprint(mapping) ? null : undefined);
  return code;
}
