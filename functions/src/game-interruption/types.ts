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

/**
 * 태블릿(진행 기기) 단절로 멈춘 턴의 보관 슬롯입니다.
 *
 * ⚠️ `interruption`과 **반드시 다른 슬롯**입니다. 참가자 단절과 태블릿 단절은
 * 동시에 일어날 수 있고, 하나의 슬롯을 공유하면 나중에 온 쪽이 앞의 남은 시간을
 * 덮어써 복구할 값이 사라집니다.
 */
export interface ServerControllerPause {
  // null만 든 객체는 RTDB에서 사라지므로 중단 자체를 보존합니다.
  // 이전 저장 데이터와의 호환을 위해 읽는 쪽에서는 선택 필드입니다.
  startedAt?: number;
  previousTurnRemainingMs: number | null;
}

export interface InterruptibleServerGameState {
  interruption?: ServerGameInterruption;
  controllerPause?: ServerControllerPause;
}

export interface InterruptibleGameState {
  public: InterruptiblePublicGameState;
  server: InterruptibleServerGameState;
}
