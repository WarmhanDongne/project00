/* eslint-disable require-jsdoc, valid-jsdoc, max-len */
import {randomInt, randomUUID} from "node:crypto";
import {getDatabase} from "firebase-admin/database";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {assertOnboardingComplete} from "../auth/require-complete-onboarding.js";
import {allocateRoom, RoomAllocation, RoomReservation, terminalRoom} from "./room-allocation.js";
import {operationFingerprint, parseSessionId} from "./session-contract.js";
import {reconcileTerminal} from "./room-cleanup.js";
import {runPrimedTransaction} from "./room-transaction.js";

async function abandonReservation(code: string, reservation: RoomReservation, uid: string, operationId: string, now: number): Promise<void> {
  const target = {...reservation, status: "terminal", controllerUid: uid, creationOperationId: operationId};
  await runPrimedTransaction(getDatabase().ref(`rooms/${code}`), (raw) => {
    const room = raw as RoomAllocation | null;
    if (room?.roomInstanceId !== reservation.roomInstanceId || room.allocationGeneration !== reservation.allocationGeneration) return;
    return room.status === "terminal" ? room : terminalRoom(room, now);
  });
  await reconcileTerminal(code, target);
}
const ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
function newCode(): string {
  return Array.from({length: 5}, () => ALPHABET[randomInt(ALPHABET.length)]).join("");
}

export const createRealtimeRoom = onCall({region: "asia-northeast3"}, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
  await assertOnboardingComplete(uid);
  const operationId = parseSessionId(request.data?.operationId, "생성 작업 ID");
  const database = getDatabase();
  const now = Date.now();
  const previousMapping = (await database.ref(`controllerRooms/${uid}`).get()).val();
  if (previousMapping?.roomCode) {
    const previous = (await database.ref(`rooms/${previousMapping.roomCode}`).get()).val();
    if (previous?.roomInstanceId === previousMapping.roomInstanceId && !["closed", "terminal"].includes(previous.status) && previous.creationOperationId !== operationId) {
      throw new HttpsError("failed-precondition", "이미 사용 중인 방이 있습니다.");
    }
  }
  const slot = database.ref(`roomCreateSlots/${uid}`);
  const claimed = await runPrimedTransaction(slot, (value) => {
    const raw = value as {operationId: string; status: string} | null;
    if (raw && raw.operationId !== operationId && raw.status !== "terminal") return;
    if (raw?.operationId === operationId) return raw;
    return {operationId, status: "reserved"};
  });
  if (!claimed.committed || claimed.snapshot.child("operationId").val() !== operationId) {
    throw new HttpsError("failed-precondition", "이전 방 생성 결과를 먼저 확인해주세요.", {reason: "creationPending"});
  }
  if (claimed.snapshot.child("status").val() === "terminal") return {status: "terminal"};
  const reservationRef = database.ref(`roomCreateRequests/${uid}/${operationId}`);
  for (let attempt = 0; attempt < 12; attempt++) {
    const code = newCode();
    const room = (await database.ref(`rooms/${code}`).get()).val() as RoomAllocation | null;
    if (room && room.status !== "terminal") continue;
    const expected = room?.allocationGeneration ?? 0;
    const candidate: RoomReservation = {roomCode: code, roomInstanceId: randomUUID(),
      expectedAllocationGeneration: expected, allocationGeneration: expected + 1,
      controllerSessionId: randomUUID(), connectionId: randomUUID(), createdAt: now, status: "reserved"};
    const reserved = await runPrimedTransaction(reservationRef, (raw) => raw ?? candidate);
    const reservation = reserved.snapshot.val() as RoomReservation;
    if (reservation.status === "terminal") return {status: "terminal"};
    const initial: RoomAllocation = {roomCode: reservation.roomCode,
      roomInstanceId: reservation.roomInstanceId, allocationGeneration: reservation.allocationGeneration,
      controllerUid: uid, controllerSessionId: reservation.controllerSessionId,
      creationOperationId: operationId, status: "waiting", membershipRevision: 0, maxPlayers: 12,
      controllerConnected: true, controllerConnectionSeq: 1,
      controllerCurrentConnectionId: reservation.connectionId,
      controllerPresence: {connected: true, lastSeen: now}, createdAt: reservation.createdAt,
      connections: {[uid]: {[reservation.connectionId]: {roomInstanceId: reservation.roomInstanceId,
        connectionSeq: 1, connected: true, lastSeen: now}}}};
    const result = await runPrimedTransaction(database.ref(`rooms/${reservation.roomCode}`), (raw) =>
      allocateRoom(raw as RoomAllocation | null, reservation, uid, operationId, initial));
    if (!result.committed) {
      const current = result.snapshot.val() as RoomAllocation | null;
      if (current?.roomInstanceId === reservation.roomInstanceId || reservation.status === "created") {
        await reconcileTerminal(reservation.roomCode, {...reservation, status: "terminal", controllerUid: uid, creationOperationId: operationId});
        return {status: "terminal"};
      }
      // Only a proven collision can change this reserved candidate; an unknown never does.
      await runPrimedTransaction(reservationRef, (value) => {
        const raw = value as RoomReservation | null;
        return raw?.roomInstanceId === reservation.roomInstanceId && raw.status === "reserved" ? null : undefined;
      });
      continue;
    }
    await runPrimedTransaction(reservationRef, (value) => {
      const raw = value as RoomReservation | null;
      return raw?.roomInstanceId === reservation.roomInstanceId && raw.status !== "terminal" ? {...raw, status: "created"} : undefined;
    });
    const live = (await database.ref(`rooms/${reservation.roomCode}`).get()).val() as RoomAllocation;
    if (!live || live.roomInstanceId !== reservation.roomInstanceId || ["closed", "terminal"].includes(live.status)) {
      await reconcileTerminal(reservation.roomCode, {...reservation, status: "terminal", controllerUid: uid, creationOperationId: operationId});
      return {status: "terminal"};
    }
    const mappingRef = database.ref(`controllerRooms/${uid}`);
    const mapping = (await mappingRef.get()).val() as {roomCode?: string; roomInstanceId?: string} | null;
    if (mapping && mapping.roomInstanceId !== reservation.roomInstanceId) {
      const other = mapping.roomCode ? (await database.ref(`rooms/${mapping.roomCode}`).get()).val() : null;
      if (other && !["closed", "terminal"].includes(other.status)) {
        await abandonReservation(reservation.roomCode, reservation, uid, operationId, now);
        throw new HttpsError("failed-precondition", "이미 사용 중인 방이 있습니다.");
      }
    }
    const mapped = await runPrimedTransaction(mappingRef, (raw) => {
      if (operationFingerprint(raw) !== operationFingerprint(mapping)) return;
      return {roomCode: reservation.roomCode, roomInstanceId: reservation.roomInstanceId,
        allocationGeneration: reservation.allocationGeneration};
    });
    const finalRoom = (await database.ref(`rooms/${reservation.roomCode}`).get()).val() as RoomAllocation | null;
    if (!mapped.committed || !finalRoom || finalRoom.roomInstanceId !== reservation.roomInstanceId || ["closed", "terminal"].includes(finalRoom.status)) {
      await abandonReservation(reservation.roomCode, reservation, uid, operationId, now);
      return {status: "terminal"};
    }
    await runPrimedTransaction(slot, (value) => {
      const raw = value as {operationId: string; status: string} | null;
      return raw?.operationId === operationId && raw.status !== "terminal" ?
        {...raw, status: "created", roomInstanceId: reservation.roomInstanceId,
          allocationGeneration: reservation.allocationGeneration} : undefined;
    });
    return {success: true, roomCode: reservation.roomCode, roomInstanceId: reservation.roomInstanceId,
      controllerSessionId: reservation.controllerSessionId,
      connectionId: live.controllerCurrentConnectionId, connectionSeq: live.controllerConnectionSeq};
  }
  throw new HttpsError("resource-exhausted", "사용 가능한 방 코드를 찾지 못했습니다.");
});
