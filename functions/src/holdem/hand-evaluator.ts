/* eslint-disable valid-jsdoc, max-len, require-jsdoc */

import {
  HOLDEM_RANKS,
  HOLDEM_SUITS,
  HoldemCard,
  HoldemHandCategory,
  HoldemHandRank,
  HoldemHandValue,
} from "./types.js";

const CATEGORY_RANK: Record<HoldemHandCategory, number> = {
  highCard: 0,
  onePair: 1,
  twoPair: 2,
  threeOfAKind: 3,
  straight: 4,
  flush: 5,
  fullHouse: 6,
  fourOfAKind: 7,
  straightFlush: 8,
};

const RANK_VALUE: Record<string, number> = Object.fromEntries(
  HOLDEM_RANKS.map((rank, index) => [rank, index + 2]),
);

/** 5~7장 중 가장 강한 5장 포커 족보를 계산합니다. */
export function evaluateHoldemHand(cards: HoldemCard[]): HoldemHandValue {
  assertValidCards(cards);
  if (cards.length < 5 || cards.length > 7) {
    throw new Error("홀덤 족보는 5~7장으로 계산해야 합니다.");
  }

  let best: HoldemHandValue | null = null;
  for (const combination of combinations(cards, 5)) {
    const candidate = evaluateFive(combination);
    if (!best || compareHoldemHands(candidate, best) > 0) best = candidate;
  }
  if (!best) throw new Error("홀덤 족보를 계산할 수 없습니다.");
  return best;
}

/**
 * 휴대폰에 보여 줄 현재 족보입니다.
 *
 * 공개 보드가 3장 미만인 프리플롭에는 홀 카드 2장만으로 페어 또는 하이 카드를
 * 표시하고, 이후에는 승패 판정과 같은 evaluator로 최선의 5장을 고릅니다.
 */
export function describeHoldemHandRank(
  hand: HoldemCard[],
  board: HoldemCard[],
): HoldemHandRank | null {
  if (hand.length !== 2) return null;
  if (board.length < 3) {
    assertValidCards(hand);
    const sorted = [...hand].sort((a, b) => rankValue(b) - rankValue(a));
    return {
      category: sorted[0].rank === sorted[1].rank ? "onePair" : "highCard",
      bestCards: sorted,
    };
  }
  const value = evaluateHoldemHand([...hand, ...board]);
  return {category: value.category, bestCards: value.bestCards};
}

/** 양수면 left, 음수면 right, 0이면 완전 동률입니다. */
export function compareHoldemHands(
  left: HoldemHandValue,
  right: HoldemHandValue,
): number {
  if (left.categoryRank !== right.categoryRank) {
    return left.categoryRank - right.categoryRank;
  }
  const length = Math.max(left.tiebreak.length, right.tiebreak.length);
  for (let index = 0; index < length; index += 1) {
    const difference = (left.tiebreak[index] ?? 0) - (right.tiebreak[index] ?? 0);
    if (difference !== 0) return difference;
  }
  return 0;
}

function evaluateFive(cards: HoldemCard[]): HoldemHandValue {
  const values = cards.map((card) => rankValue(card)).sort((a, b) => b - a);
  const counts = new Map<number, number>();
  for (const value of values) counts.set(value, (counts.get(value) ?? 0) + 1);
  const groups = [...counts.entries()].sort(
    ([leftValue, leftCount], [rightValue, rightCount]) =>
      rightCount - leftCount || rightValue - leftValue,
  );
  const flush = cards.every((card) => card.suit === cards[0].suit);
  const straight = straightHigh(values);

  if (flush && straight !== null) {
    return handValue("straightFlush", [straight], cards);
  }
  if (groups[0][1] === 4) {
    return handValue("fourOfAKind", [groups[0][0], groups[1][0]], cards);
  }
  if (groups[0][1] === 3 && groups[1][1] === 2) {
    return handValue("fullHouse", [groups[0][0], groups[1][0]], cards);
  }
  if (flush) return handValue("flush", values, cards);
  if (straight !== null) return handValue("straight", [straight], cards);
  if (groups[0][1] === 3) {
    const kickers = groups.slice(1).map(([value]) => value).sort((a, b) => b - a);
    return handValue("threeOfAKind", [groups[0][0], ...kickers], cards);
  }
  const pairs = groups.filter(([, count]) => count === 2)
    .map(([value]) => value)
    .sort((a, b) => b - a);
  if (pairs.length === 2) {
    const kicker = groups.find(([, count]) => count === 1)?.[0] ?? 0;
    return handValue("twoPair", [pairs[0], pairs[1], kicker], cards);
  }
  if (pairs.length === 1) {
    const kickers = groups
      .filter(([, count]) => count === 1)
      .map(([value]) => value)
      .sort((a, b) => b - a);
    return handValue("onePair", [pairs[0], ...kickers], cards);
  }
  return handValue("highCard", values, cards);
}

function handValue(
  category: HoldemHandCategory,
  tiebreak: number[],
  bestCards: HoldemCard[],
): HoldemHandValue {
  return {
    category,
    categoryRank: CATEGORY_RANK[category],
    tiebreak,
    bestCards: [...bestCards],
  };
}

function straightHigh(values: number[]): number | null {
  const unique = [...new Set(values)].sort((a, b) => b - a);
  if (unique.includes(14)) unique.push(1);
  for (let index = 0; index <= unique.length - 5; index += 1) {
    const high = unique[index];
    if (unique.slice(index, index + 5).every(
      (value, offset) => value === high - offset,
    )) {
      return high;
    }
  }
  return null;
}

function rankValue(card: HoldemCard): number {
  const value = RANK_VALUE[card.rank];
  if (!value) throw new Error(`지원하지 않는 카드 rank입니다: ${card.rank}`);
  return value;
}

function assertValidCards(cards: HoldemCard[]): void {
  const ids = new Set<string>();
  const faces = new Set<string>();
  for (const card of cards) {
    if (!HOLDEM_RANKS.includes(card.rank) || !HOLDEM_SUITS.includes(card.suit)) {
      throw new Error("표준 홀덤 카드가 아닙니다.");
    }
    const face = `${card.rank}_${card.suit}`;
    if (ids.has(card.id) || faces.has(face)) {
      throw new Error("중복 카드가 있습니다.");
    }
    ids.add(card.id);
    faces.add(face);
  }
}

function combinations<T>(items: T[], count: number): T[][] {
  const result: T[][] = [];
  const visit = (start: number, selected: T[]): void => {
    if (selected.length === count) {
      result.push([...selected]);
      return;
    }
    for (
      let index = start;
      index <= items.length - (count - selected.length);
      index += 1
    ) {
      selected.push(items[index]);
      visit(index + 1, selected);
      selected.pop();
    }
  };
  visit(0, []);
  return result;
}
