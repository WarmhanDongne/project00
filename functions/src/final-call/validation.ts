/* eslint-disable valid-jsdoc, max-len, require-jsdoc */

import {CallableRequest, HttpsError} from "firebase-functions/v2/https";

import {isSafeRecordKey} from "../common/own-entry.js";
import {assertControllerSession} from "../room/controller-session.js";
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
  if (!COMMAND_ID.test(id) || !isSafeRecordKey(id)) {
    throw new HttpsError("invalid-argument", "올바른 commandId가 필요합니다.");
  }
  return id;
}

export function requireFinalCallGame(
  room: FinalCallRoom,
  options: {allowInterruption?: boolean} = {},
): FinalCallGameState {
  if (!room.game || room.game.public?.gameType !== "final_call") {
    throw new HttpsError("failed-precondition", "Final Call 게임이 없습니다.");
  }
  if (room.game.public.interruption && !options.allowInterruption) {
    throw new HttpsError("failed-precondition", "플레이어 연결 확인 중에는 게임을 진행할 수 없습니다.");
  }
  return restoreEmptyFinalCallLists(room.game);
}

/**
 * Realtime Database가 지운 빈 배열 필드를 빈 배열로 되돌립니다.
 *
 * RTDB는 빈 배열을 저장하지 않아 다시 읽으면 필드 자체가 사라집니다. 덱의
 * 마지막 카드를 가져오면 `server.deck`이 없어져, 다음 카드 교체와 시간 초과
 * 처리가 `deck.length`에서 오류로 멈추고 게임 전체가 진행되지 않았습니다.
 * @param {FinalCallGameState} game 데이터베이스에서 읽은 게임 상태
 * @return {FinalCallGameState} 배열 필드가 채워진 같은 게임 상태
 */
export function restoreEmptyFinalCallLists(
  game: FinalCallGameState,
): FinalCallGameState {
  game.server.deck ??= [];
  game.public.finalTurnPendingUids ??= [];
  game.public.winnerUids ??= [];
  return game;
}

export function assertFinalCallController(
  room: FinalCallRoom,
  uid: string,
  controllerSessionId: unknown,
): void {
  assertControllerSession(room, uid, controllerSessionId);
}

export function assertFinalCallTurn(game: FinalCallGameState, uid: string): void {
  if (game.public.status !== "playing" || game.public.turnUid !== uid) {
    throw new HttpsError("failed-precondition", "현재 내 턴이 아닙니다.");
  }
  if (game.public.players[uid]?.status !== "alive") {
    throw new HttpsError("failed-precondition", "탈락한 플레이어입니다.");
  }
}
