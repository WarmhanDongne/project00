/* eslint-disable valid-jsdoc, max-len, require-jsdoc */

import {
  HoldemPositions,
  HoldemSeatPlayer,
} from "./types.js";

/** 직전 딜러 좌석 다음의 생존 좌석부터 새 버튼과 블라인드를 배정합니다. */
export function nextHoldemPositions(
  players: HoldemSeatPlayer[],
  previousDealerSeat: number | null,
): HoldemPositions {
  const ordered = eligiblePlayers(players);
  if (ordered.length < 2) {
    throw new Error("홀덤 포지션에는 칩이 있는 플레이어가 2명 이상 필요합니다.");
  }
  const dealer = previousDealerSeat === null ?
    ordered[0] :
    nextAfterSeat(ordered, previousDealerSeat);

  if (ordered.length === 2) {
    const bigBlind = nextAfterSeat(ordered, dealer.seatIndex);
    return {
      dealerUid: dealer.uid,
      smallBlindUid: dealer.uid,
      bigBlindUid: bigBlind.uid,
      preflopFirstUid: dealer.uid,
      postflopFirstUid: bigBlind.uid,
    };
  }

  const smallBlind = nextAfterSeat(ordered, dealer.seatIndex);
  const bigBlind = nextAfterSeat(ordered, smallBlind.seatIndex);
  return {
    dealerUid: dealer.uid,
    smallBlindUid: smallBlind.uid,
    bigBlindUid: bigBlind.uid,
    preflopFirstUid: nextAfterSeat(ordered, bigBlind.seatIndex).uid,
    postflopFirstUid: nextAfterSeat(ordered, dealer.seatIndex).uid,
  };
}

/** 현재 좌석 뒤에서 조건을 만족하는 첫 플레이어 UID를 반환합니다. */
export function nextHoldemUid(
  players: HoldemSeatPlayer[],
  currentSeat: number,
  predicate: (player: HoldemSeatPlayer) => boolean,
): string | null {
  const ordered = [...players].sort((left, right) => left.seatIndex - right.seatIndex);
  for (const player of rotateAfterSeat(ordered, currentSeat)) {
    if (predicate(player)) return player.uid;
  }
  return null;
}

function eligiblePlayers(players: HoldemSeatPlayer[]): HoldemSeatPlayer[] {
  const eligible = players
    .filter((player) => player.stack > 0 && player.status !== "eliminated")
    .sort((left, right) => left.seatIndex - right.seatIndex);
  const seats = new Set(eligible.map((player) => player.seatIndex));
  const uids = new Set(eligible.map((player) => player.uid));
  if (seats.size !== eligible.length || uids.size !== eligible.length) {
    throw new Error("홀덤 플레이어 UID 또는 좌석이 중복되었습니다.");
  }
  return eligible;
}

function nextAfterSeat(
  ordered: HoldemSeatPlayer[],
  seatIndex: number,
): HoldemSeatPlayer {
  return rotateAfterSeat(ordered, seatIndex)[0];
}

function rotateAfterSeat(
  ordered: HoldemSeatPlayer[],
  seatIndex: number,
): HoldemSeatPlayer[] {
  return [
    ...ordered.filter((player) => player.seatIndex > seatIndex),
    ...ordered.filter((player) => player.seatIndex <= seatIndex),
  ];
}
