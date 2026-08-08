/* eslint-disable valid-jsdoc */

import {
  LiarsPokerGameState,
  ProcessedCommand,
} from "./types.js";

/** 이미 처리한 명령이면 저장된 응답을 반환합니다. */
export function processedResult(
  game: LiarsPokerGameState,
  commandId: string,
): Record<string, unknown> | null {
  return game.server.processedCommands?.[commandId]?.result ?? null;
}

/** 명령 결과를 저장해 네트워크 재시도가 게임을 두 번 진행하지 않게 합니다. */
export function recordCommand(
  game: LiarsPokerGameState,
  commandId: string,
  command: ProcessedCommand,
): void {
  game.server.processedCommands ??= {};
  game.server.processedCommands[commandId] = {
    ...command,
    // RTDB는 중첩 객체 안의 undefined도 허용하지 않습니다.
    result: removeUndefined(command.result) as Record<string, unknown>,
  };
}

/** 명령 응답을 RTDB에 안전하게 저장할 수 있는 값으로 정리합니다. */
function removeUndefined(value: unknown): unknown {
  if (Array.isArray(value)) {
    return value.map(
      (item) => item === undefined ? null : removeUndefined(item),
    );
  }

  if (value !== null && typeof value === "object") {
    const result: Record<string, unknown> = {};
    for (const [key, item] of Object.entries(
      value as Record<string, unknown>,
    )) {
      if (item !== undefined) result[key] = removeUndefined(item);
    }
    return result;
  }

  return value;
}
