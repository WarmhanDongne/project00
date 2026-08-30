// =========================================================================
// 인원 부족 중단의 즉시 종료 (C-11)
//
// `game_common_interruption_finish_now`의 본체인 순수 함수를 검증합니다.
// onCall 래퍼(finish-now.js)는 import하지 않으므로 Firebase 초기화가 필요
// 없습니다. 중단 상태는 직접 만들지 않고 beginGameInterruption으로 만들어
// 서버와 같은 방식으로 canContinue·eligibleVoterUids가 계산되게 합니다.
// =========================================================================

import assert from "node:assert/strict";
import test from "node:test";

import {
  finishGameForInsufficientPlayers,
  resolveInterruptionFinishNow,
  supportsInsufficientPlayerFinish,
} from "../lib/game-interruption/finish-now-resolution.js";
import {beginGameInterruption} from "../lib/game-interruption/state.js";
import {makeGame} from "./mafia-test-state.mjs";

// assertControllerSession이 UUID v4 형식만 통과시킵니다.
const SESSION_ID = "11111111-2222-4333-8444-555555555555";
const CONTROLLER = "tablet";

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
    server: {lastPlayCards: ["K"], pendingHands: {a: ["K"]}},
  };
}

function finalCallGame(uids) {
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
      winnerUid: null,
      winnerUids: [],
      winningTeam: null,
      callerUid: null,
      pendingDrawUid: null,
      pendingDrawSource: null,
      finalTurnPendingUids: [],
      roundResult: {},
      resultRevealCompletedAt: 5,
      players,
    },
    private: {[uids[0]]: {hand: [1]}},
    server: {pendingHands: {}, finalSubmissions: {}},
  };
}

/**
 * 중단이 시작된 방을 만듭니다.
 *
 * @param {object} options.game        게임 상태
 * @param {string} options.selectedGame 게임 ID
 * @param {string} options.leaving     이탈자 UID
 * @param {number} options.minimum     최소 인원
 * @param {string[]} options.offline   방에서 연결이 끊긴 것으로 둘 UID 목록
 */
function roomWithInterruption({
  game,
  selectedGame,
  leaving,
  minimum,
  offline = [],
}) {
  const players = {};
  for (const uid of Object.keys(game.public.players)) {
    players[uid] = {
      nickname: uid,
      characterId: "frog",
      isConnected: !offline.includes(uid) && uid !== leaving,
    };
  }
  const room = {
    controllerUid: CONTROLLER,
    controllerSessionId: SESSION_ID,
    selectedGame,
    players,
    game,
  };
  const interruption = beginGameInterruption(room, leaving, "left", 1000, {
    minimumPlayerCount: minimum,
  });
  return {room, interruption};
}

/** 계속할 수 없는 라이어스 포커 방입니다(2인 중 1명 이탈 → 남은 1명 < 2). */
function stuckLiarsPokerRoom(options = {}) {
  return roomWithInterruption({
    game: liarsPokerGame(["leaving", "a"]),
    selectedGame: "liars_poker",
    leaving: "leaving",
    minimum: 2,
    ...options,
  });
}

function input(uid, interruptionId, overrides = {}) {
  return {uid, interruptionId, now: 5000, ...overrides};
}

// ===== 정상 종료 파리티 =====

test("라이어스 포커: 마감 전에 인원 부족으로 정상 종료된다", () => {
  const {room, interruption} = stuckLiarsPokerRoom();
  const response = resolveInterruptionFinishNow(
    room,
    input("a", interruption.id),
  );

  assert.equal(response.finished, true);
  assert.equal(response.finishReason, "insufficientPlayers");
  assert.equal(response.gameStatus, "finished");
  assert.equal(response.removedUid, "leaving");

  assert.equal(room.game.public.status, "finished");
  assert.equal(room.game.public.finishReason, "insufficientPlayers");
  assert.equal(room.game.public.phase, "finished");
  assert.equal(room.game.public.turnUid, null);
  assert.equal(room.game.public.turnDeadlineAt, null);
  assert.equal(room.game.public.finishedAt, 5000);
  assert.deepEqual(room.game.private, {});
  assert.equal(room.game.public.interruption, undefined);
  assert.equal(room.game.server.interruption, undefined);
  assert.equal(room.game.server.pendingHands, undefined);
});

test("파이널 콜: 마감 전에 인원 부족으로 정상 종료된다", () => {
  const {room, interruption} = roomWithInterruption({
    game: finalCallGame(["leaving", "a", "b", "c"]),
    selectedGame: "final_call",
    leaving: "leaving",
    minimum: 4,
  });
  const response = resolveInterruptionFinishNow(
    room,
    input("a", interruption.id),
  );

  assert.equal(response.finished, true);
  assert.equal(room.game.public.status, "finished");
  assert.equal(room.game.public.finishReason, "insufficientPlayers");
  assert.equal(room.game.public.phase, "finished");
  assert.equal(room.game.public.turnDeadlineAt, null);
  assert.deepEqual(room.game.private, {});
  assert.equal(room.game.public.roundResult, undefined);
  assert.equal(room.game.public.interruption, undefined);
});

test("마피아: 마감 전에 인원 부족으로 종료하고 전원 신분을 공개한다", () => {
  const game = makeGame({
    leaving: "mafia",
    p1: "police",
    c1: "citizen",
    c2: "citizen",
  });
  const {room, interruption} = roomWithInterruption({
    game,
    selectedGame: "mafia",
    leaving: "leaving",
    minimum: 4,
  });
  const response = resolveInterruptionFinishNow(
    room,
    input("c1", interruption.id),
  );

  assert.equal(response.finished, true);
  assert.equal(game.public.status, "finished");
  assert.equal(game.public.finishReason, "insufficientPlayers");
  assert.equal(game.public.phase, "finished");
  assert.equal(game.public.turnDeadlineAt, null);
  assert.deepEqual(game.public.winnerUids, []);
  assert.equal(Object.keys(game.public.revealedRoles).length, 4);
  assert.equal(game.public.interruption, undefined);
});

test("어느 게임이든 revision이 정확히 한 번만 오른다", () => {
  // 파이널 콜의 종료 함수는 revision을 갱신하지 않고, 나머지 둘은 갱신합니다.
  // resolveInterruptionFinishNow가 그 차이를 흡수하는지 확인합니다.
  const cases = [
    stuckLiarsPokerRoom(),
    roomWithInterruption({
      game: finalCallGame(["leaving", "a", "b", "c"]),
      selectedGame: "final_call",
      leaving: "leaving",
      minimum: 4,
    }),
    roomWithInterruption({
      game: makeGame({leaving: "mafia", p1: "police", c1: "citizen", c2: "citizen"}),
      selectedGame: "mafia",
      leaving: "leaving",
      minimum: 4,
    }),
  ];

  for (const {room, interruption} of cases) {
    const before = room.game.public.revision;
    // 세 픽스처에 공통으로 존재하는 호출자는 진행 태블릿입니다.
    const response = resolveInterruptionFinishNow(
      room,
      input(CONTROLLER, interruption.id, {controllerSessionId: SESSION_ID}),
    );
    assert.equal(response.finished, true, room.selectedGame);
    assert.equal(
      room.game.public.revision,
      before + 1,
      `${room.selectedGame}의 revision이 정확히 1 올라야 합니다`,
    );
    assert.equal(room.game.public.updatedAt, 5000, room.selectedGame);
  }
});

// ===== 멱등성 =====

test("두 번 호출해도 두 번째는 상태를 바꾸지 않는다", () => {
  const {room, interruption} = stuckLiarsPokerRoom();
  resolveInterruptionFinishNow(room, input("a", interruption.id));
  const revision = room.game.public.revision;
  const finishedAt = room.game.public.finishedAt;

  const second = resolveInterruptionFinishNow(
    room,
    input("a", interruption.id, {now: 9000}),
  );

  assert.equal(second.alreadyResolved, true);
  assert.equal(second.finished, false);
  assert.equal(room.game.public.revision, revision);
  assert.equal(room.game.public.finishedAt, finishedAt);
});

test("중단 ID가 다르면 아무것도 하지 않는다", () => {
  const {room} = stuckLiarsPokerRoom();
  const response = resolveInterruptionFinishNow(room, input("a", "other-id"));

  assert.equal(response.alreadyResolved, true);
  assert.equal(room.game.public.status, "playing");
  assert.notEqual(room.game.public.interruption, undefined);
});

test("이미 끝난 게임의 종료 사유를 덮어쓰지 않는다", () => {
  const {room, interruption} = stuckLiarsPokerRoom();
  room.game.public.status = "finished";
  room.game.public.finishReason = "manual";

  const response = resolveInterruptionFinishNow(
    room,
    input("a", interruption.id),
  );

  assert.equal(response.alreadyResolved, true);
  assert.equal(response.gameStatus, "finished");
  assert.equal(room.game.public.finishReason, "manual");
});

test("게임 노드가 없으면 아무것도 하지 않는다", () => {
  const response = resolveInterruptionFinishNow(
    {players: {}},
    input("a", "someone-1000"),
  );
  assert.equal(response.alreadyResolved, true);
});

// ===== 마감 시각 =====

test("마감 전에도 성공한다(expire가 거부하는 바로 그 조건)", () => {
  const {room, interruption} = stuckLiarsPokerRoom();
  assert.ok(interruption.deadlineAt > 5000, "픽스처가 마감 전이어야 합니다");

  const response = resolveInterruptionFinishNow(
    room,
    input("a", interruption.id, {now: 5000}),
  );

  assert.equal(response.finished, true);
});

test("마감이 지난 뒤에 호출해도 성공한다", () => {
  const {room, interruption} = stuckLiarsPokerRoom();
  const response = resolveInterruptionFinishNow(
    room,
    input("a", interruption.id, {now: interruption.deadlineAt + 500}),
  );

  assert.equal(response.finished, true);
  assert.equal(room.game.public.status, "finished");
});

// ===== canContinue == true 흐름 보존 =====

test("계속할 수 있는 중단은 거부하고 아무것도 바꾸지 않는다", () => {
  // 3인 중 1명 이탈 → 남은 2명 ≥ 최소 2명이므로 투표·제외 흐름의 몫입니다.
  const {room, interruption} = roomWithInterruption({
    game: liarsPokerGame(["leaving", "a", "b"]),
    selectedGame: "liars_poker",
    leaving: "leaving",
    minimum: 2,
  });
  assert.equal(interruption.canContinue, true);
  const revision = room.game.public.revision;

  assert.throws(
    () => resolveInterruptionFinishNow(room, input("a", interruption.id)),
    (error) => error.code === "failed-precondition",
  );

  assert.equal(room.game.public.status, "playing");
  assert.equal(room.game.public.revision, revision);
  assert.equal(room.game.public.interruption.id, interruption.id);
  assert.notEqual(room.players.leaving, undefined);
});

// ===== 권한 =====

test("방과 무관한 사용자는 종료할 수 없다", () => {
  const {room, interruption} = stuckLiarsPokerRoom();
  assert.throws(
    () => resolveInterruptionFinishNow(room, input("stranger", interruption.id)),
    (error) => error.code === "permission-denied",
  );
  assert.equal(room.game.public.status, "playing");
});

test("이탈 당사자는 스스로 종료할 수 없다", () => {
  const {room, interruption} = stuckLiarsPokerRoom();
  assert.throws(
    () => resolveInterruptionFinishNow(room, input("leaving", interruption.id)),
    (error) => error.code === "permission-denied",
  );
});

test("태블릿은 유효한 세션이 있어야 종료할 수 있다", () => {
  const stale = stuckLiarsPokerRoom();
  assert.throws(
    () =>
      resolveInterruptionFinishNow(
        stale.room,
        input(CONTROLLER, stale.interruption.id, {
          controllerSessionId: "22222222-3333-4333-8444-555555555555",
        }),
      ),
    (error) => error.code === "permission-denied",
  );

  const fresh = stuckLiarsPokerRoom();
  const response = resolveInterruptionFinishNow(
    fresh.room,
    input(CONTROLLER, fresh.interruption.id, {
      controllerSessionId: SESSION_ID,
    }),
  );
  assert.equal(response.finished, true);
});

test("남은 사람 전원이 끊겨 투표권자가 없어도 태블릿은 종료할 수 있다", () => {
  const {room, interruption} = stuckLiarsPokerRoom({offline: ["a"]});
  assert.deepEqual(interruption.eligibleVoterUids, []);

  const response = resolveInterruptionFinishNow(
    room,
    input(CONTROLLER, interruption.id, {controllerSessionId: SESSION_ID}),
  );
  assert.equal(response.finished, true);
});

test("투표권자 목록에 없지만 살아 있는 복귀자도 종료할 수 있다", () => {
  // 중단이 시작될 때 끊겨 있어 eligibleVoterUids에 못 들어간 사람입니다.
  const {room, interruption} = stuckLiarsPokerRoom({offline: ["a"]});
  assert.equal(interruption.eligibleVoterUids.includes("a"), false);
  assert.equal(room.game.public.players.a.status, "alive");

  const response = resolveInterruptionFinishNow(
    room,
    input("a", interruption.id),
  );
  assert.equal(response.finished, true);
});

test("controllerUid와 hostUid가 다른 방에서도 진행자가 막히지 않는다", () => {
  const {room, interruption} = stuckLiarsPokerRoom();
  room.hostUid = "human-host";

  const response = resolveInterruptionFinishNow(
    room,
    input(CONTROLLER, interruption.id, {controllerSessionId: SESSION_ID}),
  );
  assert.equal(response.finished, true);
});

// ===== 노드 제거 =====

test("이탈 당사자의 방 노드만 지우고 게임 로스터는 남긴다", () => {
  const {room, interruption} = stuckLiarsPokerRoom();
  resolveInterruptionFinishNow(room, input("a", interruption.id));

  assert.equal(room.players.leaving, undefined);
  assert.notEqual(room.players.a, undefined);
  // 결과 화면이 이 로스터를 그립니다(마피아는 revealedRoles와 키가 맞아야 함).
  assert.notEqual(room.game.public.players.leaving, undefined);
});

// ===== 지원하지 않는 게임 =====

test("종료 함수가 없는 게임은 중단 상태를 남긴 채 거부한다", () => {
  const {room, interruption} = stuckLiarsPokerRoom();
  room.selectedGame = "unknown_game";

  assert.throws(
    () => resolveInterruptionFinishNow(room, input("a", interruption.id)),
    (error) => error.code === "failed-precondition",
  );

  // 중단이 남아 있어야 기존 60초 만료 경로로 되돌아갈 수 있습니다.
  assert.equal(room.game.public.interruption.id, interruption.id);
  assert.equal(room.game.public.status, "playing");
});

test("지원 게임 판정은 종료 함수 표를 유일한 기준으로 쓴다", () => {
  assert.equal(supportsInsufficientPlayerFinish("liars_poker"), true);
  assert.equal(supportsInsufficientPlayerFinish("final_call"), true);
  assert.equal(supportsInsufficientPlayerFinish("mafia"), true);
  assert.equal(supportsInsufficientPlayerFinish("unknown_game"), false);
  assert.equal(supportsInsufficientPlayerFinish(undefined), false);
});

test("디스패처는 알 수 없는 게임에서 false를 돌려주고 상태를 바꾸지 않는다", () => {
  const game = liarsPokerGame(["a", "b"]);
  const room = {selectedGame: "unknown_game", game, players: {}};

  assert.equal(finishGameForInsufficientPlayers(room, 5000), false);
  assert.equal(game.public.status, "playing");
});

// ===== RTDB NaN 방어 =====

test("턴 마감이 없는 구간에서 끝내도 NaN이 생기지 않는다", () => {
  // RTDB는 null을 저장하지 않고 키를 지우므로 다시 읽으면 undefined입니다.
  // 마피아 아침·개표 발표 구간이 실제로 이 상태입니다(2026-08 수정 이력).
  const game = liarsPokerGame(["leaving", "a"]);
  delete game.public.turnDeadlineAt;
  const {room, interruption} = roomWithInterruption({
    game,
    selectedGame: "liars_poker",
    leaving: "leaving",
    minimum: 2,
  });

  const response = resolveInterruptionFinishNow(
    room,
    input("a", interruption.id),
  );

  assert.equal(response.finished, true);
  assert.equal(room.game.public.turnDeadlineAt, null);
  assert.equal(JSON.stringify(room.game).includes("null,null"), false);
  assert.equal(Number.isNaN(room.game.public.updatedAt), false);
  assert.equal(Number.isNaN(room.game.public.revision), false);
  assert.equal(room.game.server.interruption, undefined);
});
