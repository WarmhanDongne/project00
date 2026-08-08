/* eslint-disable valid-jsdoc, require-jsdoc */

import {
  CallableRequest,
  HttpsError,
} from "firebase-functions/v2/https";

import {LiarsPokerGameState, RealtimeRoom} from "./types.js";

export const REGION = "asia-northeast3";
const ROOM_CODE_PATTERN = /^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{5}$/;
const COMMAND_ID_PATTERN = /^[A-Za-z0-9_-]{1,128}$/;

/** 인증된 호출자의 UID를 반환합니다. */
export function requireUid(request: CallableRequest<unknown>): string {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
  return uid;
}

/** 방 코드를 정규화하고 검증합니다. */
export function parseRoomCode(value: unknown): string {
  const roomCode = typeof value === "string" ?
    value.trim().toUpperCase() : "";
  if (!ROOM_CODE_PATTERN.test(roomCode)) {
    throw new HttpsError("invalid-argument", "올바른 방 코드가 아닙니다.");
  }
  return roomCode;
}

/** 재시도 중복 처리를 위한 명령 ID를 검증합니다. */
export function parseCommandId(value: unknown): string {
  const commandId = typeof value === "string" ? value.trim() : "";
  if (!COMMAND_ID_PATTERN.test(commandId)) {
    throw new HttpsError("invalid-argument", "올바른 commandId가 필요합니다.");
  }
  return commandId;
}

/** 한 턴에 제출할 고유 카드 ID 1~3개를 검증합니다. */
export function parseCardIds(value: unknown): string[] {
  if (!Array.isArray(value) || value.length < 1 || value.length > 3) {
    throw new HttpsError(
      "invalid-argument",
      "카드는 한 번에 1~3장 제출해야 합니다.",
    );
  }
  const cardIds = value.map((cardId) => {
    if (typeof cardId !== "string" || !COMMAND_ID_PATTERN.test(cardId)) {
      throw new HttpsError("invalid-argument", "올바르지 않은 카드 ID입니다.");
    }
    return cardId;
  });
  if (new Set(cardIds).size !== cardIds.length) {
    throw new HttpsError("invalid-argument", "같은 카드를 중복 제출했습니다.");
  }
  return cardIds;
}

/** 진행 중인 게임 상태를 반환합니다. */
export function requireGame(room: RealtimeRoom): LiarsPokerGameState {
  if (!room.game) {
    throw new HttpsError("failed-precondition", "진행 중인 게임이 없습니다.");
  }
  return room.game;
}

/** 현재 기기가 이 방을 만든 아이패드 컨트롤러인지 확인합니다. */
export function assertController(room: RealtimeRoom, uid: string): void {
  // hostUid는 기존 생성 방을 한 번만 호환하기 위한 값입니다.
  const controllerUid = room.controllerUid ?? room.hostUid;
  if (controllerUid !== uid) {
    throw new HttpsError(
      "permission-denied",
      "이 게임은 방을 만든 아이패드에서만 진행할 수 있습니다.",
    );
  }
}

export function assertRoomExists(room: unknown): void {
  if (!room) {
    throw new HttpsError(
      "not-found",
      "방을 찾을 수 없습니다.",
    );
  }
}

export function assertGameExists(game: unknown): void {
  if (!game) {
    throw new HttpsError(
      "failed-precondition",
      "게임이 존재하지 않습니다.",
    );
  }
}

export function assertPlayerExists(player: unknown): void {
  if (!player) {
    throw new HttpsError(
      "not-found",
      "플레이어를 찾을 수 없습니다.",
    );
  }
}

export function assertPlayerAlive(
  status: string,
): void {
  if (status !== "alive") {
    throw new HttpsError(
      "failed-precondition",
      "탈락한 플레이어입니다.",
    );
  }
}

export function assertPlayerTurn(
  turnUid: string,
  uid: string,
): void {
  if (turnUid !== uid) {
    throw new HttpsError(
      "failed-precondition",
      "현재 턴이 아닙니다.",
    );
  }
}

export function assertGameStatus(
  currentStatus: string,
  expectedStatus: string,
): void {
  if (currentStatus !== expectedStatus) {
    throw new HttpsError(
      "failed-precondition",
      `현재 게임 상태는 '${expectedStatus}'가 아닙니다.`,
    );
  }
}

export function assertCardsNotEmpty(
  cards: unknown[],
): void {
  if (!cards || cards.length === 0) {
    throw new HttpsError(
      "invalid-argument",
      "제출할 카드가 없습니다.",
    );
  }
}

export function assertCardCount(
  cards: unknown[],
  maxCount = 3,
): void {
  if (cards.length > maxCount) {
    throw new HttpsError(
      "invalid-argument",
      `카드는 최대 ${maxCount}장까지 제출 가능합니다.`,
    );
  }
}
