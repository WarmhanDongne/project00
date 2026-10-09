/* eslint-disable require-jsdoc, valid-jsdoc, max-len */
import {HttpsError} from "firebase-functions/v2/https";

export interface RoomAllocation {roomInstanceId: string; allocationGeneration: number;
  status: string; controllerUid?: string; creationOperationId?: string; [key: string]: unknown}
export interface RoomReservation {roomCode: string; roomInstanceId: string;
  expectedAllocationGeneration: number; allocationGeneration: number;
  controllerSessionId: string; connectionId: string; createdAt: number;
  status: "reserved" | "created" | "terminal"}

/** An old writer can never change a terminal or a newer allocation to waiting. */
export function allocateRoom(current: RoomAllocation | null, reservation: RoomReservation,
  uid: string, operationId: string, initial: RoomAllocation): RoomAllocation | undefined {
  if (reservation.status === "terminal") return;
  if (current?.roomInstanceId === reservation.roomInstanceId &&
      current.allocationGeneration === reservation.allocationGeneration &&
      current.controllerUid === uid && current.creationOperationId === operationId) {
    return current.status === "terminal" || current.status === "closed" ? undefined : current;
  }
  const generation = current?.allocationGeneration ?? 0;
  if (generation !== reservation.expectedAllocationGeneration ||
      (current && current.status !== "terminal")) return;
  return initial;
}

export function terminalRoom(room: RoomAllocation, now: number): RoomAllocation {
  return {roomInstanceId: room.roomInstanceId, allocationGeneration: room.allocationGeneration,
    status: "terminal", ...(room.controllerUid ? {controllerUid: room.controllerUid} : {}),
    ...(room.creationOperationId ? {creationOperationId: room.creationOperationId} : {}), terminalAt: now, cleanupPending: true};
}

export function assertRoomGroupMember(room: RoomAllocation, uid: string, roomInstanceId: unknown): void {
  if (room.roomInstanceId !== roomInstanceId || room.status === "terminal" || room.status === "closed") {
    throw new HttpsError("failed-precondition", "이전 방의 요청입니다.", {reason: "staleContext"});
  }
  const players = room.players as Record<string, {status?: string}> | undefined;
  if (room.controllerUid !== uid && players?.[uid]?.status !== "active") {
    throw new HttpsError("permission-denied", "현재 방 참가 자격이 없습니다.");
  }
}
