/* eslint-disable require-jsdoc, valid-jsdoc, max-len */
import {excludeFinalCallPlayer} from "../final-call/exclude-player.js";
import {FinalCallGameState} from "../final-call/types.js";
import {excludeLiarsPokerPlayer} from "../liars-poker/exclude-player.js";
import {LiarsPokerGameState} from "../liars-poker/common/types.js";
import {excludeMafiaPlayer} from "../mafia/exclude-player.js";
import {MafiaGameState} from "../mafia/types.js";
import {excludeHoldemPlayer} from "../holdem/game.js";
import {HoldemGameState} from "../holdem/types.js";
import {RecoveryRoom} from "./recovery-state.js";
import {withTransactionRandom} from "../common/transaction-random.js";

export function excludeRecoveryPlayer(room: RecoveryRoom, uid: string, now: number): void {
  const game = room.game;
  if (!game) return;
  switch (room.selectedGame) {
  case "liars_poker": excludeLiarsPokerPlayer(game as unknown as LiarsPokerGameState, uid, now); break;
  case "final_call": excludeFinalCallPlayer(game as unknown as FinalCallGameState, uid, now); break;
  case "mafia": excludeMafiaPlayer(game as unknown as MafiaGameState, uid, now); break;
  case "holdem": excludeHoldemPlayer(game as unknown as HoldemGameState, uid, now); break;
  default: throw new Error("Unsupported recovery adapter");
  }
}

export function previewRecoveryExclusion(room: RecoveryRoom, uid: string, now: number): {
  canContinue: boolean; reason: string; room: RecoveryRoom;
} {
  const preview = structuredClone(room);
  // A dry run has no externally visible randomness and must not consume command entropy.
  withTransactionRandom(Buffer.alloc(32), () => excludeRecoveryPlayer(preview, uid, now));
  const pub = preview.game?.public;
  const cannot = pub?.status === "finished" && pub.finishReason === "insufficientPlayers";
  return {canContinue: !cannot, reason: cannot ? "insufficientPlayers" : "continue", room: preview};
}

export function decorateRecoveryCauses(room: RecoveryRoom, now: number): void {
  for (const cause of Object.values(room.game?.public.recovery?.causes ?? {})) {
    if (cause.role === "player") cause.canContinue = previewRecoveryExclusion(room, cause.uid, now).canContinue;
  }
}
