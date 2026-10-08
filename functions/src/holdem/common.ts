/* eslint-disable valid-jsdoc, require-jsdoc, max-len */

import {HoldemGameState, HoldemProcessedCommand} from "./types.js";

export function processedHoldemResult(
  game: HoldemGameState,
  commandId: string,
): Record<string, unknown> | null {
  return game.server.processedCommands?.[commandId]?.result ?? null;
}

export function recordHoldemCommand(
  game: HoldemGameState,
  commandId: string,
  command: HoldemProcessedCommand,
): void {
  game.server.processedCommands ??= {};
  game.server.processedCommands[commandId] = {
    ...command,
    result: removeUndefined(command.result) as Record<string, unknown>,
  };
}

function removeUndefined(value: unknown): unknown {
  if (Array.isArray(value)) return value.map((item) => item === undefined ? null : removeUndefined(item));
  if (value !== null && typeof value === "object") {
    return Object.fromEntries(Object.entries(value as Record<string, unknown>)
      .filter(([, item]) => item !== undefined)
      .map(([key, item]) => [key, removeUndefined(item)]));
  }
  return value;
}
