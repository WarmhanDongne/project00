/* eslint-disable valid-jsdoc */

import {randomInt, randomUUID} from "node:crypto";

import {
  LIARS_POKER_RANKS,
  LiarsPokerCard,
  LiarsPokerPlayer,
  LiarsPokerRank,
} from "./types.js";

export const CARDS_PER_PLAYER = 5;
export const MIN_PLAYERS = 2;
export const MAX_PLAYERS = 6;

/**
 * 이번 라운드의 기준 카드 랭크를 무작위로 선택합니다.
 * @return 선택된 카드 랭크
 */
export function randomTableRank(): LiarsPokerRank {
  return LIARS_POKER_RANKS[randomInt(LIARS_POKER_RANKS.length)];
}

/**
 * 플레이어 수에 맞는 카드 덱을 만들고 섞습니다.
 * @param playerCount 플레이어 수
 * @return 섞인 카드 덱
 */
export function createShuffledDeck(playerCount: number): LiarsPokerCard[] {
  const cardCount = playerCount * CARDS_PER_PLAYER;
  const jokerCount = Math.max(2, Math.floor(playerCount / 2));
  const normalCardCount = cardCount - jokerCount;
  const deck: LiarsPokerCard[] = [];

  for (let index = 0; index < normalCardCount; index += 1) {
    deck.push({
      id: randomUUID(),
      rank: LIARS_POKER_RANKS[index % LIARS_POKER_RANKS.length],
    });
  }
  for (let index = 0; index < jokerCount; index += 1) {
    deck.push({id: randomUUID(), rank: "JOKER"});
  }

  for (let index = deck.length - 1; index > 0; index -= 1) {
    const swapIndex = randomInt(index + 1);
    [deck[index], deck[swapIndex]] = [deck[swapIndex], deck[index]];
  }
  return deck;
}

/**
 * 제출 카드가 테이블 랭크 또는 조커로만 구성됐는지 확인합니다.
 * @param cards 제출된 실제 카드
 * @param tableRank 이번 라운드의 기준 랭크
 * @return 진실인 제출이면 true
 */
export function isTruthfulPlay(
  cards: LiarsPokerCard[],
  tableRank: LiarsPokerRank,
): boolean {
  return cards.every(
    (card) => card.rank === tableRank || card.rank === "JOKER",
  );
}

/**
 * 현재 플레이어 다음에 있는 탈락하지 않은 플레이어를 찾습니다.
 * @param players 공개 플레이어 목록
 * @param currentPlayerId 현재 플레이어 UID
 * @return 다음 플레이어 UID
 */
export function nextActivePlayerId(
  players: LiarsPokerPlayer[],
  currentPlayerId: string,
): string {
  const currentIndex = players.findIndex(
    (player) => player.uid === currentPlayerId,
  );
  if (currentIndex < 0) {
    throw new Error("현재 플레이어를 찾을 수 없습니다.");
  }

  for (let offset = 1; offset <= players.length; offset += 1) {
    const player = players[(currentIndex + offset) % players.length];
    if (!player.eliminated) return player.uid;
  }
  throw new Error("진행 가능한 플레이어가 없습니다.");
}
