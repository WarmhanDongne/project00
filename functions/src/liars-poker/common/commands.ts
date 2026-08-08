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
  game.server.processedCommands[commandId] = command;
}
