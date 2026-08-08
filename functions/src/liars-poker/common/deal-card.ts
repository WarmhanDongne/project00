/* eslint-disable valid-jsdoc */

import {GameCard, PublicGamePlayer} from "./types.js";

/** 좌석 순서대로 생존 플레이어에게 카드를 분배합니다. */
export function dealCards(
  deck: GameCard[],
  players: Record<string, PublicGamePlayer>,
  cardsPerPlayer: number,
): Record<string, Record<string, GameCard>> {
  const hands: Record<string, Record<string, GameCard>> = {};
  const activePlayers = Object.values(players)
    .filter((player) => player.status === "alive")
    .sort((a, b) => a.seatIndex - b.seatIndex);
  let deckIndex = 0;

  for (const player of activePlayers) {
    const hand: Record<string, GameCard> = {};
    for (let index = 0; index < cardsPerPlayer; index += 1) {
      const card = deck[deckIndex];
      if (!card) throw new Error("덱의 카드가 부족합니다.");
      hand[card.id] = card;
      deckIndex += 1;
    }
    hands[player.uid] = hand;
  }
  return hands;
}
