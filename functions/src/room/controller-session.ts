/* eslint-disable valid-jsdoc */

import {randomUUID} from "node:crypto";

import {HttpsError} from "firebase-functions/v2/https";

const CONTROLLER_SESSION_ID =
  /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export interface ControllerSessionRoom {
  controllerUid?: string;
  hostUid?: string;
  controllerSessionId?: string;
}

/** 새 controller 인스턴스를 구분하는 추측 불가능한 세션 ID를 만듭니다. */
export function createControllerSessionId(): string {
  return randomUUID();
}

/** callable 입력의 controller session ID를 검증합니다. */
export function parseControllerSessionId(value: unknown): string {
  const sessionId = typeof value === "string" ? value.trim() : "";
  if (!CONTROLLER_SESSION_ID.test(sessionId)) {
    throw new HttpsError(
      "invalid-argument",
      "controller 세션 정보가 필요합니다.",
    );
  }
  return sessionId;
}

/** UID뿐 아니라 현재 활성 controller 세션까지 함께 검사합니다. */
export function assertControllerSession(
  room: ControllerSessionRoom,
  uid: string,
  rawSessionId: unknown,
): string {
  if ((room.controllerUid ?? room.hostUid) !== uid) {
    throw new HttpsError(
      "permission-denied",
      "방을 만든 태블릿에서만 진행할 수 있습니다.",
    );
  }

  const sessionId = parseControllerSessionId(rawSessionId);
  if (!room.controllerSessionId || room.controllerSessionId !== sessionId) {
    throw new HttpsError(
      "permission-denied",
      "만료된 태블릿 세션입니다. 방을 다시 연결해주세요.",
    );
  }
  return sessionId;
}
