/* eslint-disable valid-jsdoc, max-len, require-jsdoc */

import {CallableRequest, HttpsError} from "firebase-functions/v2/https";

import {FinalCallGameState, FinalCallRoom} from "./types.js";

export const FINAL_CALL_REGION = "asia-northeast3";
const ROOM_CODE = /^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{5}$/;
const COMMAND_ID = /^[A-Za-z0-9_-]{1,128}$/;

export function finalCallUid(request: CallableRequest<unknown>): string {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
  return uid;
}

export function finalCallRoomCode(value: unknown): string {
  const code = typeof value === "string" ? value.trim().toUpperCase() : "";
  if (!ROOM_CODE.test(code)) {
    throw new HttpsError("invalid-argument", "올바른 방 코드가 아닙니다.");
  }
  return code;
}

export function finalCallCommandId(value: unknown): string {
  const id = typeof value === "string" ? value.trim() : "";
  if (!COMMAND_ID.test(id)) {
    throw new HttpsError("invalid-argument", "올바른 commandId가 필요합니다.");
  }
  return id;
}

export function requireFinalCallGame(room: FinalCallRoom): FinalCallGameState {
  if (!room.game || room.game.public?.gameType !== "final_call") {
    throw new HttpsError("failed-precondition", "Final Call 게임이 없습니다.");
  }
  return room.game;
}

export function assertFinalCallController(room: FinalCallRoom, uid: string): void {
  if ((room.controllerUid ?? room.hostUid) !== uid) {
    throw new HttpsError("permission-denied", "방을 만든 아이패드만 진행할 수 있습니다.");
  }
}

export function assertFinalCallTurn(game: FinalCallGameState, uid: string): void {
  if (game.public.status !== "playing" || game.public.turnUid !== uid) {
    throw new HttpsError("failed-precondition", "현재 내 턴이 아닙니다.");
  }
  if (game.public.players[uid]?.status !== "alive") {
    throw new HttpsError("failed-precondition", "탈락한 플레이어입니다.");
  }
}
