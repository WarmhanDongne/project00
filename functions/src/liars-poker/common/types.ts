/* eslint-disable max-len */

import {PublicGameInterruption, ServerGameInterruption} from "../../game-interruption/types.js";

export const CARD_RANKS = ["A", "K", "Q", "JOKER"] as const;

export type CardRank = typeof CARD_RANKS[number];

export const TURN_DURATION_MS = 30000;
export const LAST_CARD_CHALLENGE_DURATION_MS = 10000;

export interface GameCard {
  id: string;
  rank: CardRank;
}

export interface PublicGamePlayer {
  uid: string;
  nickname: string;
  profileImageUrl: string;
  seatIndex: number;
  status: "alive" | "eliminated";
  penaltyCount: number;
  remainingCardCount: number;
}

export interface PublicLastPlay {
  playId: string;
  round: number;
  playerUid: string;
  cardCount: number;
  declaredRank: Exclude<CardRank, "JOKER">;
  revealed: boolean;
  actualRanks?: CardRank[];
  submittedAt: number;
}

export interface PublicPenaltyResult {
  targetUid: string;
  result: "safe" | "eliminated";
  resolvedAt: number;
}

export interface PublicGameState {
  status: "playing" | "finished";
  finishReason?: "winner" | "manual" | "insufficientPlayers" | "interruptionVoteExpired";
  phase: "dealing" | "playing" | "lastCardChallenge" | "penalty" |
    "finished";
  round: number;
  revision: number;
  table: Exclude<CardRank, "JOKER">;
  turnUid: string | null;
  turnDeadlineAt: number | null;
  isFirstTurnReady?: boolean;
  lastPlay: PublicLastPlay | null;
  /** 현재 라운드에 제출된 공개 카드 묶음입니다. 실제 랭크는 공개 전까지 없습니다. */
  roundPlays?: Record<string, PublicLastPlay>;
  penaltyTargetUid: string | null;
  penaltyResult?: PublicPenaltyResult;
  winnerUid: string | null;
  players: Record<string, PublicGamePlayer>;
  startedAt: number;
  updatedAt: number;
  finishedAt?: number;
  interruption?: PublicGameInterruption;
}

export interface PrivatePlayerState {
  hand: Record<string, GameCard>;
}

export interface ProcessedCommand {
  uid: string;
  type: string;
  createdAt: number;
  result: Record<string, unknown>;
}

export interface ServerGameState {
  lastPlayCards: GameCard[] | null;
  processedCommands: Record<string, ProcessedCommand>;
  roundStarterUid: string;
  /** 1대1 LIAR 실패로 룰렛 전에 penaltyCount를 이미 올렸는지 표시합니다. */
  penaltyCountIncrementedBeforeRoulette?: boolean;
  /** 태블릿 배분 연출이 끝나기 전까지 클라이언트에 공개하지 않는 손패입니다. */
  pendingHands?: Record<string, PrivatePlayerState>;
  interruption?: ServerGameInterruption;
}

export interface LiarsPokerGameState {
  public: PublicGameState;
  private: Record<string, PrivatePlayerState>;
  server: ServerGameState;
}

export interface RealtimeRoom {
  controllerUid?: string;
  controllerSessionId?: string;
  hostUid?: string;
  selectedGame?: string;
  players?: Record<string, Record<string, unknown>>;
  game?: LiarsPokerGameState;
}
