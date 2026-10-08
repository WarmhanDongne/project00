/* eslint-disable valid-jsdoc, max-len, require-jsdoc */

import {compareHoldemHands} from "./hand-evaluator.js";
import {
  HoldemHandValue,
  HoldemPot,
  HoldemPotBuildResult,
  HoldemPotContribution,
  HoldemSettlement,
} from "./types.js";

/** 플레이어별 전체 투입액으로 메인·사이드 팟과 콜되지 않은 환급액을 만듭니다. */
export function buildHoldemPots(
  contributions: HoldemPotContribution[],
): HoldemPotBuildResult {
  assertContributions(contributions);
  const levels = [...new Set(
    contributions.filter((entry) => entry.amount > 0).map((entry) => entry.amount),
  )].sort((left, right) => left - right);
  const pots: HoldemPot[] = [];
  const refunds: Record<string, number> = {};
  let previousLevel = 0;

  for (const level of levels) {
    const contributors = contributions.filter((entry) => entry.amount >= level);
    const layerAmount = (level - previousLevel) * contributors.length;
    if (contributors.length === 1) {
      const uid = contributors[0].uid;
      refunds[uid] = (refunds[uid] ?? 0) + layerAmount;
    } else {
      pots.push({
        amount: layerAmount,
        cap: level,
        contributorUids: contributors.map((entry) => entry.uid),
        eligibleUids: contributors
          .filter((entry) => !entry.folded)
          .map((entry) => entry.uid),
      });
    }
    previousLevel = level;
  }
  return {pots, refunds};
}

/** 각 팟의 승자를 판정하고 딜러 다음 좌석부터 홀수 칩을 배분합니다. */
export function settleHoldemPots(
  pots: HoldemPot[],
  hands: Record<string, HoldemHandValue>,
  seats: Record<string, number>,
  dealerSeat: number,
): HoldemSettlement {
  const awards: Record<string, number> = {};
  const resolved = pots.map((pot, potIndex) => {
    if (!Number.isSafeInteger(pot.amount) || pot.amount <= 0) {
      throw new Error("팟 금액은 1 이상의 안전한 정수여야 합니다.");
    }
    const eligible = pot.eligibleUids.filter((uid) => hands[uid] !== undefined);
    if (eligible.length === 0) throw new Error("팟을 받을 수 있는 플레이어가 없습니다.");
    let winners = [eligible[0]];
    for (const uid of eligible.slice(1)) {
      const comparison = compareHoldemHands(hands[uid], hands[winners[0]]);
      if (comparison > 0) winners = [uid];
      else if (comparison === 0) winners.push(uid);
    }
    winners = clockwiseAfterDealer(winners, seats, dealerSeat);

    const baseShare = Math.floor(pot.amount / winners.length);
    let remainder = pot.amount % winners.length;
    const shares: Record<string, number> = {};
    for (const uid of winners) {
      const share = baseShare + (remainder > 0 ? 1 : 0);
      if (remainder > 0) remainder -= 1;
      shares[uid] = share;
      awards[uid] = (awards[uid] ?? 0) + share;
    }
    return {potIndex, amount: pot.amount, winnerUids: winners, shares};
  });
  return {awards, pots: resolved};
}

function clockwiseAfterDealer(
  uids: string[],
  seats: Record<string, number>,
  dealerSeat: number,
): string[] {
  for (const uid of uids) {
    if (!Number.isInteger(seats[uid]) || seats[uid] < 0) {
      throw new Error(`${uid}의 좌석 번호가 올바르지 않습니다.`);
    }
  }
  return [...uids].sort((left, right) => {
    const leftAfter = seats[left] > dealerSeat ? 0 : 1;
    const rightAfter = seats[right] > dealerSeat ? 0 : 1;
    return leftAfter - rightAfter || seats[left] - seats[right];
  });
}

function assertContributions(contributions: HoldemPotContribution[]): void {
  const uids = new Set<string>();
  for (const entry of contributions) {
    if (!entry.uid || uids.has(entry.uid)) {
      throw new Error("팟 기여 플레이어 UID가 없거나 중복되었습니다.");
    }
    uids.add(entry.uid);
    if (!Number.isSafeInteger(entry.amount) || entry.amount < 0) {
      throw new Error("팟 기여액은 0 이상의 안전한 정수여야 합니다.");
    }
    if (!Number.isInteger(entry.seatIndex) || entry.seatIndex < 0) {
      throw new Error("팟 기여 플레이어 좌석이 올바르지 않습니다.");
    }
  }
}
