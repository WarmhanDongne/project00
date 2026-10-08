/* eslint-disable valid-jsdoc, require-jsdoc, max-len */

import {CallableRequest, HttpsError} from "firebase-functions/v2/https";
import {assertControllerSession} from "../room/controller-session.js";
import {HoldemAction, HoldemGameState, HoldemRoom} from "./types.js";

export const HOLDEM_REGION = "asia-northeast3";
const ROOM_CODE_PATTERN = /^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{5}$/;
const COMMAND_ID_PATTERN = /^[A-Za-z0-9_-]{1,128}$/;

export function requireHoldemUid(request: CallableRequest<unknown>): string {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
  return uid;
}

export function parseHoldemRoomCode(value: unknown): string {
  const roomCode = typeof value === "string" ? value.trim().toUpperCase() : "";
  if (!ROOM_CODE_PATTERN.test(roomCode)) throw new HttpsError("invalid-argument", "올바른 방 코드가 아닙니다.");
  return roomCode;
}

export function parseHoldemCommandId(value: unknown): string {
  const commandId = typeof value === "string" ? value.trim() : "";
  if (!COMMAND_ID_PATTERN.test(commandId)) throw new HttpsError("invalid-argument", "올바른 commandId가 필요합니다.");
  return commandId;
}

export function parseHoldemStateVersion(value: unknown): number {
  if (!Number.isSafeInteger(value) || (value as number) < 1) {
    throw new HttpsError("invalid-argument", "올바른 stateVersion이 필요합니다.");
  }
  return value as number;
}

export function parseHoldemAction(value: unknown, amount: unknown): HoldemAction {
  if (value === "fold" || value === "check" || value === "call" || value === "allIn") return {kind: value};
  if ((value === "bet" || value === "raise") && Number.isSafeInteger(amount) && (amount as number) > 0) {
    return {kind: value, targetContribution: amount as number};
  }
  throw new HttpsError("invalid-argument", "올바른 홀덤 행동과 금액이 필요합니다.");
}

export function requireHoldemGame(room: HoldemRoom, allowInterruption = false): HoldemGameState {
  const game = room.game;
  if (!game || game.public.gameType !== "holdem") throw new HttpsError("failed-precondition", "진행 중인 홀덤 게임이 없습니다.");
  if (game.public.interruption && !allowInterruption) throw new HttpsError("failed-precondition", "플레이어 연결 확인 중에는 게임을 진행할 수 없습니다.");
  return game;
}

export function assertHoldemController(room: HoldemRoom, uid: string, sessionId: unknown): void {
  assertControllerSession(room, uid, sessionId);
}

export function assertHoldemRoom(room: unknown): asserts room is HoldemRoom {
  if (!room) throw new HttpsError("not-found", "방을 찾을 수 없습니다.");
}

export function holdemHttpsError(error: unknown): HttpsError {
  if (error instanceof HttpsError) return error;
  return new HttpsError("failed-precondition", error instanceof Error ? error.message : "홀덤 요청을 처리하지 못했습니다.");
}
