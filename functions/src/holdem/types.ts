/* eslint-disable valid-jsdoc, max-len */

import {PublicGameInterruption, ServerGameInterruption} from "../game-interruption/types.js";

export const HOLDEM_SUITS = ["clubs", "diamonds", "hearts", "spades"] as const;
export const HOLDEM_RANKS = [
  "2", "3", "4", "5", "6", "7", "8", "9", "10", "j", "q", "k", "a",
] as const;

export type HoldemSuit = typeof HOLDEM_SUITS[number];
export type HoldemRank = typeof HOLDEM_RANKS[number];

export type HoldemCard = {
  id: string;
  suit: HoldemSuit;
  rank: HoldemRank;
};

export type HoldemHandCategory =
  | "highCard"
  | "onePair"
  | "twoPair"
  | "threeOfAKind"
  | "straight"
  | "flush"
  | "fullHouse"
  | "fourOfAKind"
  | "straightFlush";

export type HoldemHandValue = {
  category: HoldemHandCategory;
  categoryRank: number;
  tiebreak: number[];
  bestCards: HoldemCard[];
};

export type HoldemSeatPlayer = {
  uid: string;
  seatIndex: number;
  stack: number;
  status: "active" | "folded" | "allIn" | "eliminated";
};

export type HoldemPositions = {
  dealerUid: string;
  smallBlindUid: string;
  bigBlindUid: string;
  preflopFirstUid: string;
  postflopFirstUid: string;
};

export type HoldemBetPlayer = HoldemSeatPlayer & {
  streetContribution: number;
  totalContribution: number;
  hasActed: boolean;
  lastActionCurrentBet: number;
  lastActionKind: "none" | "check" | "call" | "bet" | "raise" | "allIn";
};

export type HoldemBettingRound = {
  currentBet: number;
  minimumRaise: number;
  turnUid: string | null;
  players: Record<string, HoldemBetPlayer>;
};

export type HoldemAction =
  | {kind: "fold"}
  | {kind: "check"}
  | {kind: "call"}
  | {kind: "allIn"}
  | {kind: "bet"; targetContribution: number}
  | {kind: "raise"; targetContribution: number};

export type HoldemLegalActions = {
  fold: boolean;
  check: boolean;
  call: boolean;
  bet: boolean;
  raise: boolean;
  allIn: boolean;
  toCall: number;
  callAmount: number;
  minimumTarget: number | null;
  maximumTarget: number;
};

export type HoldemPotContribution = {
  uid: string;
  seatIndex: number;
  amount: number;
  folded: boolean;
};

export type HoldemPot = {
  amount: number;
  cap: number;
  contributorUids: string[];
  eligibleUids: string[];
};

export type HoldemPotBuildResult = {
  pots: HoldemPot[];
  refunds: Record<string, number>;
};

export type HoldemPotAward = {
  potIndex: number;
  amount: number;
  winnerUids: string[];
  shares: Record<string, number>;
};

export type HoldemSettlement = {
  awards: Record<string, number>;
  pots: HoldemPotAward[];
};

export type HoldemPlayerStatus =
  | "active"
  | "folded"
  | "allIn"
  | "eliminated";

export type HoldemPublicPlayer = {
  uid: string;
  nickname: string;
  characterId: string;
  seatIndex: number;
  stack: number;
  status: "alive" | "eliminated";
  handStatus: HoldemPlayerStatus;
  streetContribution: number;
  totalContribution: number;
};

export type HoldemPublicResult = {
  reason: "fold" | "showdown";
  winnerUids: string[];
  awards: Record<string, number>;
  revealedHands: Record<string, HoldemCard[]>;
  handCategories: Record<string, HoldemHandCategory>;
  /** 쇼다운 참가자별 최종 5장입니다. 화면 강조용이며 구버전 결과에는 없습니다. */
  bestCards?: Record<string, HoldemCard[]>;
};

export type HoldemPublicGameState = {
  gameType: "holdem";
  status: "playing" | "finished";
  finishReason?: "winner" | "manual" | "insufficientPlayers" |
    "interruptionVoteExpired";
  phase: "dealing" | "preflop" | "flop" | "turn" | "river" |
    "handResult" | "finished";
  handNumber: number;
  revision: number;
  dealerUid: string;
  smallBlindUid: string;
  bigBlindUid: string;
  smallBlind: number;
  bigBlind: number;
  communityCards: HoldemCard[];
  pots: Array<{amount: number; eligibleUids: string[]}>;
  potTotal: number;
  turnUid: string | null;
  turnDeadlineAt: number | null;
  currentBet: number;
  minimumRaise: number;
  lastAction: {
    uid: string;
    kind: HoldemAction["kind"];
    amount: number;
    createdAt: number;
  } | null;
  result: HoldemPublicResult | null;
  winnerUid: string | null;
  players: Record<string, HoldemPublicPlayer>;
  startedAt: number;
  updatedAt: number;
  finishedAt?: number;
  interruption?: PublicGameInterruption;
};

export type HoldemHandRank = {
  category: HoldemHandCategory;
  bestCards: HoldemCard[];
};

export type HoldemPrivatePlayerState = {
  hand: HoldemCard[];
  legalActions: HoldemLegalActions | null;
  /** 홀 카드와 공개 보드로 만든 현재 족보입니다. 화면 표시 전용입니다. */
  handRank?: HoldemHandRank | null;
};

export type HoldemProcessedCommand = {
  uid: string;
  type: string;
  createdAt: number;
  result: Record<string, unknown>;
};

export type HoldemServerGameState = {
  deck: HoldemCard[];
  deckIndex: number;
  betting: HoldemBettingRound;
  processedCommands: Record<string, HoldemProcessedCommand>;
  previousDealerSeat: number | null;
  interruption?: ServerGameInterruption;
};

export type HoldemGameState = {
  public: HoldemPublicGameState;
  private: Record<string, HoldemPrivatePlayerState>;
  server: HoldemServerGameState;
};

export type HoldemRoom = {
  controllerUid?: string;
  controllerSessionId?: string;
  hostUid?: string;
  status?: string;
  selectedGame?: string;
  players?: Record<string, Record<string, unknown>>;
  game?: HoldemGameState;
};
