/* eslint-disable valid-jsdoc, max-len, require-jsdoc */

import {CallableRequest, HttpsError} from "firebase-functions/v2/https";

import {assertControllerSession} from "../room/controller-session.js";
import {mafiaRole} from "./roles.js";
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

/**
 * 태블릿이 **역할 배치 화면**에서 고른 구성입니다(`역할 id → 인원수`).
 *
 * 확정(2026-08): 마피아는 게임 시작 전에 자리 배치 대신 역할 배치를 합니다.
 * 값이 없으면 인원별 추천 표(`MAFIA_COMPOSITION`)를 그대로 씁니다.
 *
 * 여기서 막지 않으면 게임이 시작조차 못 하는 구성이 들어옵니다 — 인원과 합이
 * 다르거나, 이 빌드가 동작을 구현하지 않은 역할이거나, 마피아가 아예 없거나
 * 전원이 마피아인 경우입니다.
 *
 * @param {unknown} value 클라이언트가 보낸 값
 * @param {number} playerCount 이번 판의 인원
 * @return {Record<string, number> | null} 검사를 통과한 구성(없으면 null)
 */
export function mafiaComposition(
  value: unknown,
  playerCount: number,
): Record<string, number> | null {
  if (value === undefined || value === null) return null;
  if (typeof value !== "object" || Array.isArray(value)) {
    throw new HttpsError("invalid-argument", "역할 구성을 읽을 수 없습니다.");
  }

  const composition: Record<string, number> = {};
  let total = 0;
  let mafiaCount = 0;
  for (const [roleId, raw] of Object.entries(value as Record<string, unknown>)) {
    const count = typeof raw === "number" ? raw : NaN;
    if (!Number.isInteger(count) || count < 1 || count > playerCount) {
      throw new HttpsError(
        "invalid-argument",
        `'${roleId}' 인원수가 올바르지 않습니다.`,
      );
    }
    const role = mafiaRole(roleId);
    if (!role || !role.isImplemented) {
      throw new HttpsError(
        "failed-precondition",
        `아직 쓸 수 없는 역할입니다: ${roleId}`,
      );
    }
    composition[roleId] = count;
    total += count;
    if (role.faction === "mafia") mafiaCount += count;
  }

  if (total !== playerCount) {
    throw new HttpsError(
      "failed-precondition",
      `역할 ${total}개가 인원 ${playerCount}명과 맞지 않습니다.`,
    );
  }
  if (mafiaCount < 1) {
    throw new HttpsError("failed-precondition", "마피아가 최소 1명 있어야 합니다.");
  }
  if (mafiaCount >= playerCount) {
    throw new HttpsError("failed-precondition", "마피아만으로는 진행할 수 없습니다.");
  }
  return composition;
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
