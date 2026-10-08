/* eslint-disable valid-jsdoc */

import {randomInt} from "node:crypto";

import {
  HOLDEM_RANKS,
  HOLDEM_SUITS,
  HoldemCard,
} from "./types.js";

type NextInt = (maxExclusive: number) => number;

/** 표준 52장 덱을 만들고 Fisher-Yates 방식으로 섞습니다. */
export function createHoldemDeck(nextInt: NextInt = randomInt): HoldemCard[] {
  const deck: HoldemCard[] = [];
  for (const suit of HOLDEM_SUITS) {
    for (const rank of HOLDEM_RANKS) {
      deck.push({id: `${rank}_${suit}`, suit, rank});
    }
  }

  for (let index = deck.length - 1; index > 0; index -= 1) {
    const swapIndex = nextInt(index + 1);
    if (!Number.isInteger(swapIndex) || swapIndex < 0 || swapIndex > index) {
      throw new Error("덱 셔플 난수 범위가 올바르지 않습니다.");
    }
    [deck[index], deck[swapIndex]] = [deck[swapIndex], deck[index]];
  }
  return deck;
}
