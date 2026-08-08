/* eslint-disable valid-jsdoc */

import {randomInt, randomUUID} from "node:crypto";

import {CardRank, GameCard} from "./types.js";

/** 플레이어 수에 맞는 카드를 생성하고 안전하게 섞습니다. */
export function createDeck(playerCount: number): GameCard[] {
  const counts = deckCounts(playerCount);
  const deck: GameCard[] = [];

  for (const [rank, count] of Object.entries(counts)) {
    for (let index = 0; index < count; index += 1) {
      deck.push({id: randomUUID(), rank: rank as CardRank});
    }
  }

  for (let index = deck.length - 1; index > 0; index -= 1) {
    const swapIndex = randomInt(index + 1);
    [deck[index], deck[swapIndex]] = [deck[swapIndex], deck[index]];
  }
  return deck;
}

/** 플레이어 수별 덱 구성을 반환합니다. */
function deckCounts(playerCount: number): Record<CardRank, number> {
  switch (playerCount) {
  case 2:
    return {A: 3, K: 3, Q: 3, JOKER: 1};
  case 3:
    return {A: 5, K: 5, Q: 5, JOKER: 2};
  case 4:
    return {A: 6, K: 6, Q: 6, JOKER: 2};
  case 5:
    return {A: 8, K: 8, Q: 8, JOKER: 3};
  case 6:
    return {A: 9, K: 9, Q: 9, JOKER: 3};
  default:
    throw new Error("지원하지 않는 플레이어 수입니다.");
  }
}
