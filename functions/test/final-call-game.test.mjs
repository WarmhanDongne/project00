import assert from "node:assert/strict";
import test from "node:test";

import {
  createFinalCallPlayers,
  createInitialFinalCallGame,
  finalCallTeamForSeat,
  nextFinalCallRoundStarter,
  nextFinalCallPlayer,
  prepareFinalCallRound,
  removeFinalTurnPendingPlayer,
  resolveFinalCallRound,
} from "../lib/final-call/game.js";

import {excludeFinalCallPlayer} from "../lib/final-call/exclude-player.js";
import {assertFinalCallTurn} from "../lib/final-call/validation.js";

function card(id, color, value) {
  return {id, color, value};
}

function finalCallGame({automaticCall = false} = {}) {
  const uid1Hand = {
    red10: card("red10", "red", 10),
    blue10: card("blue10", "blue", 10),
    green2: card("green2", "green", 2),
    yellow4: card("yellow4", "yellow", 4),
  };
  const uid2Hand = {
    red6: card("red6", "red", 6),
    red5: card("red5", "red", 5),
    blue3: card("blue3", "blue", 3),
    green1: card("green1", "green", 1),
  };
  const uid3Hand = {
    red9: card("red9", "red", 9),
    blue9: card("blue9", "blue", 9),
    green7: card("green7", "green", 7),
    yellow2: card("yellow2", "yellow", 2),
  };
  const uid4Hand = {
    red8: card("red8", "red", 8),
    blue8: card("blue8", "blue", 8),
    green6: card("green6", "green", 6),
    yellow3: card("yellow3", "yellow", 3),
  };
  return {
    public: {
      status: "playing",
      phase: automaticCall ? "playing" : "finalSubmit",
      round: 1,
      revision: 1,
      turnUid: "uid2",
      turnDeadlineAt: 100,
      callerUid: automaticCall ? null : "uid1",
      deckRemainingCount: 3,
      discardCard: card("discard", "yellow", 1),
      pendingDrawUid: null,
      pendingDrawSource: null,
      finalTurnPendingUids: automaticCall ? [] : ["uid2"],
      winnerUid: null,
      winnerUids: [],
      winningTeam: null,
      players: {
        uid1: {uid: "uid1", nickname: "A", seatIndex: 0, team: "red", status: "alive", lives: 3},
        uid2: {uid: "uid2", nickname: "B", seatIndex: 1, team: "blue", status: "alive", lives: 3},
        uid3: {uid: "uid3", nickname: "C", seatIndex: 2, team: "red", status: "alive", lives: 3},
        uid4: {uid: "uid4", nickname: "D", seatIndex: 3, team: "blue", status: "alive", lives: 3},
      },
      startedAt: 1,
      updatedAt: 1,
    },
    private: {
      uid1: {hand: uid1Hand},
      uid2: {hand: uid2Hand},
      uid3: {hand: uid3Hand},
      uid4: {hand: uid4Hand},
    },
    server: {
      deck: [],
      pendingHands: {},
      finalSubmissions: automaticCall ? {} : {
        uid1: [uid1Hand.red10, uid1Hand.blue10],
        uid2: [uid2Hand.red6, uid2Hand.red5],
        uid3: [uid3Hand.red9, uid3Hand.blue9],
        uid4: [uid4Hand.red8, uid4Hand.blue8],
      },
      roundStarterUid: "uid1",
      processedCommands: {},
    },
  };
}

test("Final Call 결과에는 각 플레이어가 제출한 카드만 공개된다", () => {
  const game = finalCallGame();

  resolveFinalCallRound(game, 200, false);

  assert.deepEqual(
    game.public.roundResult.revealedHands.uid1.map((value) => value.id),
    ["red10", "blue10"],
  );
  assert.deepEqual(
    game.public.roundResult.revealedHands.uid2.map((value) => value.id),
    ["red6", "red5"],
  );
  assert.equal(game.public.roundResult.revealedHands.uid1.length, 2);
  assert.equal(game.public.roundResult.revealedHands.uid2.length, 2);
});

test("마주 보는 좌석은 같은 팀으로 자동 지정된다", () => {
  assert.equal(finalCallTeamForSeat(0), "red");
  assert.equal(finalCallTeamForSeat(2), "red");
  assert.equal(finalCallTeamForSeat(1), "blue");
  assert.equal(finalCallTeamForSeat(3), "blue");
});

test("Final Call의 기존 4인 시작과 팀 배치를 유지한다", async () => {
  const roomPlayer = (seatIndex) => ({
    role: "player",
    status: "active",
    nickname: `P${seatIndex}`,
    characterId: "frog",
    seatIndex,
  });
  await assert.rejects(() => createFinalCallPlayers({
    uid1: roomPlayer(0),
    uid2: roomPlayer(1),
    uid3: roomPlayer(2),
  }), /4명 또는 6명/);

  const players = await createFinalCallPlayers({
    uid1: roomPlayer(0),
    uid2: roomPlayer(1),
    uid3: roomPlayer(2),
    uid4: roomPlayer(3),
  });
  assert.equal(Object.keys(players).length, 4);
  assert.equal(players.uid1.characterId, "frog");
  assert.equal(players.uid1.team, players.uid3.team);
  assert.equal(players.uid2.team, players.uid4.team);
});

test("CALL 패배자는 실제 보유한 하트만 잃고 팀 전체가 패배한다", () => {
  const game = finalCallGame();
  game.public.callerUid = "uid2";
  game.public.players.uid2.lives = 1;

  resolveFinalCallRound(game, 200, false);

  assert.equal(game.public.roundResult.lifeLosses.uid2, 1);
  assert.equal(game.public.players.uid2.lives, 0);
  assert.equal(game.public.status, "finished");
  assert.equal(game.public.winningTeam, "red");
  assert.deepEqual(game.public.winnerUids, ["uid1", "uid3"]);
  assert.equal(game.public.players.uid4.status, "eliminated");
});

test("덱 소진 자동 CALL도 전체 손패 대신 최고 조합만 공개한다", () => {
  const game = finalCallGame({automaticCall: true});

  resolveFinalCallRound(game, 200, true);

  assert.deepEqual(
    game.public.roundResult.revealedHands.uid1.map((value) => value.id),
    ["red10", "blue10"],
  );
  assert.deepEqual(
    game.public.roundResult.revealedHands.uid2.map((value) => value.id),
    ["red6", "red5"],
  );
});

test("RTDB에서 빈 최종 턴 목록이 생략되어도 플레이어 퇴장을 처리한다", () => {
  assert.deepEqual(removeFinalTurnPendingPlayer(undefined, "uid1"), []);
  assert.deepEqual(
    removeFinalTurnPendingPlayer(["uid1", "uid2"], "uid1"),
    ["uid2"],
  );
});

// 같은 숫자 4장을 제출한 CALL 라운드를 만듭니다.
// uid1(red팀)이 7 네 장을 내고, 나머지는 평범한 조합을 냅니다.
function fourOfAKindGame({callerUid = "uid1"} = {}) {
  const game = finalCallGame();
  const quad = [
    card("q-red7", "red", 7),
    card("q-blue7", "blue", 7),
    card("q-green7", "green", 7),
    card("q-yellow7", "yellow", 7),
  ];
  game.private.uid1 = {
    hand: Object.fromEntries(quad.map((value) => [value.id, value])),
  };
  game.server.finalSubmissions.uid1 = quad;
  game.public.callerUid = callerUid;
  return game;
}

test("포카드로 CALL하면 상대팀 전원만 하트를 하나씩 잃는다", () => {
  const game = fourOfAKindGame();

  resolveFinalCallRound(game, 300, false);

  const result = game.public.roundResult;
  assert.equal(result.callerFourOfAKind, true);
  // uid2, uid4가 blue팀입니다.
  assert.deepEqual(result.lifeLosses, {uid2: 1, uid4: 1});
  assert.equal(game.public.players.uid2.lives, 2);
  assert.equal(game.public.players.uid4.lives, 2);
  // 선언한 red팀은 아무도 잃지 않습니다.
  assert.equal(game.public.players.uid1.lives, 3);
  assert.equal(game.public.players.uid3.lives, 3);
  // 최저 점수 판정은 건너뜁니다.
  assert.deepEqual(result.lowestUids, []);
});

test("포카드를 들고 있어도 다른 사람이 CALL하면 평소대로 점수로 겨룬다", () => {
  const game = fourOfAKindGame({callerUid: "uid2"});

  resolveFinalCallRound(game, 300, false);

  const result = game.public.roundResult;
  assert.equal(result.callerFourOfAKind, false);
  // uid1의 포카드는 28점이라 최저가 아니고, 하트도 잃지 않습니다.
  assert.equal(result.scores.uid1, 28);
  assert.equal(game.public.players.uid1.lives, 3);
  // 최저 점수 판정이 그대로 동작합니다.
  assert.ok(result.lowestUids.length > 0);
  assert.equal(result.lifeLosses.uid1, undefined);
});

test("포카드가 아닌 일반 CALL은 기존 규칙 그대로다", () => {
  const game = finalCallGame();

  resolveFinalCallRound(game, 300, false);

  const result = game.public.roundResult;
  assert.equal(result.callerFourOfAKind, false);
  assert.ok(result.lowestUids.length > 0);
});

test("덱 소진 자동 CALL에서는 포카드 규칙이 적용되지 않는다", () => {
  const game = fourOfAKindGame();

  resolveFinalCallRound(game, 300, true);

  assert.equal(game.public.roundResult.callerFourOfAKind, false);
});

// ============================================================================
// 다음 라운드 시작 플레이어
// ============================================================================

function roundStarterGame({lifeLosses, players}) {
  return {
    public: {
      status: "playing",
      phase: "roundResult",
      round: 2,
      revision: 5,
      turnUid: null,
      players,
      roundResult: {
        scores: {},
        lifeLosses,
        lowestUids: Object.keys(lifeLosses),
        revealedHands: {},
        callerUid: null,
        automaticCall: false,
        callerFourOfAKind: false,
        resolvedAt: 200,
      },
    },
    private: {},
    server: {deck: [], pendingHands: {}, finalSubmissions: {}, roundStarterUid: "uid1", processedCommands: {}},
  };
}

function starterPlayer(uid, seatIndex, lives, status = "alive") {
  return {uid, nickname: uid, seatIndex, team: seatIndex % 2 === 0 ? "red" : "blue", status, lives};
}

test("직전 라운드에 생명을 잃은 플레이어가 다음 라운드를 시작한다", () => {
  const game = roundStarterGame({
    lifeLosses: {uid3: 1},
    players: {
      uid1: starterPlayer("uid1", 0, 3),
      uid2: starterPlayer("uid2", 1, 3),
      uid3: starterPlayer("uid3", 2, 2),
      uid4: starterPlayer("uid4", 3, 3),
    },
  });

  assert.equal(nextFinalCallRoundStarter(game), "uid3");
});

test("두 명이 동시에 잃었으면 남은 생명이 더 적은 플레이어가 시작한다", () => {
  const game = roundStarterGame({
    lifeLosses: {uid2: 1, uid4: 1},
    players: {
      uid1: starterPlayer("uid1", 0, 3),
      uid2: starterPlayer("uid2", 1, 2),
      uid3: starterPlayer("uid3", 2, 3),
      uid4: starterPlayer("uid4", 3, 1),
    },
  });

  assert.equal(nextFinalCallRoundStarter(game), "uid4");
});

test("잃은 생명까지 같으면 좌석 순서가 빠른 플레이어가 시작한다", () => {
  const game = roundStarterGame({
    lifeLosses: {uid2: 1, uid4: 1},
    players: {
      uid1: starterPlayer("uid1", 0, 3),
      uid2: starterPlayer("uid2", 1, 2),
      uid3: starterPlayer("uid3", 2, 3),
      uid4: starterPlayer("uid4", 3, 2),
    },
  });

  assert.equal(nextFinalCallRoundStarter(game), "uid2");
});

test("생명을 잃은 플레이어가 탈락했으면 생존자 중 생명이 가장 적은 쪽이 시작한다", () => {
  const game = roundStarterGame({
    lifeLosses: {uid3: 1},
    players: {
      uid1: starterPlayer("uid1", 0, 3),
      uid2: starterPlayer("uid2", 1, 1),
      uid3: starterPlayer("uid3", 2, 0, "eliminated"),
      uid4: starterPlayer("uid4", 3, 2),
    },
  });

  assert.equal(nextFinalCallRoundStarter(game), "uid2");
});

function roomPlayersForSeats(seats) {
  return Object.fromEntries(seats.map((seatIndex, index) => [`p${index}`, {
    role: "player", status: "active", seatIndex, nickname: `P${index}`,
  }]));
}

test("6인은 반대 좌석끼리 세 팀을 구성하고 40장에서 중복 없이 배분한다", async () => {
  const players = await createFinalCallPlayers(roomPlayersForSeats([0, 1, 2, 3, 4, 5]));
  assert.deepEqual(Object.values(players).map((player) => player.team),
    ["red", "blue", "green", "red", "blue", "green"]);
  const game = createInitialFinalCallGame(players, 100);
  const hands = Object.values(game.server.pendingHands);
  assert.equal(hands.length, 6);
  for (const player of hands) assert.equal(Object.keys(player.hand).length, 4);
  assert.equal(game.public.deckRemainingCount, 15);
  const cards = [...hands.flatMap((player) => Object.values(player.hand)),
    ...game.server.deck, game.public.discardCard];
  assert.equal(new Set(cards.map((card) => card.id)).size, 40);
  assert.deepEqual(game.private, {});
});

test("4·6인 외 인원과 중복·범위 밖 좌석은 시작을 거부한다", async () => {
  for (const seats of [[0, 1], [0, 1, 2, 3, 4], [0, 1, 2, 3, 4, 5, 6],
    [0, 1, 2, 3, 4, 4], [0, 1, 2, 3, 4, 6], [-1, 0, 1, 2, 3, 4],
    [0, 1, 2, 3, 4, 4.5]]) {
    await assert.rejects(() => createFinalCallPlayers(roomPlayersForSeats(seats)));
  }
});

async function sixPlayerGame() {
  const players = await createFinalCallPlayers(roomPlayersForSeats([0, 1, 2, 3, 4, 5]));
  const game = createInitialFinalCallGame(players, 100);
  game.private = game.server.pendingHands;
  delete game.server.pendingHands;
  game.public.phase = "finalSubmit";
  game.public.callerUid = "p0";
  setScores(game, {p0: 10, p1: 9, p2: 1, p3: 8, p4: 7, p5: 6});
  return game;
}

function setScores(game, scores) {
  game.server.finalSubmissions = Object.fromEntries(Object.entries(scores)
    .map(([uid, value]) => [uid, [card(`${uid}-score`, "red", value)]]));
}

test("6인 첫 팀 탈락 후 원래 팀·좌석으로 계속하고 탈락자는 배분·턴에서 제외한다", async () => {
  const game = await sixPlayerGame();
  game.public.players.p2.lives = 1;
  resolveFinalCallRound(game, 200, false);
  assert.equal(game.public.status, "playing");
  assert.equal(game.public.phase, "roundResult");
  assert.equal(game.public.players.p2.status, "eliminated");
  assert.equal(game.public.players.p5.status, "eliminated");
  assert.equal(game.public.players.p5.lives, 3);
  assert.equal(game.public.winningTeam, null);
  assert.deepEqual(game.public.winnerUids, []);
  assert.equal(game.public.finishedAt, undefined);
  assert.equal(nextFinalCallRoundStarter(game), "p0");
  prepareFinalCallRound(game, nextFinalCallRoundStarter(game), 2, 300);
  assert.deepEqual(Object.keys(game.server.pendingHands), ["p0", "p1", "p3", "p4"]);
  assert.equal(game.public.deckRemainingCount, 23);
  assert.equal(nextFinalCallPlayer(game.public.players, "p1"), "p3");
  assert.equal(nextFinalCallPlayer(game.public.players, "p4"), "p0");
  assert.equal(game.public.players.p3.team, "red");
  assert.equal(game.public.players.p4.seatIndex, 4);
  game.public.turnUid = "p5";
  assert.throws(() => assertFinalCallTurn(game, "p5"), /탈락/);

  game.private = game.server.pendingHands;
  setScores(game, {p0: 10, p1: 1, p3: 8, p4: 7});
  game.public.players.p1.lives = 1;
  resolveFinalCallRound(game, 400, false);
  assert.equal(game.public.status, "finished");
  assert.equal(game.public.winningTeam, "red");
  assert.deepEqual(game.public.winnerUids, ["p0", "p3"]);
  assert.equal(game.public.players.p4.status, "eliminated");
  assert.equal(game.public.roundResult.scores.p2, undefined);
});

test("두 팀이 동시에 탈락하면 남은 그린팀이 승리한다", async () => {
  const game = await sixPlayerGame();
  setScores(game, {p0: 1, p1: 1, p2: 5, p3: 8, p4: 7, p5: 6});
  game.public.players.p0.lives = 1;
  game.public.players.p1.lives = 1;
  resolveFinalCallRound(game, 200, false);
  assert.equal(game.public.finishReason, "winner");
  assert.equal(game.public.winningTeam, "green");
  assert.deepEqual(game.public.winnerUids, ["p2", "p5"]);
  for (const uid of ["p0", "p1", "p3", "p4"]) {
    assert.equal(game.public.players[uid].status, "eliminated");
  }
});

test("세 팀이 동시에 탈락하면 무승부로 종료한다", async () => {
  const game = await sixPlayerGame();
  setScores(game, {p0: 1, p1: 1, p2: 1, p3: 8, p4: 7, p5: 6});
  for (const uid of ["p0", "p1", "p2"]) game.public.players[uid].lives = 1;
  resolveFinalCallRound(game, 200, false);
  assert.equal(game.public.finishReason, "draw");
  assert.equal(game.public.winningTeam, null);
  assert.deepEqual(game.public.winnerUids, []);
  assert.ok(Object.values(game.public.players).every((player) => player.status === "eliminated"));
});

test("6인 포카드 CALL은 상대 두 팀 네 명에게만 하트 손실을 적용한다", async () => {
  const game = await sixPlayerGame();
  game.server.finalSubmissions.p0 = ["red", "blue", "green", "yellow"]
    .map((color) => card(`${color}-7`, color, 7));
  resolveFinalCallRound(game, 200, false);
  assert.deepEqual(game.public.roundResult.lifeLosses, {p1: 1, p2: 1, p4: 1, p5: 1});
  assert.equal(game.public.players.p0.lives, 3);
  assert.equal(game.public.players.p3.lives, 3);
  assert.equal(game.public.status, "playing");
});

test("6인 덱 소진 자동 판정도 팀 탈락 뒤 남은 팀끼리 계속한다", async () => {
  const game = await sixPlayerGame();
  for (const [uid, hand] of Object.entries(game.server.finalSubmissions)) {
    game.private[uid] = {hand: Object.fromEntries(hand.map((card) => [card.id, card]))};
  }
  game.public.players.p2.lives = 1;
  resolveFinalCallRound(game, 200, true);
  assert.equal(game.public.status, "playing");
  assert.equal(game.public.players.p5.status, "eliminated");
  assert.equal(game.public.roundResult.automaticCall, true);
});

test("관전자 제외는 게임에 영향을 주지 않고 실제 참가자 퇴장은 팀 구성 부족으로 종료한다", async () => {
  const game = await sixPlayerGame();
  game.public.players.p2.lives = 1;
  resolveFinalCallRound(game, 200, false);
  const before = structuredClone(game);
  excludeFinalCallPlayer(game, "p5", 250);
  assert.deepEqual(game, before);
  excludeFinalCallPlayer(game, "p0", 300);
  assert.equal(game.public.finishReason, "insufficientPlayers");
  assert.deepEqual(game.private, {});
  assert.equal(game.public.winningTeam, null);

  const six = await sixPlayerGame();
  excludeFinalCallPlayer(six, "p0", 300);
  assert.equal(six.public.finishReason, "insufficientPlayers");
});
