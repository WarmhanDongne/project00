/* eslint-disable max-len */

import {PublicGameInterruption, ServerGameInterruption} from "../game-interruption/types.js";

export const FINAL_CALL_TURN_MS = 30000;
export const FINAL_CALL_CARDS_PER_PLAYER = 4;

export type FinalCallColor = "red" | "blue" | "yellow" | "green";
export type FinalCallTeam = "red" | "blue";

export interface FinalCallCard {
  id: string;
  color: FinalCallColor;
  value: number;
}

export interface FinalCallPlayer {
  uid: string;
  nickname: string;
  characterId: string;
  seatIndex: number;
  team: FinalCallTeam;
  status: "alive" | "eliminated";
  lives: number;
}

export interface FinalCallRoundResult {
  scores: Record<string, number>;
  lifeLosses: Record<string, number>;
  lowestUids: string[];
  revealedHands: Record<string, FinalCallCard[]>;
  callerUid: string | null;
  automaticCall: boolean;
  /**
   * CALL을 선언한 플레이어가 같은 숫자 4장을 제출했는지 여부입니다.
   *
   * true면 최저 점수 판정 대신 상대팀 전원이 하트를 하나씩 잃습니다. 결과만
   * 봐서는 왜 상대팀만 하트를 잃었는지 알 수 없으므로 판정 근거를 함께 남깁니다.
   */
  callerFourOfAKind: boolean;
  resolvedAt: number;
}

export interface FinalCallPublicState {
  gameType: "final_call";
  status: "playing" | "finished";
  finishReason?: "winner" | "draw" | "manual" | "insufficientPlayers" | "interruptionVoteExpired";
  phase: "dealing" | "playing" | "callerSubmit" | "finalTurns" |
    "finalSubmit" |
    "roundResult" | "finished";
  round: number;
  revision: number;
  turnUid: string | null;
  turnDeadlineAt: number | null;
  callerUid: string | null;
  deckRemainingCount: number;
  discardCard: FinalCallCard;
  pendingDrawUid: string | null;
  pendingDrawSource: "deck" | "discard" | null;
  finalTurnPendingUids: string[];
  players: Record<string, FinalCallPlayer>;
  roundResult?: FinalCallRoundResult;
  /** 태블릿의 최종 카드 공개 연출이 모두 끝난 시각입니다. */
  resultRevealCompletedAt?: number;
  winnerUid: string | null;
  winnerUids: string[];
  winningTeam: FinalCallTeam | null;
  startedAt: number;
  updatedAt: number;
  finishedAt?: number;
  interruption?: PublicGameInterruption;
}

export interface FinalCallPrivatePlayer {
  hand: Record<string, FinalCallCard>;
  pendingDraw?: FinalCallCard;
}

export interface FinalCallProcessedCommand {
  uid: string;
  type: string;
  createdAt: number;
  result: Record<string, unknown>;
}

export interface FinalCallServerState {
  deck: FinalCallCard[];
  pendingHands?: Record<string, FinalCallPrivatePlayer>;
  finalSubmissions?: Record<string, FinalCallCard[]>;
  processedCommands?: Record<string, FinalCallProcessedCommand>;
  roundStarterUid: string;
  interruption?: ServerGameInterruption;
}

export interface FinalCallGameState {
  public: FinalCallPublicState;
  private: Record<string, FinalCallPrivatePlayer>;
  server: FinalCallServerState;
}

export interface FinalCallRoom {
  controllerUid?: string;
  controllerSessionId?: string;
  hostUid?: string;
  status?: string;
  selectedGame?: string;
  players?: Record<string, Record<string, unknown>>;
  game?: FinalCallGameState;
}
