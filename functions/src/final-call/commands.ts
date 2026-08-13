/* eslint-disable require-jsdoc */

import {FinalCallGameState} from "./types.js";

export function finalCallProcessed(
  game: FinalCallGameState,
  commandId: string,
): Record<string, unknown> | null {
  return game.server.processedCommands[commandId]?.result ?? null;
}

export function recordFinalCallCommand(
  game: FinalCallGameState,
  commandId: string,
  uid: string,
  type: string,
  now: number,
  result: Record<string, unknown>,
): void {
  game.server.processedCommands[commandId] = {
    uid,
    type,
    createdAt: now,
    result,
  };
}
