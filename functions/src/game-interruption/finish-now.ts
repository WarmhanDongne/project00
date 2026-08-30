/* eslint-disable max-len, valid-jsdoc, require-jsdoc */

import {getDatabase} from "firebase-admin/database";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {
  FinishNowRoom,
  resolveInterruptionFinishNow,
} from "./finish-now-resolution.js";

// callable은 HTTPS라 Realtime Database 리전 제약을 받지 않습니다. 자세한 배경은
// functions.ts 상단 주석을 보세요. 클라이언트도 이 리전으로 고정돼 있습니다
// (lib/games/shared/services/game_interruption_command_service.dart).
const REGION = "asia-northeast3";
const ROOM_CODE = /^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{5}$/;
const INTERRUPTION_ID = /^[A-Za-z0-9_-]{3,160}$/;

type Data = {
  roomCode?: unknown;
  interruptionId?: unknown;
  controllerSessionId?: unknown;
};

const ALREADY_RESOLVED = {
  success: true,
  finished: false,
  alreadyResolved: true,
};

/**
 * 인원 부족이 확정된 중단을 60초 마감을 기다리지 않고 즉시 정상 종료합니다.
 *
 * `game_common_interruption_expire`의 `canContinue === false` 분기와 같은 결과를
 * 만들되 마감 검사만 없앤 경로입니다. 마감 검사를 넣지 않는 이유:
 *
 * - 기다려서 얻을 수 있는 다른 결론이 없습니다. 계속할 수 없는 중단이 마감까지
 *   가서 도달하는 상태는 이 함수가 만드는 것과 동일합니다.
 * - 이탈자가 돌아오면 재접속 트리거가 중단을 취소하고, 그 뒤에 도착한 이 호출은
 *   interruptionId 대조로 alreadyResolved가 됩니다. 반대 순서면 status가 이미
 *   finished라 재접속 쪽이 조기 반환합니다. 어느 쪽이든 안전합니다.
 * - 휴대폰 오버레이가 0초에 자동으로 expire를 호출하므로, 마감 직후 호출은
 *   정상 경합입니다. 여기서 시간 검사를 넣으면 정상 동작을 오류로 바꿉니다.
 *
 * ⚠️ 이름을 바꾸면 구버전 앱이 함수를 찾지 못합니다. `expire`도 삭제하지
 * 마세요 — 마감 자동 만료와 `canContinue === true` 중단의 만료는 그 함수 몫입니다.
 */
export const game_common_interruption_finish_now = onCall<Data>(
  {region: REGION},
  async (request) => {
    const uid = requireUid(request.auth?.uid);
    const roomCode = parseRoomCode(request.data?.roomCode);
    const interruptionId = parseInterruptionId(request.data?.interruptionId);
    const roomRef = getDatabase().ref(`rooms/${roomCode}`);
    let response: Record<string, unknown> | null = null;
    let roomMissing = false;

    const transaction = await roomRef.transaction((raw) => {
      if (raw === null) {
        // 방이 이미 정리됐으면 게임도 끝난 것으로 봅니다. 여기서 aborted를
        // 던지면 CallableRetryPolicy가 일시 오류로 보고 12초간 헛재시도합니다.
        roomMissing = true;
        return raw;
      }
      response = resolveInterruptionFinishNow(raw as FinishNowRoom, {
        uid,
        interruptionId,
        controllerSessionId: request.data?.controllerSessionId,
        now: Date.now(),
      });
      return raw;
    });

    if (roomMissing) return ALREADY_RESOLVED;
    if (!transaction.committed || !response) {
      throw new HttpsError("aborted", "게임을 즉시 종료하지 못했습니다.");
    }
    return response;
  },
);

function requireUid(uid: string | undefined): string {
  if (!uid) throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
  return uid;
}

function parseRoomCode(value: unknown): string {
  const roomCode = typeof value === "string" ? value.trim().toUpperCase() : "";
  if (!ROOM_CODE.test(roomCode)) {
    throw new HttpsError("invalid-argument", "올바른 방 코드가 아닙니다.");
  }
  return roomCode;
}

function parseInterruptionId(value: unknown): string {
  const id = typeof value === "string" ? value.trim() : "";
  if (!INTERRUPTION_ID.test(id)) {
    throw new HttpsError("invalid-argument", "올바른 게임 중단 ID가 아닙니다.");
  }
  return id;
}
