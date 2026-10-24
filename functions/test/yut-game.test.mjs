import assert from "node:assert/strict";
import test from "node:test";

import {
  applyClassicRoll,
  YUT_HOME,
  advancePath,
  autoMoveYut,
  createYutGame,
  moveYutPiece,
  normalizeYutGame,
  submitStrategyChoice,
  timeoutYutTurn,
} from "../lib/yut/game.js";

const players = ["a", "b", "c", "d"].map((uid, seatIndex) => ({
  uid, nickname: uid.toUpperCase(), characterId: "", seatIndex,
}));

function strategyGame() {
  return createYutGame("strategy_yut", players, 1000);
}

/** Submits hidden sides so that exactly [fronts] players choose the front. */
function reveal(game, fronts, now = 2000) {
  const alive = ["a", "b", "c", "d"];
  alive.forEach((uid, index) => submitStrategyChoice(game, uid, index < fronts, now));
}

test("outer ring walks 1..19, passes the start corner and goes home", () => {
  let path = [];
  path = advancePath(path, 1);
  assert.deepEqual(path, [1]);
  path = advancePath(path, 3);
  assert.deepEqual(path, [1, 2, 3, 4]);
  // Passing through corner 5 without stopping keeps the outer ring.
  path = advancePath(path, 3);
  assert.deepEqual(path.slice(-3), [5, 6, 7]);
  path = advancePath([...Array(19).keys()].map((n) => n + 1), 1);
  assert.equal(path.at(-1), 0, "node 19 steps onto the start corner");
  path = advancePath(path, 1);
  assert.equal(path.at(-1), YUT_HOME, "any step past the start corner is home");
});

test("stopping on a corner takes the diagonal; the centre heads home", () => {
  assert.deepEqual(advancePath([1, 2, 3, 4, 5], 3).slice(-3), [20, 21, 22]);
  assert.deepEqual(advancePath([1, 2, 3, 4, 5, 20, 21], 3).slice(-3), [22, 23, 24]);
  assert.deepEqual(advancePath([1, 2, 3, 4, 5, 20, 21, 22], 2).slice(-2), [27, 28]);
  const fromTen = advancePath([...Array(10).keys()].map((n) => n + 1), 5);
  assert.deepEqual(fromTen.slice(-5), [25, 26, 22, 27, 28]);
  assert.equal(advancePath([1, 2, 3, 4, 5, 20, 21, 22, 27, 28], 2).at(-1), YUT_HOME);
});

test("back-do retraces one step and wraps from the first node", () => {
  assert.deepEqual(advancePath([1, 2, 3], -1), [1, 2]);
  assert.deepEqual(advancePath([1], -1), [0]);
  assert.deepEqual(advancePath([0], -1), [19]);
});

test("strategy: geol is pooled, moved on the tablet, then the turn passes", () => {
  const game = strategyGame();
  assert.equal(game.public.turnTeam, "blue");
  reveal(game, 1); // 앞면 1 · 뒷면 3 → 걸
  assert.equal(game.public.phase, "moving");
  assert.deepEqual(game.public.pool, [{name: "geol", steps: 3}]);
  const result = moveYutPiece(game, 0, 0, 3000);
  assert.equal(result.type, "pieceMoved");
  assert.equal(game.public.pieces.blue[0].position, 3);
  assert.equal(game.public.turnTeam, "white");
  assert.equal(game.public.phase, "selecting");
  assert.equal(game.public.turnUid, "b");
});

test("strategy: one flat back (three fronts) is back-do and is dropped with nothing on the board", () => {
  const game = strategyGame();
  reveal(game, 3);
  assert.equal(game.public.lastRoll.name, "backDo");
  assert.equal(game.public.turnTeam, "white", "unusable back-do ends the turn");
  assert.equal(game.public.pool.length, 0);
});

test("yut and mo throw again and keep the pooled results", () => {
  const game = strategyGame();
  reveal(game, 0); // 뒷면 4 → 윷
  assert.equal(game.public.phase, "selecting");
  assert.equal(game.public.turnTeam, "blue");
  assert.deepEqual(game.public.pool.map((entry) => entry.name), ["yut"]);
  reveal(game, 4, 2500); // 앞면 4 → 모
  assert.equal(game.public.phase, "selecting");
  reveal(game, 2, 2600);
  assert.equal(game.public.phase, "moving");
  assert.deepEqual(game.public.pool.map((entry) => entry.name), ["yut", "mo", "gae"]);
  moveYutPiece(game, 0, 2, 3000);
  assert.equal(game.public.phase, "moving", "remaining results stay on the tablet");
  assert.deepEqual(game.public.pool.map((entry) => entry.name), ["yut", "mo"]);
});

test("stacked pieces move together and a capture earns another throw", () => {
  const game = strategyGame();
  const pub = game.public;
  pub.pieces.blue[0] = {id: 0, position: 2, path: [1, 2], status: "onBoard"};
  pub.pieces.blue[1] = {id: 1, position: 2, path: [1, 2], status: "onBoard"};
  pub.pieces.white[0] = {id: 0, position: 4, path: [1, 2, 3, 4], status: "onBoard"};
  pub.phase = "moving";
  pub.pool = [{name: "gae", steps: 2}, {name: "do", steps: 1}];
  const result = moveYutPiece(game, 1, 0, 3000);
  assert.deepEqual(result.movedPieceIds, [0, 1]);
  assert.equal(pub.pieces.blue[0].position, 4);
  assert.equal(pub.pieces.white[0].status, "ready");
  assert.equal(result.extraThrow, true);
  assert.equal(pub.phase, "selecting");
  assert.equal(pub.turnTeam, "blue");
  assert.deepEqual(pub.pool.map((entry) => entry.name), ["do"]);
});

test("two pieces home wins for the team", () => {
  const game = strategyGame();
  const pub = game.public;
  pub.pieces.blue[0] = {id: 0, position: YUT_HOME, path: [YUT_HOME], status: "finished"};
  pub.pieces.blue[3] = {id: 3, position: 19, path: [...Array(19).keys()].map((n) => n + 1), status: "onBoard"};
  pub.phase = "moving";
  pub.pool = [{name: "gae", steps: 2}];
  const result = moveYutPiece(game, 3, 0, 3000);
  assert.equal(result.type, "winner");
  assert.equal(pub.status, "finished");
  assert.equal(pub.winningTeam, "blue");
});

test("one piece home is not yet a win", () => {
  const game = strategyGame();
  const pub = game.public;
  pub.pieces.blue[3] = {id: 3, position: 19, path: [...Array(19).keys()].map((n) => n + 1), status: "onBoard"};
  pub.phase = "moving";
  pub.pool = [{name: "gae", steps: 2}];
  const result = moveYutPiece(game, 3, 0, 3000);
  assert.notEqual(result.type, "winner");
  assert.equal(pub.status, "playing");
  assert.equal(pub.pieces.blue[3].status, "finished");
});

test("timeouts choose randomly, then move the leading piece automatically", () => {
  const game = strategyGame();
  submitStrategyChoice(game, "a", true, 1500);
  timeoutYutTurn(game, game.public.turnDeadlineAt);
  assert.notEqual(game.public.lastRoll, null);
  const pub = game.public;
  pub.phase = "moving";
  pub.turnTeam = "blue";
  pub.pool = [{name: "do", steps: 1}];
  pub.pieces.blue[2] = {id: 2, position: 6, path: [1, 2, 3, 4, 5, 6], status: "onBoard"};
  autoMoveYut(game, 5000);
  assert.equal(pub.pieces.blue[2].position, 7);
});

test("classic: the thrower's pieces are keyed by uid and back-do passes", () => {
  const game = createYutGame("yut", players, 1000);
  assert.equal(game.public.phase, "rolling");
  assert.deepEqual(Object.keys(game.public.pieces).sort(), ["a", "b", "c", "d"]);
  game.public.pool = [{name: "backDo", steps: -1}];
  game.public.phase = "moving";
  autoMoveYut(game, 2000);
  assert.equal(game.public.turnUid, "b");
  assert.equal(game.public.phase, "rolling");
});

test("classic supports two, three, and four players", () => {
  for (const count of [2, 3, 4]) {
    const game = createYutGame("yut", players.slice(0, count), 1000);
    assert.equal(Object.keys(game.public.players).length, count);
    assert.equal(Object.keys(game.public.pieces).length, count);
    assert.equal(game.public.turnUid, "a");
  }
  for (const count of [1, 5]) {
    const roster = count === 5
      ? [...players, {...players[0], uid: "e", seatIndex: 4}]
      : players.slice(0, count);
    assert.throws(() => createYutGame("yut", roster, 1000), {code: "failed-precondition"});
  }
});

test("classic two-player game rolls, moves and passes the turn in both directions", () => {
  const game = createYutGame("yut", players.slice(0, 2), 1000);
  const pub = game.public;

  assert.equal(applyClassicRoll(game, "a", 1500).actorUid, "a");
  const firstMover = pub.turnUid;
  pub.phase = "moving";
  pub.pool = [{name: "gae", steps: 2}];
  moveYutPiece(game, 0, 0, 2000);
  assert.notEqual(pub.turnUid, firstMover);
  assert.equal(pub.phase, "rolling");

  const secondMover = pub.turnUid;
  assert.ok(["a", "b"].includes(secondMover));
  pub.phase = "moving";
  pub.pool = [{name: "do", steps: 1}];
  moveYutPiece(game, 0, 0, 3000);
  assert.equal(pub.turnUid, firstMover);
  assert.equal(pub.phase, "rolling");
});

test("strategy products still require four players", () => {
  for (const gameId of ["strategy_yut", "strategy_yut_edition"]) {
    for (const count of [2, 3]) {
      assert.throws(() => createYutGame(gameId, players.slice(0, count), 1000), {
        code: "failed-precondition",
      });
    }
  }
});

test("states read back from RTDB without empty arrays are repaired", () => {
  const game = strategyGame();
  delete game.public.pool;
  delete game.public.history;
  for (const piece of game.public.pieces.blue) delete piece.path;
  normalizeYutGame(game);
  assert.deepEqual(game.public.pool, []);
  assert.deepEqual(game.public.pieces.blue[0].path, []);
});
