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

test("controller UID와 현재 session이 모두 맞아야 진행 명령을 허용한다", () => {
  const sessionId = createControllerSessionId();
  const room = {controllerUid: "tablet", controllerSessionId: sessionId};

  assert.equal(assertControllerSession(room, "tablet", sessionId), sessionId);
  assert.throws(() => assertControllerSession(room, "tablet", createControllerSessionId()));
  assert.throws(() => assertControllerSession(room, "old-tablet", sessionId));
});

test("순간 단절 유예시간 중인 방은 삭제하지 않고 오래된 방만 삭제한다", () => {
  const now = 1_000_000;
  assert.equal(
    shouldDeleteRoom(
      {status: "playing", controllerPresence: {lastSeen: now - 60_000}},
      now,
    ),
    false,
  );
  assert.equal(
    shouldDeleteRoom(
      {status: "playing", controllerPresence: {lastSeen: now - 181_000}},
      now,
    ),
    true,
  );
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
