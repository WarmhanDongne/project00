/* eslint-disable valid-jsdoc, max-len, require-jsdoc */

import {
  HoldemAction,
  HoldemBetPlayer,
  HoldemBettingRound,
  HoldemLegalActions,
} from "./types.js";
import {nextHoldemUid} from "./table.js";

type InitialBetPlayer = Omit<
  HoldemBetPlayer,
  "hasActed" | "lastActionCurrentBet" | "lastActionKind"
>;

/** 블라인드 등 현재 투입액을 포함한 새 베팅 라운드를 만듭니다. */
export function createHoldemBettingRound(
  players: InitialBetPlayer[],
  currentBet: number,
  minimumRaise: number,
  turnUid: string,
): HoldemBettingRound {
  assertChipAmount(currentBet, "현재 베팅");
  assertPositiveChipAmount(minimumRaise, "최소 레이즈");
  const uids = new Set<string>();
  const seats = new Set<number>();
  const entries = players.map((player) => {
    assertPlayer(player);
    if (uids.has(player.uid) || seats.has(player.seatIndex)) {
      throw new Error("베팅 플레이어 UID 또는 좌석이 중복되었습니다.");
    }
    uids.add(player.uid);
    seats.add(player.seatIndex);
    return [player.uid, {
      ...player,
      hasActed: false,
      lastActionCurrentBet: 0,
      lastActionKind: "none" as const,
    }];
  });
  const round: HoldemBettingRound = {
    currentBet,
    minimumRaise,
    turnUid,
    players: Object.fromEntries(entries),
  };
  if (round.players[turnUid]?.status !== "active") {
    throw new Error("첫 행동 플레이어가 베팅 가능한 상태가 아닙니다.");
  }
  return round;
}

/** 현재 플레이어가 선택할 수 있는 행동과 금액 범위를 계산합니다. */
export function legalHoldemActions(
  round: HoldemBettingRound,
  uid: string,
): HoldemLegalActions {
  const player = requireTurnPlayer(round, uid);
  const toCall = Math.max(0, round.currentBet - player.streetContribution);
  const maximumTarget = player.streetContribution + player.stack;
  const canRaise = holdemRaiseIsOpen(round, player);
  const openingTarget = round.currentBet < round.minimumRaise ?
    round.minimumRaise :
    round.currentBet + round.minimumRaise;
  const canReachMinimum = maximumTarget >= openingTarget;

  return {
    fold: true,
    check: toCall === 0,
    call: toCall > 0,
    bet: round.currentBet === 0 && canRaise && canReachMinimum,
    raise: round.currentBet > 0 && canRaise && canReachMinimum,
    allIn: player.stack > 0 &&
      (maximumTarget <= round.currentBet || canRaise),
    toCall,
    callAmount: Math.min(toCall, player.stack),
    minimumTarget: canRaise && canReachMinimum ? openingTarget : null,
    maximumTarget,
  };
}

/**
 * 행동을 적용한 새 베팅 상태를 반환합니다.
 *
 * bet/raise의 targetContribution은 이번 스트리트의 목표 누적 투입액입니다.
 */
export function applyHoldemAction(
  round: HoldemBettingRound,
  uid: string,
  action: HoldemAction,
): HoldemBettingRound {
  const next = cloneRound(round);
  const player = requireTurnPlayer(next, uid);
  const legal = legalHoldemActions(next, uid);

  switch (action.kind) {
  case "fold":
    player.status = "folded";
    player.hasActed = true;
    break;
  case "check":
    if (!legal.check) throw new Error("콜할 금액이 있어 체크할 수 없습니다.");
    rememberAction(player, "check", next.currentBet);
    break;
  case "call":
    if (!legal.call) throw new Error("콜할 금액이 없습니다.");
    commitChips(player, legal.callAmount);
    rememberAction(player, "call", next.currentBet);
    break;
  case "bet":
    if (!legal.bet) throw new Error("현재 베팅을 시작할 수 없습니다.");
    applyTarget(next, player, action.targetContribution, "bet", false);
    break;
  case "raise":
    if (!legal.raise) throw new Error("현재 레이즈할 수 없습니다.");
    applyTarget(next, player, action.targetContribution, "raise", false);
    break;
  case "allIn":
    if (!legal.allIn) throw new Error("현재 올인으로 베팅을 늘릴 수 없습니다.");
    applyTarget(next, player, legal.maximumTarget, "allIn", true);
    break;
  }

  if (player.stack === 0 && player.status === "active") {
    player.status = "allIn";
  }
  next.turnUid = nextTurnUid(next, player.seatIndex);
  return next;
}

/** short all-in 누적액이 full raise에 도달해야 이미 행동한 사람의 raise가 다시 열립니다. */
export function holdemRaiseIsOpen(
  round: HoldemBettingRound,
  player: HoldemBetPlayer,
): boolean {
  if (!player.hasActed || player.lastActionKind === "check") return true;
  return round.currentBet - player.lastActionCurrentBet >= round.minimumRaise;
}

/** 모든 베팅 가능한 플레이어가 행동하고 현재 금액을 맞췄는지 확인합니다. */
export function holdemBettingRoundComplete(round: HoldemBettingRound): boolean {
  const contenders = Object.values(round.players).filter(
    (player) => player.status !== "folded" && player.status !== "eliminated",
  );
  if (contenders.length <= 1) return true;
  return contenders.every((player) =>
    player.status === "allIn" ||
    (player.hasActed && player.streetContribution === round.currentBet),
  );
}

function applyTarget(
  round: HoldemBettingRound,
  player: HoldemBetPlayer,
  target: number,
  kind: "bet" | "raise" | "allIn",
  allowShortAllIn: boolean,
): void {
  assertChipAmount(target, "목표 베팅");
  const maximum = player.streetContribution + player.stack;
  if (target <= player.streetContribution || target > maximum) {
    throw new Error("목표 베팅 금액이 보유 칩 범위를 벗어났습니다.");
  }

  const previousBet = round.currentBet;
  if (kind === "bet" && previousBet !== 0) {
    throw new Error("이미 베팅이 있어 bet을 사용할 수 없습니다.");
  }
  if (kind === "raise" && target <= previousBet) {
    throw new Error("레이즈는 현재 베팅보다 커야 합니다.");
  }

  if (target > previousBet) {
    const raiseSize = target - previousBet;
    const completesShortOpening = previousBet < round.minimumRaise &&
      target >= round.minimumRaise;
    if (
      raiseSize < round.minimumRaise &&
      !completesShortOpening &&
      !allowShortAllIn
    ) {
      throw new Error("최소 레이즈 금액보다 작습니다.");
    }
    if (
      raiseSize < round.minimumRaise &&
      !completesShortOpening &&
      target !== maximum
    ) {
      throw new Error("최소 금액 미만 베팅은 실제 올인만 허용됩니다.");
    }
    if (raiseSize >= round.minimumRaise) round.minimumRaise = raiseSize;
    round.currentBet = target;
  }

  commitChips(player, target - player.streetContribution);
  rememberAction(player, kind, round.currentBet);
}

function commitChips(player: HoldemBetPlayer, amount: number): void {
  assertChipAmount(amount, "투입 칩");
  if (amount > player.stack) throw new Error("보유 칩보다 많이 베팅할 수 없습니다.");
  player.stack -= amount;
  player.streetContribution += amount;
  player.totalContribution += amount;
}

function rememberAction(
  player: HoldemBetPlayer,
  kind: HoldemBetPlayer["lastActionKind"],
  currentBet: number,
): void {
  player.hasActed = true;
  player.lastActionKind = kind;
  player.lastActionCurrentBet = currentBet;
}

function nextTurnUid(
  round: HoldemBettingRound,
  currentSeat: number,
): string | null {
  if (holdemBettingRoundComplete(round)) return null;
  return nextHoldemUid(
    Object.values(round.players),
    currentSeat,
    (candidate) => {
      const player = round.players[candidate.uid];
      return player.status === "active" &&
        (!player.hasActed || player.streetContribution < round.currentBet);
    },
  );
}

function requireTurnPlayer(
  round: HoldemBettingRound,
  uid: string,
): HoldemBetPlayer {
  if (round.turnUid !== uid) throw new Error("현재 플레이어의 턴이 아닙니다.");
  const player = round.players[uid];
  if (!player || player.status !== "active" || player.stack <= 0) {
    throw new Error("현재 플레이어는 베팅할 수 없습니다.");
  }
  return player;
}

function cloneRound(round: HoldemBettingRound): HoldemBettingRound {
  return {
    ...round,
    players: Object.fromEntries(
      Object.entries(round.players).map(([uid, player]) => [uid, {...player}]),
    ),
  };
}

function assertPlayer(player: InitialBetPlayer): void {
  assertChipAmount(player.stack, "보유 칩");
  assertChipAmount(player.streetContribution, "스트리트 투입액");
  assertChipAmount(player.totalContribution, "전체 투입액");
  if (!Number.isInteger(player.seatIndex) || player.seatIndex < 0) {
    throw new Error("좌석 번호가 올바르지 않습니다.");
  }
  if (player.streetContribution > player.totalContribution) {
    throw new Error("스트리트 투입액이 전체 투입액보다 클 수 없습니다.");
  }
}

function assertChipAmount(value: number, label: string): void {
  if (!Number.isSafeInteger(value) || value < 0) {
    throw new Error(`${label}은 0 이상의 안전한 정수여야 합니다.`);
  }
}

function assertPositiveChipAmount(value: number, label: string): void {
  if (!Number.isSafeInteger(value) || value <= 0) {
    throw new Error(`${label}은 1 이상의 안전한 정수여야 합니다.`);
  }
}
