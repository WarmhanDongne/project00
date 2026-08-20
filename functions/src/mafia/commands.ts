/* eslint-disable require-jsdoc */

import {MafiaGameState} from "./types.js";

export function mafiaProcessed(
  game: MafiaGameState,
  commandId: string,
): Record<string, unknown> | null {
  return game.server.processedCommands?.[commandId]?.result ?? null;
}

export function recordMafiaCommand(
  game: MafiaGameState,
  commandId: string,
  uid: string,
  type: string,
  now: number,
  result: Record<string, unknown>,
): void {
  // Realtime Database는 빈 객체를 저장하지 않으므로 첫 명령에서 다시 만듭니다.
  game.server.processedCommands ??= {};
  game.server.processedCommands[commandId] = {
    uid,
    type,
    createdAt: now,
    result,
  };
}
