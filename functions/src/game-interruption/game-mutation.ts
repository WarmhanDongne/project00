/* eslint-disable require-jsdoc, valid-jsdoc, max-len */
import {operationFingerprint} from "../room/session-contract.js";
import {beginRecoveryPause, clearFinishedRecovery, recoveryTimer, RecoveryGame, RecoveryRoom} from "./recovery-state.js";

const PUBLIC_META = new Set([
  "revision", "updatedAt", "gameInstanceId", "phaseSeq", "turnSeq", "dataSeq", "resumeEpoch", "recovery",
]);

function phaseKey(game: RecoveryGame): string {
  const pub = game.public;
  return operationFingerprint([pub.phase, pub.round, pub.handNumber, pub.nightStage, pub.dayStage, pub.trialStage, pub.trialUid]);
}
function turnKey(game: RecoveryGame): string {
  return operationFingerprint([phaseKey(game), game.public.turnUid, game.public.turnNumber]);
}
function semanticKey(game: RecoveryGame): string {
  const publicState = Object.fromEntries(Object.entries(game.public).filter(([key]) => !PUBLIC_META.has(key)));
  const privateState = Object.fromEntries(Object.entries(game.private ?? {}).map(([uid, entry]) =>
    [uid, Object.fromEntries(Object.entries(entry).filter(([key]) => key !== "_context"))]));
  return operationFingerprint([publicState, privateState]);
}

/** Called once at every room transaction's game mutation boundary. */
export function finalizeGameMutation(room: RecoveryRoom, before: RecoveryGame | undefined, now: number, newGameId: string): void {
  const game = room.game;
  if (!game) return;
  const newGame = !before || before.public.startedAt !== game.public.startedAt ||
    before.public.gameType !== game.public.gameType;
  const changed = newGame || semanticKey(before!) !== semanticKey(game);
  if (!changed) return;
  if (newGame) {
    game.public.gameInstanceId = newGameId;
    game.public.phaseSeq = 1;
    game.public.turnSeq = 1;
    game.public.dataSeq = 1;
    game.public.resumeEpoch = 0;
    beginRecoveryPause(room, now);
  } else {
    game.public.gameInstanceId = before!.public.gameInstanceId;
    game.public.phaseSeq = (before!.public.phaseSeq ?? 0) + (phaseKey(before!) !== phaseKey(game) ? 1 : 0);
    game.public.turnSeq = (before!.public.turnSeq ?? 0) + (turnKey(before!) !== turnKey(game) ? 1 : 0);
    game.public.dataSeq = (before!.public.dataSeq ?? 0) + 1;
    if (game.public.recovery?.paused && game.server.recovery) {
      game.public.resumeEpoch = (before!.public.resumeEpoch ?? 0) + 1;
      game.server.recovery.ready = {};
      if (turnKey(before!) !== turnKey(game)) {
        game.server.recovery.timer = recoveryTimer(game.public.turnDeadlineAt, now, game.public.phaseSeq ?? 0, game.public.turnSeq ?? 0);
      }
      game.public.turnDeadlineAt = null;
    }
  }
  for (const entry of Object.values(game.private ?? {})) {
    entry._context = {
      gameInstanceId: game.public.gameInstanceId, phaseSeq: game.public.phaseSeq,
      turnSeq: game.public.turnSeq, dataSeq: game.public.dataSeq,
    };
  }
  clearFinishedRecovery(game);
}
