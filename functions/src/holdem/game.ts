/* eslint-disable valid-jsdoc, max-len, require-jsdoc */

import {
  HOLDEM_ACTION_MS,
  HOLDEM_STARTING_CHIPS,
  holdemBlindsForHand,
  holdemTimeoutAction,
} from "./config.js";
import {
  applyHoldemAction,
  createHoldemBettingRound,
  holdemBettingRoundComplete,
  legalHoldemActions,
} from "./betting.js";
import {createHoldemDeck} from "./deck.js";
import {describeHoldemHandRank, evaluateHoldemHand} from "./hand-evaluator.js";
import {buildHoldemPots, settleHoldemPots} from "./pots.js";
import {nextHoldemPositions, nextHoldemUid} from "./table.js";
import {
  HoldemAction,
  HoldemBetPlayer,
  HoldemCard,
  HoldemGameState,
  HoldemHandValue,
  HoldemPublicPlayer,
} from "./types.js";

export type HoldemStartPlayer = {
  uid: string;
  nickname: string;
  characterId: string;
  seatIndex: number;
};

/** 새 토너먼트를 만들고 첫 핸드를 배분 대기 상태로 준비합니다. */
export function createHoldemGame(
  players: HoldemStartPlayer[],
  now: number,
  deckFactory: () => HoldemCard[] = createHoldemDeck,
): HoldemGameState {
  assertStartPlayers(players);
  const publicPlayers = Object.fromEntries(players.map((player) => [
    player.uid,
    {
      ...player,
      stack: HOLDEM_STARTING_CHIPS,
      status: "alive" as const,
      handStatus: "active" as const,
      streetContribution: 0,
      totalContribution: 0,
    },
  ]));
  const placeholder = createHoldemBettingRound(
    players.map((player) => ({
      uid: player.uid,
      seatIndex: player.seatIndex,
      stack: HOLDEM_STARTING_CHIPS,
      status: "active" as const,
      streetContribution: 0,
      totalContribution: 0,
    })),
    0,
    1,
    players[0].uid,
  );
  const game: HoldemGameState = {
    public: {
      gameType: "holdem",
      status: "playing",
      phase: "dealing",
      handNumber: 0,
      revision: 0,
      dealerUid: players[0].uid,
      smallBlindUid: players[0].uid,
      bigBlindUid: players[1].uid,
      smallBlind: 0,
      bigBlind: 0,
      communityCards: [],
      pots: [],
      potTotal: 0,
      turnUid: null,
      turnDeadlineAt: null,
      currentBet: 0,
      minimumRaise: 1,
      lastAction: null,
      result: null,
      winnerUid: null,
      players: publicPlayers,
      startedAt: now,
      updatedAt: now,
    },
    private: {},
    server: {
      deck: [],
      deckIndex: 0,
      betting: placeholder,
      processedCommands: {},
      previousDealerSeat: null,
    },
  };
  startNextHoldemHand(game, now, deckFactory);
  return game;
}

/** 태블릿 배분 연출이 끝난 뒤 첫 행동을 엽니다. */
export function completeHoldemDealing(
  game: HoldemGameState,
  now: number,
): Record<string, unknown> {
  requirePlaying(game);
  if (game.public.phase !== "dealing") {
    return {
      success: true,
      type: "dealingAlreadyCompleted",
      revision: game.public.revision,
    };
  }
  game.public.phase = "preflop";
  game.public.turnUid = game.server.betting.turnUid;
  if (game.public.turnUid === null) {
    runBoardToResult(game, now);
  } else {
    game.public.turnDeadlineAt = now + HOLDEM_ACTION_MS;
    refreshPrivateActions(game);
    touch(game, now);
  }
  return {
    success: true,
    type: "dealingCompleted",
    revision: game.public.revision,
    turnUid: game.public.turnUid,
  };
}

/** 현재 플레이어 행동을 적용하고 필요하면 다음 스트리트나 결과로 이동합니다. */
export function actInHoldemGame(
  game: HoldemGameState,
  uid: string,
  action: HoldemAction,
  now: number,
): Record<string, unknown> {
  requireBettingPhase(game);
  if (game.public.turnUid !== uid) throw new Error("현재 플레이어의 턴이 아닙니다.");
  const before = game.server.betting.players[uid];
  if (!before) throw new Error("홀덤 플레이어를 찾을 수 없습니다.");
  const beforeContribution = before.streetContribution;
  const nextBetting = applyHoldemAction(game.server.betting, uid, action);
  game.server.betting = nextBetting;
  syncPlayersFromBetting(game);
  game.public.lastAction = {
    uid,
    kind: action.kind,
    amount: nextBetting.players[uid].streetContribution - beforeContribution,
    createdAt: now,
  };
  game.public.turnUid = nextBetting.turnUid;
  game.public.turnDeadlineAt = nextBetting.turnUid === null ? null : now + HOLDEM_ACTION_MS;
  refreshPublicBets(game);

  if (contenderUids(game).length <= 1) {
    finishByFold(game, now);
  } else if (holdemBettingRoundComplete(nextBetting)) {
    advanceAfterBetting(game, now);
  } else {
    refreshPrivateActions(game);
    touch(game, now);
  }
  return {
    success: true,
    type: "actionApplied",
    action: action.kind,
    phase: game.public.phase,
    revision: game.public.revision,
    turnUid: game.public.turnUid,
  };
}

/** 서버 마감 뒤 체크 또는 폴드를 적용합니다. */
export function timeoutHoldemTurn(
  game: HoldemGameState,
  now: number,
): Record<string, unknown> {
  if (!isBettingPhase(game.public.phase) || game.public.status !== "playing") {
    return {success: true, ignored: true, phase: game.public.phase};
  }
  const uid = game.public.turnUid;
  const deadline = game.public.turnDeadlineAt;
  if (!uid || deadline === null) return {success: true, ignored: true};
  if (now < deadline) {
    return {success: false, reason: "notExpired", turnDeadlineAt: deadline};
  }
  const legal = legalHoldemActions(game.server.betting, uid);
  const action = holdemTimeoutAction(legal.check);
  return actInHoldemGame(game, uid, {kind: action}, now);
}

/** 결과 연출 뒤 다음 핸드를 만들거나 토너먼트를 종료합니다. */
export function completeHoldemResult(
  game: HoldemGameState,
  now: number,
  deckFactory: () => HoldemCard[] = createHoldemDeck,
): Record<string, unknown> {
  requirePlaying(game);
  if (game.public.phase !== "handResult") {
    if (game.public.phase === "dealing") {
      return {success: true, type: "resultAlreadyCompleted", revision: game.public.revision};
    }
    throw new Error("핸드 결과를 완료할 수 있는 단계가 아닙니다.");
  }
  const survivors = Object.values(game.public.players).filter((player) => player.stack > 0);
  if (survivors.length <= 1) {
    finishTournament(game, survivors[0]?.uid ?? null, now, "winner");
    return {success: true, type: "tournamentFinished", winnerUid: game.public.winnerUid, revision: game.public.revision};
  }
  startNextHoldemHand(game, now, deckFactory);
  return {success: true, type: "nextHand", handNumber: game.public.handNumber, revision: game.public.revision};
}

/** 진행자가 현재 게임을 수동 종료합니다. */
export function endHoldemGame(game: HoldemGameState, now: number): void {
  finishTournament(game, null, now, "manual");
}

/** 중단 처리에서 참가자를 제외하고 남은 상태를 안전하게 이어 갑니다. */
export function excludeHoldemPlayer(
  game: HoldemGameState,
  uid: string,
  now: number,
): void {
  const player = game.public.players[uid];
  if (!player || player.status === "eliminated") return;
  player.status = "eliminated";
  player.handStatus = "eliminated";
  player.stack = 0;
  delete game.private[uid];
  const betPlayer = game.server.betting.players[uid];
  if (betPlayer) {
    betPlayer.status = "eliminated";
    betPlayer.stack = 0;
  }
  const survivors = Object.values(game.public.players).filter((entry) => entry.stack > 0 && entry.status !== "eliminated");
  if (survivors.length < 2) {
    finishTournament(game, null, now, "insufficientPlayers");
    return;
  }
  if (game.public.phase === "dealing") {
    game.server.betting.turnUid = firstActiveUid(game.server.betting, game.server.betting.turnUid);
    game.public.turnUid = null;
    touch(game, now);
    return;
  }
  if (isBettingPhase(game.public.phase)) {
    if (contenderUids(game).length <= 1) {
      finishByFold(game, now);
    } else if (holdemBettingRoundComplete(game.server.betting)) {
      advanceAfterBetting(game, now);
    } else if (game.public.turnUid === uid) {
      game.server.betting.turnUid = firstActiveUid(game.server.betting, uid);
      game.public.turnUid = game.server.betting.turnUid;
      game.public.turnDeadlineAt = game.public.turnUid === null ? null : now + HOLDEM_ACTION_MS;
      if (game.public.turnUid === null) advanceAfterBetting(game, now);
      else {
        refreshPrivateActions(game);
        touch(game, now);
      }
    } else {
      refreshPrivateActions(game);
      touch(game, now);
    }
  }
}

/** 인원 부족 중단을 공용 종료 흐름에서 호출합니다. */
export function finishHoldemForInsufficientPlayers(
  game: HoldemGameState,
  now: number,
): void {
  finishTournament(game, null, now, "insufficientPlayers");
}

function startNextHoldemHand(
  game: HoldemGameState,
  now: number,
  deckFactory: () => HoldemCard[],
): void {
  game.public.handNumber += 1;
  const handNumber = game.public.handNumber;
  const blinds = holdemBlindsForHand(handNumber);
  for (const player of Object.values(game.public.players)) {
    player.status = player.stack > 0 ? "alive" : "eliminated";
    player.handStatus = player.stack > 0 ? "active" : "eliminated";
    player.streetContribution = 0;
    player.totalContribution = 0;
  }
  const positions = nextHoldemPositions(
    Object.values(game.public.players).map((player) => ({
      uid: player.uid,
      seatIndex: player.seatIndex,
      stack: player.stack,
      status: player.handStatus,
    })),
    game.server.previousDealerSeat,
  );
  const dealer = game.public.players[positions.dealerUid];
  game.server.previousDealerSeat = dealer.seatIndex;
  game.public.dealerUid = positions.dealerUid;
  game.public.smallBlindUid = positions.smallBlindUid;
  game.public.bigBlindUid = positions.bigBlindUid;
  game.public.smallBlind = blinds.smallBlind;
  game.public.bigBlind = blinds.bigBlind;
  game.public.communityCards = [];
  game.public.pots = [];
  game.public.potTotal = 0;
  game.public.lastAction = null;
  game.public.result = null;
  game.public.winnerUid = null;
  game.public.phase = "dealing";
  game.public.turnUid = null;
  game.public.turnDeadlineAt = null;

  const deck = deckFactory();
  if (deck.length !== 52 || new Set(deck.map((card) => card.id)).size !== 52) {
    throw new Error("홀덤 덱은 서로 다른 52장이어야 합니다.");
  }
  game.server.deck = deck;
  game.server.deckIndex = 0;
  game.private = {};
  const ordered = orderedAfterSeat(
    Object.values(game.public.players).filter((player) => player.stack > 0),
    dealer.seatIndex,
  );
  for (const player of ordered) game.private[player.uid] = {hand: [], legalActions: null};
  for (let pass = 0; pass < 2; pass += 1) {
    for (const player of ordered) game.private[player.uid].hand.push(draw(game));
  }

  const initialPlayers = Object.values(game.public.players).map((player) => ({
    uid: player.uid,
    seatIndex: player.seatIndex,
    stack: player.stack,
    status: player.handStatus,
    streetContribution: 0,
    totalContribution: 0,
  }));
  postBlind(initialPlayers, positions.smallBlindUid, blinds.smallBlind);
  postBlind(initialPlayers, positions.bigBlindUid, blinds.bigBlind);
  const currentBet = Math.max(...initialPlayers.map((player) => player.streetContribution));
  const first = firstAvailableFromUid(initialPlayers, positions.preflopFirstUid);
  const fallback = initialPlayers.find((player) => player.status === "active")?.uid;
  const firstUid = first ?? fallback;
  if (!firstUid) {
    // createHoldemBettingRound requires an active turn. Keep a stable placeholder;
    // completeDealing will run the board immediately.
    const placeholder = initialPlayers.find((player) => player.stack >= 0)!;
    const actualStack = placeholder.stack;
    const actualStatus = placeholder.status;
    placeholder.status = "active";
    placeholder.stack = Math.max(actualStack, 1);
    game.server.betting = createHoldemBettingRound(initialPlayers, currentBet, blinds.bigBlind, placeholder.uid);
    game.server.betting.players[placeholder.uid].status = actualStatus;
    game.server.betting.players[placeholder.uid].stack = actualStack;
    game.server.betting.turnUid = null;
  } else {
    game.server.betting = createHoldemBettingRound(initialPlayers, currentBet, blinds.bigBlind, firstUid);
  }
  syncPlayersFromBetting(game);
  refreshPublicBets(game);
  refreshPrivateActions(game);
  touch(game, now);
}

function advanceAfterBetting(game: HoldemGameState, now: number): void {
  if (game.public.phase === "river") {
    finishShowdown(game, now);
    return;
  }
  const phase = game.public.phase;
  revealNextStreet(game);
  resetStreetBetting(game);
  const activeCount = Object.values(game.server.betting.players).filter((player) => player.status === "active").length;
  if (activeCount <= 1) {
    runBoardToResult(game, now);
    return;
  }
  const preferred = postflopFirstUid(game);
  game.server.betting.turnUid = firstActiveUid(game.server.betting, preferred);
  game.public.turnUid = game.server.betting.turnUid;
  game.public.turnDeadlineAt = game.public.turnUid === null ? null : now + HOLDEM_ACTION_MS;
  refreshPublicBets(game);
  refreshPrivateActions(game);
  if (phase === game.public.phase) throw new Error("홀덤 스트리트가 진행되지 않았습니다.");
  touch(game, now);
}

function runBoardToResult(game: HoldemGameState, now: number): void {
  while (game.public.phase !== "river") revealNextStreet(game);
  finishShowdown(game, now);
}

function revealNextStreet(game: HoldemGameState): void {
  // RTDB는 빈 배열을 저장하지 않아 프리플롭의 communityCards 키가
  // 재조회 시 사라질 수 있습니다. 첫 공개 전에 보드를 복원합니다.
  game.public.communityCards ??= [];
  draw(game); // burn
  switch (game.public.phase) {
  case "dealing":
  case "preflop":
    game.public.communityCards.push(draw(game), draw(game), draw(game));
    game.public.phase = "flop";
    break;
  case "flop":
    game.public.communityCards.push(draw(game));
    game.public.phase = "turn";
    break;
  case "turn":
    game.public.communityCards.push(draw(game));
    game.public.phase = "river";
    break;
  default:
    throw new Error("현재 단계에서는 카드를 공개할 수 없습니다.");
  }
}

function resetStreetBetting(game: HoldemGameState): void {
  for (const player of Object.values(game.server.betting.players)) {
    player.streetContribution = 0;
    player.hasActed = false;
    player.lastActionCurrentBet = 0;
    player.lastActionKind = "none";
  }
  game.server.betting.currentBet = 0;
  game.server.betting.minimumRaise = game.public.bigBlind;
  game.server.betting.turnUid = null;
  syncPlayersFromBetting(game);
}

function finishByFold(game: HoldemGameState, now: number): void {
  const winnerUid = contenderUids(game)[0];
  if (!winnerUid) throw new Error("폴드 승자를 찾을 수 없습니다.");
  const total = Object.values(game.server.betting.players).reduce((sum, player) => sum + player.totalContribution, 0);
  game.server.betting.players[winnerUid].stack += total;
  const awards = {[winnerUid]: total};
  finishHand(game, now, {
    reason: "fold",
    winnerUids: [winnerUid],
    awards,
    revealedHands: {},
    handCategories: {},
  });
}

function finishShowdown(game: HoldemGameState, now: number): void {
  const bettingPlayers = Object.values(game.server.betting.players);
  const contributions = bettingPlayers.map((player) => ({
    uid: player.uid,
    seatIndex: player.seatIndex,
    amount: player.totalContribution,
    folded: player.status === "folded" || player.status === "eliminated",
  }));
  const built = buildHoldemPots(contributions);
  for (const [uid, refund] of Object.entries(built.refunds)) {
    game.server.betting.players[uid].stack += refund;
  }
  const hands: Record<string, HoldemHandValue> = {};
  const revealedHands: Record<string, HoldemCard[]> = {};
  for (const player of bettingPlayers) {
    if (player.status === "folded" || player.status === "eliminated") continue;
    const hand = game.private[player.uid]?.hand;
    if (!hand || hand.length !== 2) throw new Error("쇼다운 홀 카드가 없습니다.");
    hands[player.uid] = evaluateHoldemHand([...hand, ...game.public.communityCards]);
    revealedHands[player.uid] = [...hand];
  }
  const seats = Object.fromEntries(bettingPlayers.map((player) => [player.uid, player.seatIndex]));
  const dealerSeat = game.public.players[game.public.dealerUid].seatIndex;
  const settlement = settleHoldemPots(built.pots, hands, seats, dealerSeat);
  for (const [uid, award] of Object.entries(settlement.awards)) {
    game.server.betting.players[uid].stack += award;
  }
  finishHand(game, now, {
    reason: "showdown",
    winnerUids: [...new Set(settlement.pots.flatMap((pot) => pot.winnerUids))],
    awards: settlement.awards,
    revealedHands,
    handCategories: Object.fromEntries(Object.entries(hands).map(([uid, value]) => [uid, value.category])),
    bestCards: Object.fromEntries(Object.entries(hands).map(([uid, value]) => [uid, value.bestCards])),
  });
}

function finishHand(game: HoldemGameState, now: number, result: HoldemGameState["public"]["result"]): void {
  if (!result) throw new Error("핸드 결과가 없습니다.");
  syncPlayersFromBetting(game);
  for (const player of Object.values(game.public.players)) {
    if (player.stack === 0) {
      player.status = "eliminated";
      player.handStatus = "eliminated";
    }
  }
  game.public.phase = "handResult";
  game.public.turnUid = null;
  game.public.turnDeadlineAt = null;
  game.public.result = result;
  game.public.pots = result.awards ? Object.entries(result.awards).map(([uid, amount]) => ({amount, eligibleUids: [uid]})) : [];
  game.public.potTotal = Object.values(result.awards).reduce((sum, amount) => sum + amount, 0);
  for (const privateState of Object.values(game.private)) privateState.legalActions = null;
  refreshPrivateHandRanks(game);
  touch(game, now);
}

function finishTournament(game: HoldemGameState, winnerUid: string | null, now: number, reason: NonNullable<HoldemGameState["public"]["finishReason"]>): void {
  game.public.status = "finished";
  game.public.phase = "finished";
  game.public.finishReason = reason;
  game.public.winnerUid = winnerUid;
  game.public.turnUid = null;
  game.public.turnDeadlineAt = null;
  game.public.finishedAt = now;
  game.private = {};
  delete game.public.interruption;
  delete game.server.interruption;
  touch(game, now);
}

function refreshPublicBets(game: HoldemGameState): void {
  const entries = Object.values(game.server.betting.players);
  const built = buildHoldemPots(entries.map((player) => ({
    uid: player.uid,
    seatIndex: player.seatIndex,
    amount: player.totalContribution,
    folded: player.status === "folded" || player.status === "eliminated",
  })));
  game.public.currentBet = game.server.betting.currentBet;
  game.public.minimumRaise = game.server.betting.minimumRaise;
  game.public.pots = built.pots.map((pot) => ({amount: pot.amount, eligibleUids: pot.eligibleUids}));
  game.public.potTotal = entries.reduce((sum, player) => sum + player.totalContribution, 0);
}

function refreshPrivateActions(game: HoldemGameState): void {
  for (const [uid, privateState] of Object.entries(game.private)) {
    privateState.legalActions = game.public.turnUid === uid && isBettingPhase(game.public.phase) ?
      legalHoldemActions(game.server.betting, uid) : null;
  }
  refreshPrivateHandRanks(game);
}

function refreshPrivateHandRanks(game: HoldemGameState): void {
  const board = game.public.communityCards ?? [];
  for (const privateState of Object.values(game.private)) {
    privateState.handRank = describeHoldemHandRank(privateState.hand, board);
  }
}

function syncPlayersFromBetting(game: HoldemGameState): void {
  for (const [uid, betPlayer] of Object.entries(game.server.betting.players)) {
    const player = game.public.players[uid];
    if (!player) continue;
    player.stack = betPlayer.stack;
    player.handStatus = betPlayer.status;
    // 올인은 칩이 0이어도 쇼다운 결과 전까지 살아 있는 참가자입니다.
    // 공용 중단 처리에서 투표권·복귀 대상으로 유지되도록 handStatus와 분리합니다.
    player.status = betPlayer.status === "eliminated" ? "eliminated" : "alive";
    player.streetContribution = betPlayer.streetContribution;
    player.totalContribution = betPlayer.totalContribution;
  }
}

function postBlind(players: Array<Omit<HoldemBetPlayer, "hasActed" | "lastActionCurrentBet" | "lastActionKind">>, uid: string, amount: number): void {
  const player = players.find((entry) => entry.uid === uid);
  if (!player) throw new Error("블라인드 플레이어를 찾을 수 없습니다.");
  const paid = Math.min(player.stack, amount);
  player.stack -= paid;
  player.streetContribution += paid;
  player.totalContribution += paid;
  if (player.stack === 0) player.status = "allIn";
}

function postflopFirstUid(game: HoldemGameState): string {
  const dealerSeat = game.public.players[game.public.dealerUid].seatIndex;
  return nextHoldemUid(
    Object.values(game.server.betting.players),
    dealerSeat,
    (player) => game.server.betting.players[player.uid].status === "active",
  ) ?? game.public.dealerUid;
}

function firstAvailableFromUid(players: Array<Omit<HoldemBetPlayer, "hasActed" | "lastActionCurrentBet" | "lastActionKind">>, preferredUid: string): string | null {
  const preferred = players.find((player) => player.uid === preferredUid);
  if (preferred?.status === "active") return preferredUid;
  const seat = preferred?.seatIndex ?? -1;
  return nextHoldemUid(players, seat, (player) => player.status === "active");
}

function firstActiveUid(round: HoldemGameState["server"]["betting"], preferredUid: string | null): string | null {
  if (preferredUid && round.players[preferredUid]?.status === "active") return preferredUid;
  const seat = preferredUid ? round.players[preferredUid]?.seatIndex ?? -1 : -1;
  return nextHoldemUid(Object.values(round.players), seat, (player) => round.players[player.uid].status === "active");
}

function contenderUids(game: HoldemGameState): string[] {
  return Object.values(game.server.betting.players)
    .filter((player) => player.status !== "folded" && player.status !== "eliminated")
    .map((player) => player.uid);
}

function orderedAfterSeat(players: HoldemPublicPlayer[], seat: number): HoldemPublicPlayer[] {
  return [...players].sort((left, right) => {
    const leftGroup = left.seatIndex > seat ? 0 : 1;
    const rightGroup = right.seatIndex > seat ? 0 : 1;
    return leftGroup - rightGroup || left.seatIndex - right.seatIndex;
  });
}

function draw(game: HoldemGameState): HoldemCard {
  const card = game.server.deck[game.server.deckIndex];
  if (!card) throw new Error("홀덤 덱에 남은 카드가 없습니다.");
  game.server.deckIndex += 1;
  return card;
}

function touch(game: HoldemGameState, now: number): void {
  game.public.revision += 1;
  game.public.updatedAt = now;
}

function requirePlaying(game: HoldemGameState): void {
  if (game.public.status !== "playing") throw new Error("진행 중인 홀덤 게임이 아닙니다.");
}

function requireBettingPhase(game: HoldemGameState): void {
  requirePlaying(game);
  if (!isBettingPhase(game.public.phase)) throw new Error("현재 베팅할 수 있는 단계가 아닙니다.");
}

function isBettingPhase(phase: HoldemGameState["public"]["phase"]): boolean {
  return phase === "preflop" || phase === "flop" || phase === "turn" || phase === "river";
}

function assertStartPlayers(players: HoldemStartPlayer[]): void {
  if (players.length < 2 || players.length > 8) throw new Error("홀덤은 2~8명이어야 합니다.");
  const uids = new Set(players.map((player) => player.uid));
  const seats = new Set(players.map((player) => player.seatIndex));
  if (uids.size !== players.length || seats.size !== players.length || players.some((player) => !player.uid || !Number.isInteger(player.seatIndex) || player.seatIndex < 0 || player.seatIndex >= players.length)) {
    throw new Error("홀덤 플레이어 UID와 좌석은 중복 없이 연속 범위여야 합니다.");
  }
}
