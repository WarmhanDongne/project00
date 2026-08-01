export const LIARS_POKER_GAME_IDS = new Set(["liars_poker"]);
export const LIARS_POKER_RANKS = ["A", "K", "Q"] as const;

export type LiarsPokerRank = typeof LIARS_POKER_RANKS[number];
export type LiarsPokerCardRank = LiarsPokerRank | "JOKER";

export type LiarsPokerCard = {
  id: string;
  rank: LiarsPokerCardRank;
};

export type LiarsPokerPlayer = {
  uid: string;
  nickname: string;
  profileImageUrl: string;
  seatIndex: number;
  remainingCardCount: number;
  eliminated: boolean;
};

export type PublicPlay = {
  playId: string;
  playerId: string;
  cardCount: number;
  declaredRank: LiarsPokerRank;
  revealed: boolean;
};
