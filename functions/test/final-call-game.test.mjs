import assert from "node:assert/strict";
import test from "node:test";

import {
  createFinalCallPlayers,
  finalCallTeamForSeat,
  nextFinalCallRoundStarter,
  removeFinalTurnPendingPlayer,
  resolveFinalCallRound,
} from "../lib/final-call/game.js";

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

test("Final Call은 정확히 4명만 시작할 수 있다", async () => {
  const roomPlayer = (seatIndex) => ({
    role: "player",
    status: "active",
    nickname: `P${seatIndex}`,
    profileImageUrl: "https://example.com/profile.png",
    seatIndex,
  });
  await assert.rejects(() => createFinalCallPlayers({
    uid1: roomPlayer(0),
    uid2: roomPlayer(1),
    uid3: roomPlayer(2),
  }), /정확히 4명/);

  const players = await createFinalCallPlayers({
    uid1: roomPlayer(0),
    uid2: roomPlayer(1),
    uid3: roomPlayer(2),
    uid4: roomPlayer(3),
  });
  assert.equal(Object.keys(players).length, 4);
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
