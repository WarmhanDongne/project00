import assert from "node:assert/strict";
import test from "node:test";

import {
  HOLDEM_ACTION_MS,
  HOLDEM_MAX_PLAYERS,
  HOLDEM_MIN_PLAYERS,
  HOLDEM_STARTING_CHIPS,
  holdemBlindsForHand,
  holdemTimeoutAction,
} from "../lib/holdem/config.js";
import {createHoldemDeck} from "../lib/holdem/deck.js";
import {
  compareHoldemHands,
  describeHoldemHandRank,
  evaluateHoldemHand,
} from "../lib/holdem/hand-evaluator.js";
import {
  applyHoldemAction,
  createHoldemBettingRound,
  holdemBettingRoundComplete,
  legalHoldemActions,
} from "../lib/holdem/betting.js";
import {buildHoldemPots, settleHoldemPots} from "../lib/holdem/pots.js";
import {nextHoldemPositions} from "../lib/holdem/table.js";
import {
  actInHoldemGame,
  completeHoldemDealing,
  completeHoldemResult,
  createHoldemGame,
  timeoutHoldemTurn,
} from "../lib/holdem/game.js";

function card(rank, suit) {
  return {id: `${rank}_${suit}`, rank, suit};
}

function cards(values) {
  return values.map(([rank, suit]) => card(rank, suit));
}

function player(
  uid,
  seatIndex,
  {
    stack = 1000,
    streetContribution = 0,
    totalContribution = streetContribution,
    status = "active",
  } = {},
) {
  return {
    uid,
    seatIndex,
    stack,
    streetContribution,
    totalContribution,
    status,
  };
}

test("승인된 홀덤 MVP 인원·칩·시간·블라인드 표를 유지한다", () => {
  assert.equal(HOLDEM_MIN_PLAYERS, 2);
  assert.equal(HOLDEM_MAX_PLAYERS, 8);
  assert.equal(HOLDEM_STARTING_CHIPS, 1000);
  assert.equal(HOLDEM_ACTION_MS, 20_000);
  assert.deepEqual(holdemBlindsForHand(1), {smallBlind: 10, bigBlind: 20});
  assert.deepEqual(holdemBlindsForHand(5), {smallBlind: 10, bigBlind: 20});
  assert.deepEqual(holdemBlindsForHand(6), {smallBlind: 20, bigBlind: 40});
  assert.deepEqual(holdemBlindsForHand(21), {smallBlind: 160, bigBlind: 320});
  assert.deepEqual(holdemBlindsForHand(100), {smallBlind: 160, bigBlind: 320});
  assert.equal(holdemTimeoutAction(true), "check");
  assert.equal(holdemTimeoutAction(false), "fold");
  assert.throws(() => holdemBlindsForHand(0), /1 이상/);
});

test("상태 머신은 비공개 홀 카드와 공개 보드를 분리해 첫 핸드를 연다", () => {
  const game = createHoldemGame([
    {uid: "a", nickname: "A", characterId: "frog", seatIndex: 0},
    {uid: "b", nickname: "B", characterId: "cat", seatIndex: 1},
  ], 1000, () => createHoldemDeck(() => 0));

  assert.equal(game.public.phase, "dealing");
  assert.equal(game.public.communityCards.length, 0);
  assert.equal(game.private.a.hand.length, 2);
  assert.equal(game.private.b.hand.length, 2);
  assert.equal("hand" in game.public.players.a, false);
  assert.equal(game.public.players.a.stack, 990);
  assert.equal(game.public.players.b.stack, 980);

  const completed = completeHoldemDealing(game, 2000);
  assert.equal(completed.success, true);
  assert.equal(game.public.phase, "preflop");
  assert.equal(game.public.turnUid, "a");
  assert.equal(game.private.a.legalActions?.fold, true);
  assert.equal(game.private.b.legalActions, null);
});

test("폴드 승리 뒤 칩을 지급하고 다음 핸드에서 버튼을 이동한다", () => {
  const game = createHoldemGame([
    {uid: "a", nickname: "A", characterId: "frog", seatIndex: 0},
    {uid: "b", nickname: "B", characterId: "cat", seatIndex: 1},
  ], 1000, () => createHoldemDeck(() => 0));
  completeHoldemDealing(game, 2000);
  actInHoldemGame(game, "a", {kind: "fold"}, 2100);

  assert.equal(game.public.phase, "handResult");
  assert.deepEqual(game.public.result?.winnerUids, ["b"]);
  assert.equal(game.public.players.a.stack, 990);
  assert.equal(game.public.players.b.stack, 1010);

  const result = completeHoldemResult(game, 3000, () => createHoldemDeck(() => 0));
  assert.equal(result.type, "nextHand");
  assert.equal(game.public.handNumber, 2);
  assert.equal(game.public.dealerUid, "b");
  assert.equal(game.public.phase, "dealing");
});

test("시간 초과는 체크 가능하면 체크하고 콜이 필요하면 폴드한다", () => {
  const game = createHoldemGame([
    {uid: "a", nickname: "A", characterId: "frog", seatIndex: 0},
    {uid: "b", nickname: "B", characterId: "cat", seatIndex: 1},
  ], 1000, () => createHoldemDeck(() => 0));
  completeHoldemDealing(game, 2000);
  assert.equal(timeoutHoldemTurn(game, 2100).success, false);
  const timeout = timeoutHoldemTurn(game, 22_000);
  assert.equal(timeout.success, true);
  assert.equal(game.public.phase, "handResult");
  assert.equal(game.public.result?.reason, "fold");
});

test("올인 플레이어는 쇼다운 전까지 공용 생존 상태를 유지한다", () => {
  const game = createHoldemGame([
    {uid: "a", nickname: "A", characterId: "frog", seatIndex: 0},
    {uid: "b", nickname: "B", characterId: "cat", seatIndex: 1},
  ], 1000, () => createHoldemDeck(() => 0));
  completeHoldemDealing(game, 2000);

  actInHoldemGame(game, "a", {kind: "allIn"}, 2100);

  assert.equal(game.public.players.a.stack, 0);
  assert.equal(game.public.players.a.handStatus, "allIn");
  assert.equal(game.public.players.a.status, "alive");
  assert.equal(game.public.turnUid, "b");
});

test("베팅 라운드가 닫히면 플롭을 공개하고 딜러 다음 생존자에게 턴을 준다", () => {
  const game = createHoldemGame([
    {uid: "a", nickname: "A", characterId: "frog", seatIndex: 0},
    {uid: "b", nickname: "B", characterId: "cat", seatIndex: 1},
    {uid: "c", nickname: "C", characterId: "bear", seatIndex: 2},
  ], 1000, () => createHoldemDeck(() => 0));
  completeHoldemDealing(game, 2000);
  actInHoldemGame(game, "a", {kind: "call"}, 2100);
  actInHoldemGame(game, "b", {kind: "call"}, 2200);
  actInHoldemGame(game, "c", {kind: "check"}, 2300);

  assert.equal(game.public.phase, "flop");
  assert.equal(game.public.communityCards.length, 3);
  assert.equal(game.public.turnUid, "b");
  assert.equal(game.public.currentBet, 0);
});

test("RTDB가 빈 보드 배열을 생략해도 두 번째 플레이어 CHECK가 플롭을 연다", () => {
  const players = [
    {uid: "a", nickname: "A", characterId: "frog", seatIndex: 0},
    {uid: "b", nickname: "B", characterId: "cat", seatIndex: 1},
  ];
  const roundTrip = (game) => JSON.parse(JSON.stringify(game, (_key, value) => {
    if (value === null || (Array.isArray(value) && value.length === 0)) return undefined;
    return value;
  }));
  let game = roundTrip(createHoldemGame(players, 1000, () => createHoldemDeck(() => 0)));
  assert.equal(game.public.communityCards, undefined);

  completeHoldemDealing(game, 2000);
  game = roundTrip(game);
  assert.equal(game.public.turnUid, "a");
  actInHoldemGame(game, "a", {kind: "call"}, 2100);
  game = roundTrip(game);
  assert.equal(game.public.turnUid, "b");
  assert.equal(game.private.b.legalActions.check, true);

  actInHoldemGame(game, "b", {kind: "check"}, 2200);
  assert.equal(game.public.phase, "flop");
  assert.equal(game.public.communityCards.length, 3);
  assert.equal(game.public.turnUid, "b");
});

test("비공개 현재 족보는 보드 공개에 맞춰 갱신되고 쇼다운은 최종 5장을 공개한다", () => {
  const game = createHoldemGame([
    {uid: "a", nickname: "A", characterId: "frog", seatIndex: 0},
    {uid: "b", nickname: "B", characterId: "cat", seatIndex: 1},
  ], 1000, () => createHoldemDeck(() => 0));
  assert.equal(game.private.a.handRank?.bestCards.length, 2);
  completeHoldemDealing(game, 2000);
  actInHoldemGame(game, "a", {kind: "call"}, 2100);
  actInHoldemGame(game, "b", {kind: "check"}, 2200);

  assert.equal(game.public.phase, "flop");
  for (const uid of ["a", "b"]) {
    const expected = evaluateHoldemHand([...game.private[uid].hand, ...game.public.communityCards]);
    assert.equal(game.private[uid].handRank?.category, expected.category);
    assert.deepEqual(game.private[uid].handRank?.bestCards, expected.bestCards);
  }

  actInHoldemGame(game, "b", {kind: "allIn"}, 2300);
  actInHoldemGame(game, "a", {kind: "call"}, 2400);
  assert.equal(game.public.phase, "handResult");
  assert.equal(game.public.result?.reason, "showdown");
  for (const uid of ["a", "b"]) {
    const expected = evaluateHoldemHand([...game.private[uid].hand, ...game.public.communityCards]);
    assert.deepEqual(game.public.result?.bestCards?.[uid], expected.bestCards);
    assert.equal(game.public.result?.handCategories[uid], expected.category);
    assert.deepEqual(game.private[uid].handRank?.bestCards, expected.bestCards);
  }
});

test("프리플롭 현재 족보는 홀 카드 2장으로 페어와 하이 카드를 구분한다", () => {
  assert.deepEqual(
    describeHoldemHandRank(cards([["9", "hearts"], ["9", "spades"]]), []),
    {category: "onePair", bestCards: cards([["9", "hearts"], ["9", "spades"]])},
  );
  assert.deepEqual(
    describeHoldemHandRank(cards([["4", "clubs"], ["k", "spades"]]), []),
    {category: "highCard", bestCards: cards([["k", "spades"], ["4", "clubs"]])},
  );
  assert.equal(describeHoldemHandRank([], []), null);
  assert.equal(
    describeHoldemHandRank(
      cards([["a", "spades"], ["7", "spades"]]),
      cards([["k", "spades"], ["9", "hearts"], ["2", "spades"], ["j", "spades"]]),
    )?.category,
    "flush",
  );
});

test("표준 덱은 suit·rank 조합이 겹치지 않는 52장이다", () => {
  const deck = createHoldemDeck(() => 0);
  assert.equal(deck.length, 52);
  assert.equal(new Set(deck.map((value) => value.id)).size, 52);
  assert.equal(deck.filter((value) => value.rank === "a").length, 4);
  assert.equal(deck.filter((value) => value.suit === "spades").length, 13);
  assert.throws(() => createHoldemDeck((maximum) => maximum), /난수 범위/);
});

test("7장 중 최선의 족보와 wheel straight를 계산한다", () => {
  const royal = evaluateHoldemHand(cards([
    ["a", "spades"],
    ["k", "spades"],
    ["q", "spades"],
    ["j", "spades"],
    ["10", "spades"],
    ["2", "hearts"],
    ["2", "clubs"],
  ]));
  assert.equal(royal.category, "straightFlush");
  assert.deepEqual(royal.tiebreak, [14]);

  const wheel = evaluateHoldemHand(cards([
    ["a", "clubs"],
    ["2", "diamonds"],
    ["3", "hearts"],
    ["4", "spades"],
    ["5", "clubs"],
    ["k", "diamonds"],
    ["q", "hearts"],
  ]));
  assert.equal(wheel.category, "straight");
  assert.deepEqual(wheel.tiebreak, [5]);
});

test("두 트리플에서는 높은 트리플을 쓰는 full house를 고른다", () => {
  const value = evaluateHoldemHand(cards([
    ["a", "spades"],
    ["a", "hearts"],
    ["a", "diamonds"],
    ["k", "spades"],
    ["k", "hearts"],
    ["k", "diamonds"],
    ["2", "clubs"],
  ]));
  assert.equal(value.category, "fullHouse");
  assert.deepEqual(value.tiebreak, [14, 13]);
});

test("아홉 족보 등급을 약한 순서부터 정확히 구분한다", () => {
  const values = [
    cards([
      ["a", "spades"], ["k", "hearts"], ["9", "diamonds"],
      ["7", "clubs"], ["3", "hearts"],
    ]),
    cards([
      ["a", "spades"], ["a", "hearts"], ["9", "diamonds"],
      ["7", "clubs"], ["3", "hearts"],
    ]),
    cards([
      ["a", "spades"], ["a", "hearts"], ["9", "diamonds"],
      ["9", "clubs"], ["3", "hearts"],
    ]),
    cards([
      ["a", "spades"], ["a", "hearts"], ["a", "diamonds"],
      ["7", "clubs"], ["3", "hearts"],
    ]),
    cards([
      ["9", "spades"], ["8", "hearts"], ["7", "diamonds"],
      ["6", "clubs"], ["5", "hearts"],
    ]),
    cards([
      ["a", "hearts"], ["j", "hearts"], ["9", "hearts"],
      ["7", "hearts"], ["3", "hearts"],
    ]),
    cards([
      ["a", "spades"], ["a", "hearts"], ["a", "diamonds"],
      ["9", "clubs"], ["9", "hearts"],
    ]),
    cards([
      ["a", "spades"], ["a", "hearts"], ["a", "diamonds"],
      ["a", "clubs"], ["9", "hearts"],
    ]),
    cards([
      ["9", "spades"], ["8", "spades"], ["7", "spades"],
      ["6", "spades"], ["5", "spades"],
    ]),
  ].map(evaluateHoldemHand);

  assert.deepEqual(
    values.map((value) => value.category),
    [
      "highCard",
      "onePair",
      "twoPair",
      "threeOfAKind",
      "straight",
      "flush",
      "fullHouse",
      "fourOfAKind",
      "straightFlush",
    ],
  );
  assert.deepEqual(values.map((value) => value.categoryRank), [0, 1, 2, 3, 4, 5, 6, 7, 8]);
});

test("같은 족보는 kicker로 비교하고 완전 동률은 0이다", () => {
  const aceKicker = evaluateHoldemHand(cards([
    ["9", "spades"],
    ["9", "hearts"],
    ["a", "diamonds"],
    ["k", "clubs"],
    ["7", "spades"],
    ["4", "hearts"],
    ["2", "diamonds"],
  ]));
  const queenKicker = evaluateHoldemHand(cards([
    ["9", "clubs"],
    ["9", "diamonds"],
    ["q", "hearts"],
    ["j", "clubs"],
    ["7", "hearts"],
    ["4", "clubs"],
    ["2", "spades"],
  ]));
  assert.ok(compareHoldemHands(aceKicker, queenKicker) > 0);

  const boardOne = evaluateHoldemHand(cards([
    ["a", "spades"],
    ["k", "spades"],
    ["q", "spades"],
    ["j", "spades"],
    ["10", "spades"],
    ["2", "clubs"],
    ["3", "diamonds"],
  ]));
  const boardTwo = evaluateHoldemHand(cards([
    ["a", "spades"],
    ["k", "spades"],
    ["q", "spades"],
    ["j", "spades"],
    ["10", "spades"],
    ["8", "clubs"],
    ["9", "diamonds"],
  ]));
  assert.equal(compareHoldemHands(boardOne, boardTwo), 0);
  assert.throws(
    () => evaluateHoldemHand([
      card("a", "spades"),
      card("a", "spades"),
      ...cards([
        ["k", "hearts"],
        ["q", "diamonds"],
        ["j", "clubs"],
      ]),
    ]),
    /중복 카드/,
  );
  assert.throws(
    () => evaluateHoldemHand([
      card("a", "spades"),
      {id: "different-id", rank: "a", suit: "spades"},
      ...cards([
        ["k", "hearts"],
        ["q", "diamonds"],
        ["j", "clubs"],
      ]),
    ]),
    /중복 카드/,
  );
});

test("일반 테이블과 heads-up의 버튼·블라인드·첫 행동 순서를 계산한다", () => {
  const fourPlayers = [
    player("a", 0),
    player("b", 2),
    player("c", 5),
    player("d", 7),
  ];
  assert.deepEqual(nextHoldemPositions(fourPlayers, 0), {
    dealerUid: "b",
    smallBlindUid: "c",
    bigBlindUid: "d",
    preflopFirstUid: "a",
    postflopFirstUid: "c",
  });

  const headsUp = [player("a", 0), player("b", 4)];
  assert.deepEqual(nextHoldemPositions(headsUp, 0), {
    dealerUid: "b",
    smallBlindUid: "b",
    bigBlindUid: "a",
    preflopFirstUid: "b",
    postflopFirstUid: "a",
  });
  assert.throws(
    () => nextHoldemPositions([player("a", 0), player("a", 1)], null),
    /UID 또는 좌석이 중복/,
  );
});

test("프리플롭 call·check가 순서대로 끝나면 베팅 라운드가 닫힌다", () => {
  let round = createHoldemBettingRound([
    player("small", 0, {stack: 990, streetContribution: 10}),
    player("big", 1, {stack: 980, streetContribution: 20}),
    player("button", 2),
  ], 20, 20, "button");

  round = applyHoldemAction(round, "button", {kind: "call"});
  assert.equal(round.turnUid, "small");
  round = applyHoldemAction(round, "small", {kind: "call"});
  assert.equal(round.turnUid, "big");
  assert.equal(legalHoldemActions(round, "big").check, true);
  round = applyHoldemAction(round, "big", {kind: "check"});

  assert.equal(round.turnUid, null);
  assert.equal(holdemBettingRoundComplete(round), true);
  assert.equal(round.players.small.stack, 980);
  assert.equal(round.players.button.totalContribution, 20);
  assert.throws(
    () => createHoldemBettingRound(
      [player("same", 0), player("same", 1)],
      0,
      20,
      "same",
    ),
    /UID 또는 좌석이 중복/,
  );
});

test("full raise는 최소 레이즈를 갱신하고 이전 행동자의 선택을 다시 연다", () => {
  let round = createHoldemBettingRound([
    player("a", 0),
    player("b", 1, {stack: 900, streetContribution: 100}),
    player("c", 2, {stack: 900, streetContribution: 100}),
  ], 100, 100, "a");
  round = applyHoldemAction(round, "a", {kind: "call"});
  round = applyHoldemAction(round, "b", {
    kind: "raise",
    targetContribution: 300,
  });
  round = applyHoldemAction(round, "c", {kind: "call"});

  const legal = legalHoldemActions(round, "a");
  assert.equal(round.minimumRaise, 200);
  assert.equal(legal.raise, true);
  assert.equal(legal.minimumTarget, 500);
});

test("short all-in 하나는 이미 call한 플레이어의 raise를 다시 열지 않는다", () => {
  let round = createHoldemBettingRound([
    player("a", 0),
    player("b", 1, {stack: 50, streetContribution: 100}),
    player("c", 2, {stack: 900, streetContribution: 100}),
  ], 100, 100, "a");
  round = applyHoldemAction(round, "a", {kind: "call"});
  round = applyHoldemAction(round, "b", {kind: "allIn"});
  round = applyHoldemAction(round, "c", {kind: "call"});

  const legal = legalHoldemActions(round, "a");
  assert.equal(legal.toCall, 50);
  assert.equal(legal.raise, false);
  assert.equal(legal.allIn, false);
  round = applyHoldemAction(round, "a", {kind: "call"});
  assert.equal(round.turnUid, null);
});

test("누적 short all-in이 full raise 크기에 도달하면 raise가 다시 열린다", () => {
  let round = createHoldemBettingRound([
    player("a", 0),
    player("b", 1, {stack: 50, streetContribution: 100}),
    player("c", 2, {stack: 100, streetContribution: 100}),
  ], 100, 100, "a");
  round = applyHoldemAction(round, "a", {kind: "call"});
  round = applyHoldemAction(round, "b", {kind: "allIn"});
  round = applyHoldemAction(round, "c", {kind: "allIn"});

  const legal = legalHoldemActions(round, "a");
  assert.equal(legal.toCall, 100);
  assert.equal(legal.raise, true);
  assert.equal(legal.minimumTarget, 300);
});

test("체크 뒤 최소 베팅보다 작은 opening all-in은 minimum bet까지 올릴 수 있다", () => {
  let round = createHoldemBettingRound([
    player("a", 0),
    player("b", 1, {stack: 50}),
  ], 0, 100, "a");
  round = applyHoldemAction(round, "a", {kind: "check"});
  round = applyHoldemAction(round, "b", {kind: "allIn"});

  const legal = legalHoldemActions(round, "a");
  assert.equal(legal.raise, true);
  assert.equal(legal.minimumTarget, 100);
  round = applyHoldemAction(round, "a", {
    kind: "raise",
    targetContribution: 100,
  });
  assert.equal(round.currentBet, 100);
});

test("복수 side pot과 콜되지 않은 초과 베팅을 분리한다", () => {
  const result = buildHoldemPots([
    {uid: "a", seatIndex: 0, amount: 1000, folded: false},
    {uid: "b", seatIndex: 1, amount: 500, folded: false},
    {uid: "c", seatIndex: 2, amount: 200, folded: true},
    {uid: "d", seatIndex: 3, amount: 200, folded: false},
  ]);
  assert.deepEqual(result.refunds, {a: 500});
  assert.deepEqual(result.pots, [
    {
      amount: 800,
      cap: 200,
      contributorUids: ["a", "b", "c", "d"],
      eligibleUids: ["a", "b", "d"],
    },
    {
      amount: 600,
      cap: 500,
      contributorUids: ["a", "b"],
      eligibleUids: ["a", "b"],
    },
  ]);
});

test("각 side pot은 자격 있는 최고 족보에게 따로 지급된다", () => {
  const built = buildHoldemPots([
    {uid: "a", seatIndex: 0, amount: 1000, folded: false},
    {uid: "b", seatIndex: 1, amount: 500, folded: false},
    {uid: "c", seatIndex: 2, amount: 200, folded: true},
    {uid: "d", seatIndex: 3, amount: 200, folded: false},
  ]);
  const hands = {
    a: evaluateHoldemHand(cards([
      ["a", "spades"], ["a", "hearts"], ["a", "diamonds"],
      ["k", "spades"], ["k", "hearts"], ["4", "clubs"], ["2", "diamonds"],
    ])),
    b: evaluateHoldemHand(cards([
      ["9", "spades"], ["8", "hearts"], ["7", "diamonds"],
      ["6", "clubs"], ["5", "hearts"], ["3", "clubs"], ["2", "spades"],
    ])),
    d: evaluateHoldemHand(cards([
      ["q", "spades"], ["q", "hearts"], ["q", "diamonds"],
      ["q", "clubs"], ["5", "hearts"], ["3", "diamonds"], ["2", "clubs"],
    ])),
  };

  const result = settleHoldemPots(
    built.pots,
    hands,
    {a: 0, b: 1, c: 2, d: 3},
    0,
  );
  assert.deepEqual(result.awards, {d: 800, a: 600});
  assert.deepEqual(built.refunds, {a: 500});
});

test("동률 팟의 홀수 칩은 딜러 다음 승자부터 지급한다", () => {
  const common = cards([
    ["a", "spades"],
    ["k", "spades"],
    ["q", "spades"],
    ["j", "spades"],
    ["10", "spades"],
  ]);
  const hands = {
    a: evaluateHoldemHand([...common, card("2", "clubs"), card("3", "diamonds")]),
    b: evaluateHoldemHand([...common, card("8", "clubs"), card("9", "diamonds")]),
  };
  const result = settleHoldemPots([
    {
      amount: 5,
      cap: 3,
      contributorUids: ["a", "b"],
      eligibleUids: ["a", "b"],
    },
  ], hands, {a: 2, b: 5}, 3);

  assert.deepEqual(result.awards, {b: 3, a: 2});
  assert.deepEqual(result.pots[0].winnerUids, ["b", "a"]);
});
