import assert from "node:assert/strict";
import test from "node:test";

import {
  assertControllerSession,
  createControllerSessionId,
} from "../lib/room/controller-session.js";
import {
  isGameAccessibleToGroup,
  shouldDeleteRoom,
} from "../lib/room/realtime-room-lifecycle.js";
import {decideRoomJoin} from "../lib/room/room-join-policy.js";
import {
  applyWaitingGameSelection,
  decideRoomSeating,
} from "../lib/room/room-seating-policy.js";
import {runPrimedTransaction} from "../lib/room/room-transaction.js";

test("controller UID와 현재 session이 모두 맞아야 진행 명령을 허용한다", () => {
  const sessionId = createControllerSessionId();
  const room = {controllerUid: "tablet", controllerSessionId: sessionId};

  assert.equal(assertControllerSession(room, "tablet", sessionId), sessionId);
  assert.throws(() => assertControllerSession(room, "tablet", createControllerSessionId()));
  assert.throws(() => assertControllerSession(room, "old-tablet", sessionId));
});

test("대기 방은 순간 단절을 견디고 3분이 지나면 삭제한다", () => {
  const now = 1_000_000;
  for (const status of ["waiting", "seating", undefined]) {
    assert.equal(
      shouldDeleteRoom({status, controllerPresence: {lastSeen: now - 60_000}}, now),
      false,
      `${status}: 순간 단절로 삭제하면 안 됩니다`,
    );
    assert.equal(
      shouldDeleteRoom({status, controllerPresence: {lastSeen: now - 181_000}}, now),
      true,
      `${status}: 3분이 지나면 삭제해야 합니다`,
    );
  }
});

test("진행 중인 방은 대기 방보다 오래 붙잡는다 (C-03)", () => {
  // 태블릿이 3분 백그라운드에 있었다는 이유로 진행 중인 판이 통째로 사라지는
  // 것이 '그룹 폭파'의 직접 원인이었다. 대기 방이 사라지면 다시 만들면 되지만
  // 진행 중인 판은 되돌릴 방법이 없다.
  const now = 1_000_000;
  const playing = (lastSeen) =>
    shouldDeleteRoom({status: "playing", controllerPresence: {lastSeen}}, now);

  // 대기 방이라면 삭제됐을 시점
  assert.equal(playing(now - 181_000), false);
  // OS 업데이트 후 재부팅(5~15분)까지 덮는다
  assert.equal(playing(now - 14 * 60_000), false);
  assert.equal(playing(now - 15 * 60_000), true);

  // 대기 방보다 반드시 길어야 한다
  assert.equal(
    shouldDeleteRoom(
      {status: "waiting", controllerPresence: {lastSeen: now - 5 * 60_000}},
      now,
    ),
    true,
  );
  assert.equal(playing(now - 5 * 60_000), false);
});

test("finished 방은 보존 시간이 지난 뒤에만 삭제한다", () => {
  const now = 1_000_000;
  assert.equal(
    shouldDeleteRoom({status: "finished", retainUntil: now + 1}, now),
    false,
  );
  assert.equal(
    shouldDeleteRoom({status: "finished", retainUntil: now}, now),
    true,
  );
});

test("무료 게임은 항상 허용하고 유료 게임은 그룹 보유자에게만 허용한다", () => {
  assert.equal(isGameAccessibleToGroup(undefined, "mafia", []), true);
  assert.equal(isGameAccessibleToGroup("free", "final_call", []), true);
  assert.equal(
    isGameAccessibleToGroup("paid", "paid_game", [[], ["paid_game"]]),
    true,
  );
  assert.equal(
    isGameAccessibleToGroup("paid", "paid_game", [["another_game"]]),
    false,
  );
});

test("신규 참가자는 waiting에서만 허용한다", () => {
  assert.equal(decideRoomJoin({roomStatus: "waiting", playerExists: false}), "new-player");
  assert.equal(
    decideRoomJoin({
      roomStatus: "waiting",
      gameStatus: "finished",
      playerExists: false,
    }),
    "new-player",
  );
  assert.equal(decideRoomJoin({roomStatus: "seating", playerExists: false}), "game-preparing");
  assert.equal(decideRoomJoin({roomStatus: "playing", playerExists: false}), "game-preparing");
  assert.equal(decideRoomJoin({roomStatus: "closed", playerExists: false}), "room-closed");
  assert.equal(decideRoomJoin({roomStatus: "finished", playerExists: false}), "room-finished");
});

test("기존 active UID는 seating과 playing에서도 재접속할 수 있다", () => {
  assert.equal(
    decideRoomJoin({
      roomStatus: "waiting",
      gameStatus: "finished",
      playerExists: true,
      playerStatus: "active",
    }),
    "reconnect",
  );
  assert.equal(
    decideRoomJoin({
      roomStatus: "seating",
      playerExists: true,
      playerStatus: "active",
    }),
    "reconnect",
  );
  assert.equal(
    decideRoomJoin({
      roomStatus: "playing",
      gameStatus: "playing",
      playerExists: true,
      playerStatus: "active",
    }),
    "reconnect",
  );
  assert.equal(
    decideRoomJoin({
      roomStatus: "seating",
      playerExists: true,
      playerStatus: "inactive",
    }),
    "inactive-player",
  );
});

test("게임 선택 변경은 이전 종료 게임 데이터를 제거하고 waiting으로 전환한다", () => {
  const room = {
    status: "finished",
    selectedGame: "liars_poker",
    game: {public: {status: "finished"}},
    finishedAt: 100,
    retainUntil: 200,
  };

  applyWaitingGameSelection(room, "mafia");
  assert.deepEqual(room, {status: "waiting", selectedGame: "mafia"});

  applyWaitingGameSelection(room, null);
  assert.deepEqual(room, {status: "waiting"});
});

test("waiting 방의 선택 게임과 인원이 유효할 때만 seating을 시작한다", () => {
  const validState = {
    roomStatus: "waiting",
    selectedGame: "mafia",
    expectedGame: "mafia",
    activePlayerCount: 4,
    minPlayers: 4,
    maxPlayers: 12,
  };

  assert.equal(decideRoomSeating(validState), "begin");
  assert.equal(
    decideRoomSeating({...validState, activePlayerCount: 3}),
    "invalid-player-count",
  );
  assert.equal(
    decideRoomSeating({...validState, activePlayerCount: 13}),
    "invalid-player-count",
  );
});

test("자리 배치 시작과 경합한 상태·게임 변경을 거부한다", () => {
  const validState = {
    roomStatus: "waiting",
    selectedGame: "mafia",
    expectedGame: "mafia",
    activePlayerCount: 4,
    minPlayers: 4,
    maxPlayers: 12,
  };

  assert.equal(
    decideRoomSeating({...validState, roomStatus: "playing"}),
    "invalid-status",
  );
  assert.equal(
    decideRoomSeating({...validState, gameStatus: "playing"}),
    "invalid-status",
  );
  assert.equal(
    decideRoomSeating({...validState, selectedGame: "final_call"}),
    "game-changed",
  );
  assert.equal(
    decideRoomSeating({...validState, roomStatus: "seating"}),
    "already-seating",
  );
});

test("RTDB 트랜잭션은 첫 서버 값을 받은 뒤 실행하고 리스너를 해제한다", async () => {
  const calls = [];
  let emitValue;
  const expectedResult = {committed: true, snapshot: {val: () => ({})}};
  const ref = {
    on(event, listener) {
      calls.push(`on:${event}`);
      emitValue = listener;
    },
    off(event, listener) {
      calls.push(`off:${event}:${listener === emitValue}`);
    },
    async transaction(update) {
      calls.push("transaction");
      assert.deepEqual(update({status: "waiting"}), {status: "seating"});
      return expectedResult;
    },
  };

  const pending = runPrimedTransaction(ref, (room) => ({
    ...room,
    status: "seating",
  }));
  await Promise.resolve();
  assert.deepEqual(calls, ["on:value"]);

  emitValue({val: () => ({status: "waiting"})});
  assert.equal(await pending, expectedResult);
  assert.deepEqual(calls, ["on:value", "transaction", "off:value:true"]);
});
