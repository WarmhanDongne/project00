export type GameInterruptionReason = "disconnected" | "left";

export interface PublicGameInterruption {
  id: string;
  playerUid: string;
  playerNickname: string;
  playerCharacterId: string;
  reason: GameInterruptionReason;
  startedAt: number;
  deadlineAt: number;
  eligibleVoterUids: string[];
  requiredVotes: number;
  votes?: Record<string, true>;
  remainingPlayerCount: number;
  minimumPlayerCount: number;
  canContinue: boolean;
}

export interface ServerGameInterruption {
  id: string;
  previousTurnRemainingMs: number | null;
}

export interface InterruptiblePublicGameState {
  status: string;
  revision: number;
  updatedAt: number;
  turnDeadlineAt: number | null;
  players: Record<string, {status: string}>;
  interruption?: PublicGameInterruption;
}

export interface InterruptibleServerGameState {
  interruption?: ServerGameInterruption;
}

export interface InterruptibleGameState {
  public: InterruptiblePublicGameState;
  server: InterruptibleServerGameState;
}
