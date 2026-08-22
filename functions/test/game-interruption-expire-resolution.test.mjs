// =========================================================================
// 중단 만료의 서버 최종 처리 (C-03/C-10)
//
// 지금까지 중단 만료를 부르는 곳은 휴대폰·태블릿 화면의 카운트다운뿐이었습니다.
// 남은 참가자가 전원 앱을 닫으면 중단이 영구 잔류하고 게임이 멈췄습니다.
// `resolveExpiredInterruption`은 그 처리를 순수 함수로 분리한 것이며,
// **callable과 서버 스케줄이 같은 함수를 씁니다.** 두 경로가 각자 상태를
// 만들면 "화면이 끝낸 게임"과 "서버가 끝낸 게임"의 최종 상태가 갈립니다.
// =========================================================================

import assert from "node:assert/strict";
import test from "node:test";

import {resolveExpiredInterruption} from "../lib/game-interruption/expire-resolution.js";
import {beginGameInterruption} from "../lib/game-interruption/state.js";

const DEADLINE_PASSED = 62000;

function liarsPokerGame(uids) {
  const players = {};
  for (const uid of uids) players[uid] = {status: "alive", nickname: uid};
  return {
    public: {
      status: "playing",
      phase: "playing",
      revision: 3,
      updatedAt: 100,
      turnUid: uids[0],
      turnDeadlineAt: 51000,
      penaltyTargetUid: null,
      winnerUid: null,
      players,
    },
    private: {[uids[0]]: {hand: ["K"]}},
    server: {lastPlayCards: ["K"], pendingHands: {}},
  };
}

function roomWithInterruption({uids, leaving, minimum, selectedGame}) {
  const game = liarsPokerGame(uids);
  const players = {};
  for (const uid of uids) {
    players[uid] = {
      nickname: uid,
      characterId: "frog",
      isConnected: uid !== leaving,
    };
  }
  const room = {
    controllerUid: "tablet",
    selectedGame,
    players,
    game,
  };
  beginGameInterruption(room, leaving, "left", 1000, {
    minimumPlayerCount: minimum,
  });
  return room;
}

/** 남은 인원이 부족한 방입니다(2인 중 1명 이탈). */
function stuckRoom() {
  return roomWithInterruption({
    uids: ["leaving", "a"],
    leaving: "leaving",
    minimum: 2,
    selectedGame: "liars_poker",
  });
}

/** 계속할 수 있는 방입니다(4인 중 1명 이탈, 최소 2명). */
function continuableRoom() {
  return roomWithInterruption({
    uids: ["leaving", "a", "b", "c"],
    leaving: "leaving",
    minimum: 2,
    selectedGame: "liars_poker",
  });
}

const noopExclude = () => {};

test("마감 전에는 아무것도 바꾸지 않는다", () => {
  const room = stuckRoom();
  const before = JSON.stringify(room);

  const result = resolveExpiredInterruption(room, 5000, noopExclude);

  assert.equal(result.outcome, "not-expired");
  assert.equal(JSON.stringify(room), before);
});

test("인원이 부족하면 게임을 정상 종료한다", () => {
  const room = stuckRoom();

  const result = resolveExpiredInterruption(room, DEADLINE_PASSED, noopExclude);

  assert.equal(result.outcome, "finished");
  assert.equal(room.game.public.status, "finished");
  assert.equal(room.game.public.finishReason, "insufficientPlayers");
  assert.equal(result.removedUid, "leaving");
});

test("종료 사유가 즉시 종료(C-11)와 같다", () => {
  // 휴대폰·태블릿이 '만료로 끝난 게임'과 '즉시 종료된 게임'을 구분하는 코드를
  // 갖지 않도록 같은 사유를 씁니다.
  const room = stuckRoom();
  resolveExpiredInterruption(room, DEADLINE_PASSED, noopExclude);
  assert.equal(room.game.public.finishReason, "insufficientPlayers");
});

test("이탈 당사자의 방 노드를 지운다", () => {
  const room = stuckRoom();

  resolveExpiredInterruption(room, DEADLINE_PASSED, noopExclude);

  assert.equal(room.players.leaving, undefined);
  assert.ok(room.players.a, "남은 참가자는 그대로여야 합니다");
});

test("좀비 턴 마감을 남기지 않는다", () => {
  // completeGameInterruption의 restoreTurnDeadline은 status === "playing"일 때만
  // 마감을 되살립니다. 종료를 **먼저** 부르면 그 가드를 통과하지 못합니다.
  // 순서를 뒤집으면 끝난 게임에 살아 있는 마감이 남습니다.
  const room = stuckRoom();

  resolveExpiredInterruption(room, DEADLINE_PASSED, noopExclude);

  assert.equal(room.game.public.turnDeadlineAt, null);
  assert.equal(room.game.server.interruption, undefined);
});

test("revision이 정확히 한 번만 오른다", () => {
  const room = stuckRoom();
  const before = room.game.public.revision;

  resolveExpiredInterruption(room, DEADLINE_PASSED, noopExclude);

  assert.equal(room.game.public.revision, before + 1);
});

test("계속할 수 있는 중단은 제외하고 이어 간다", () => {
  const room = continuableRoom();
  const excluded = [];

  const result = resolveExpiredInterruption(
    room,
    DEADLINE_PASSED,
    (_room, uid) => excluded.push(uid),
  );

  assert.equal(result.outcome, "continued");
  assert.equal(room.game.public.status, "playing");
  assert.deepEqual(excluded, ["leaving"]);
  assert.equal(room.players.leaving, undefined);
});

test("계속하는 경우 보관해 둔 턴 시간을 복원한다", () => {
  const room = continuableRoom();
  // beginGameInterruption이 now=1000에 마감 51000을 보관했으므로 남은 50초입니다.
  resolveExpiredInterruption(room, DEADLINE_PASSED, noopExclude);
  assert.equal(room.game.public.turnDeadlineAt, DEADLINE_PASSED + 50000);
});

test("중단이 없으면 아무것도 하지 않는다", () => {
  const room = stuckRoom();
  delete room.game.public.interruption;

  const result = resolveExpiredInterruption(room, DEADLINE_PASSED, noopExclude);

  assert.equal(result.outcome, "no-interruption");
  assert.equal(room.game.public.status, "playing");
});

test("이미 끝난 게임의 종료 사유를 덮어쓰지 않는다", () => {
  const room = stuckRoom();
  room.game.public.status = "finished";
  room.game.public.finishReason = "manual";

  const result = resolveExpiredInterruption(room, DEADLINE_PASSED, noopExclude);

  assert.equal(result.outcome, "no-interruption");
  assert.equal(room.game.public.finishReason, "manual");
  // 잔여 중단 상태는 지웁니다. 남겨 두면 끝난 게임 위에 중단 화면이 뜹니다.
  assert.equal(room.game.public.interruption, undefined);
});

test("종료 함수가 없는 게임은 중단 상태를 남긴 채 거부한다", () => {
  // 최악의 경우에도 기존 경로로 되돌아갈 수 있어야 합니다(영구 정지가 아니라 지연).
  const room = stuckRoom();
  room.selectedGame = "unknown_game";

  const result = resolveExpiredInterruption(room, DEADLINE_PASSED, noopExclude);

  assert.equal(result.outcome, "unsupported-game");
  assert.ok(room.game.public.interruption, "중단이 보존돼야 합니다");
  assert.equal(room.game.public.status, "playing");
});

test("두 번 불러도 두 번째는 상태를 바꾸지 않는다", () => {
  // 화면 만료와 서버 스케줄이 겹쳐도 안전해야 합니다.
  const room = stuckRoom();
  resolveExpiredInterruption(room, DEADLINE_PASSED, noopExclude);
  const after = JSON.stringify(room);

  const second = resolveExpiredInterruption(room, DEADLINE_PASSED, noopExclude);

  assert.equal(second.outcome, "no-interruption");
  assert.equal(JSON.stringify(room), after);
});

test("게임 노드가 없으면 아무것도 하지 않는다", () => {
  const result = resolveExpiredInterruption({players: {}}, DEADLINE_PASSED, noopExclude);
  assert.equal(result.outcome, "no-interruption");
});
