/* eslint-disable valid-jsdoc */

import {HttpsError} from "firebase-functions/v2/https";

type StartableRoom = {
  selectedGame?: unknown;
  status?: unknown;
  players?: unknown;
};

/** 시작 준비와 커밋 사이에 로비 참가자/좌석이 바뀌었는지 비교합니다. */
export function startGameFingerprint(room: StartableRoom): string {
  return JSON.stringify(stableValue({
    selectedGame: room.selectedGame,
    status: room.status,
    players: room.players,
  }));
}

/** 사전 계산한 게임이 다른 로비 스냅샷에 기록되는 TOCTOU를 차단합니다. */
export function assertStartGameSnapshot(
  expectedFingerprint: string,
  currentRoom: StartableRoom,
): void {
  if (startGameFingerprint(currentRoom) !== expectedFingerprint) {
    throw new HttpsError(
      "aborted",
      "게임을 준비하는 동안 참가자 또는 좌석이 바뀌었습니다. 다시 시도해주세요.",
    );
  }
}

/** 객체 키 순서와 무관한 JSON 값으로 정규화합니다. */
function stableValue(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(stableValue);
  if (value && typeof value === "object") {
    const object = value as Record<string, unknown>;
    return Object.fromEntries(
      Object.keys(object)
        .sort()
        .map((key) => [key, stableValue(object[key])]),
    );
  }
  return value;
}
