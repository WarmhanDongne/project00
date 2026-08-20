/* eslint-disable valid-jsdoc, max-len, require-jsdoc */

import {CallableRequest, HttpsError} from "firebase-functions/v2/https";

import {assertControllerSession} from "../room/controller-session.js";
import {MafiaGameState, MafiaPhase, MafiaRoom} from "./types.js";

export const MAFIA_REGION = "asia-northeast3";
const ROOM_CODE = /^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{5}$/;
const COMMAND_ID = /^[A-Za-z0-9_-]{1,128}$/;
const UID = /^[A-Za-z0-9_-]{1,128}$/;

export function mafiaUid(request: CallableRequest<unknown>): string {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
  return uid;
}

export function mafiaRoomCode(value: unknown): string {
  const code = typeof value === "string" ? value.trim().toUpperCase() : "";
  if (!ROOM_CODE.test(code)) {
    throw new HttpsError("invalid-argument", "올바른 방 코드가 아닙니다.");
  }
  return code;
}

export function mafiaCommandId(value: unknown): string {
  const id = typeof value === "string" ? value.trim() : "";
  if (!COMMAND_ID.test(id)) {
    throw new HttpsError("invalid-argument", "올바른 commandId가 필요합니다.");
  }
  return id;
}

export function mafiaTargetUid(value: unknown): string {
  const uid = typeof value === "string" ? value.trim() : "";
  if (!UID.test(uid)) {
    throw new HttpsError("invalid-argument", "올바른 대상이 필요합니다.");
  }
  return uid;
}

export function requireMafiaGame(
  room: MafiaRoom,
  options: {allowInterruption?: boolean} = {},
): MafiaGameState {
  if (!room.game || room.game.public?.gameType !== "mafia") {
    throw new HttpsError("failed-precondition", "마피아 게임이 없습니다.");
  }
  if (room.game.public.interruption && !options.allowInterruption) {
    throw new HttpsError("failed-precondition", "플레이어 연결 확인 중에는 게임을 진행할 수 없습니다.");
  }
  return room.game;
}

export function assertMafiaController(
  room: MafiaRoom,
  uid: string,
  controllerSessionId: unknown,
): void {
  assertControllerSession(room, uid, controllerSessionId);
}

/** 지금 단계가 기대한 단계인지 확인합니다. */
export function assertMafiaPhase(
  game: MafiaGameState,
  phase: MafiaPhase,
): void {
  if (game.public.status !== "playing" || game.public.phase !== phase) {
    throw new HttpsError("failed-precondition", "지금 할 수 없는 동작입니다.");
  }
}

/** 살아 있는 참가자인지 확인합니다. 사망자·관전자는 조작할 수 없습니다. */
export function assertMafiaAlive(game: MafiaGameState, uid: string): void {
  if (game.public.players[uid]?.status !== "alive") {
    throw new HttpsError("failed-precondition", "사망한 플레이어입니다.");
  }
}
