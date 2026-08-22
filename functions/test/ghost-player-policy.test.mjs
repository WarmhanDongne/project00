import assert from "node:assert/strict";
import test from "node:test";

import {
  findGhostPlayers,
  GHOST_PLAYER_GRACE_MS,
} from "../lib/room/ghost-player-policy.js";

//=======================유령 참가자 정리 (C-10)==============================
// 이탈 참가자 제거가 화면 타이머의 onExpired 호출에만 의존했다. 화면 dispose·
// 앱 백그라운드·네트워크 재단절·전원 종료 어느 것이든 그 호출이 사라지면
// 참가자 노드가 영구히 남는다. 게임이 끝나 대기실로 돌아왔을 때 나간 사람이
// 명단에 그대로 보인다.
//
// ⚠️ 지우는 쪽은 되돌릴 수 없으므로 판정은 보수적이어야 한다.

const now = 10_000_000;
const stale = now - GHOST_PLAYER_GRACE_MS - 1;
const fresh = now - 1000;

function player(overrides = {}) {
  return {isConnected: false, lastSeen: stale, role: "player", ...overrides};
}

test("유예가 지난 끊긴 참가자만 지운다", () => {
  assert.deepEqual(
    findGhostPlayers({
      roomStatus: "waiting",
      players: {ghost: player(), alive: player({isConnected: true})},
      now,
    }),
    ["ghost"],
  );
});

test("진행 중인 방은 아무도 지우지 않는다", () => {
  // 그 구간의 이탈은 게임 중단(interruption)이 담당한다. 여기서 손대면
  // 중단 상태와 경합해 재접속 유예 중인 참가자를 지울 수 있다.
  assert.deepEqual(
    findGhostPlayers({
      roomStatus: "playing",
      players: {ghost: player()},
      now,
    }),
    [],
  );
  assert.deepEqual(
    findGhostPlayers({
      roomStatus: "finished",
      gameStatus: "playing",
      players: {ghost: player()},
      now,
    }),
    [],
  );
});

test("재접속 유예 중인 참가자는 남긴다", () => {
  assert.deepEqual(
    findGhostPlayers({
      roomStatus: "waiting",
      players: {recent: player({lastSeen: fresh})},
      now,
    }),
    [],
  );
});

test("유예 경계에서는 아직 지우지 않는다", () => {
  assert.deepEqual(
    findGhostPlayers({
      roomStatus: "waiting",
      players: {edge: player({lastSeen: now - GHOST_PLAYER_GRACE_MS})},
      now,
    }),
    [],
  );
});

test("유예는 중단 재접속 유예(60초)보다 충분히 길다", () => {
  // 짧게 잡으면 재접속 유예 중인 정상 참가자를 지운다.
  assert.ok(GHOST_PLAYER_GRACE_MS > 60_000);
});

test("접속 중인 참가자는 오래됐어도 지우지 않는다", () => {
  assert.deepEqual(
    findGhostPlayers({
      roomStatus: "waiting",
      players: {live: player({isConnected: true, lastSeen: stale})},
      now,
    }),
    [],
  );
});

test("isConnected가 없는 옛 노드는 살아 있는 것으로 본다", () => {
  const {isConnected: _drop, ...noFlag} = player();
  assert.deepEqual(
    findGhostPlayers({roomStatus: "waiting", players: {old: noFlag}, now}),
    [],
  );
});

test("lastSeen이 없으면 판단 근거가 없으므로 남긴다", () => {
  const {lastSeen: _drop, ...noSeen} = player();
  assert.deepEqual(
    findGhostPlayers({roomStatus: "waiting", players: {old: noSeen}, now}),
    [],
  );
});

test("관전자는 이 정리의 대상이 아니다", () => {
  assert.deepEqual(
    findGhostPlayers({
      roomStatus: "waiting",
      players: {watcher: player({role: "observer"})},
      now,
    }),
    [],
  );
});

test("게임이 끝나 대기실로 돌아온 방을 정리한다", () => {
  // C-10의 실제 증상: 종료 후 대기실에 나간 사람이 남아 있다.
  assert.deepEqual(
    findGhostPlayers({
      roomStatus: "waiting",
      gameStatus: "finished",
      players: {
        left: player(),
        stillHere: player({isConnected: true, lastSeen: fresh}),
      },
      now,
    }),
    ["left"],
  );
});

test("참가자가 없거나 형태가 이상해도 던지지 않는다", () => {
  assert.deepEqual(findGhostPlayers({roomStatus: "waiting", players: {}, now}), []);
  assert.deepEqual(
    findGhostPlayers({
      roomStatus: "waiting",
      players: {broken: null, alsoBroken: "nope"},
      now,
    }),
    [],
  );
});
