import assert from "node:assert/strict";
import test from "node:test";

import {applyControllerPauseToTurnTimer} from "../lib/game-interruption/controller-presence.js";
import {
  beginGameInterruption,
  cancelGameInterruption,
} from "../lib/game-interruption/state.js";

//=======================태블릿 단절 중 턴 타이머 정지 (C-14)==============================
// 참가자 단절은 이미 턴 타이머를 멈췄다(beginGameInterruption). 그런데 **태블릿
// 단절에는 서버가 전혀 반응하지 않았다.** 태블릿이 죽어 있는 동안에도 마감은
// 계속 흐르고, 마감이 지난 턴을 해결하는 백스톱을 부르는 곳도 태블릿뿐이라
// 아무도 해결하지 않는다. 돌아와 보면 턴이 한참 지나 있다.

function game({turnDeadlineAt = 51_000, status = "playing"} = {}) {
  return {
    public: {
      status,
      revision: 3,
      updatedAt: 100,
      turnDeadlineAt,
      players: {a: {status: "alive"}, b: {status: "alive"}},
    },
    server: {},
  };
}

test("태블릿이 끊기면 남은 시간을 보관하고 마감을 비운다", () => {
  const state = game({turnDeadlineAt: 51_000});

  const outcome = applyControllerPauseToTurnTimer(state, false, 1000);

  assert.equal(outcome, "paused");
  assert.equal(state.public.turnDeadlineAt, null);
  assert.equal(state.server.controllerPause.previousTurnRemainingMs, 50_000);
});

test("태블릿이 돌아오면 남은 시간부터 다시 흐른다", () => {
  const state = game({turnDeadlineAt: 51_000});
  applyControllerPauseToTurnTimer(state, false, 1000);

  const outcome = applyControllerPauseToTurnTimer(state, true, 90_000);

  assert.equal(outcome, "resumed");
  assert.equal(state.public.turnDeadlineAt, 140_000);
  assert.equal(state.server.controllerPause, undefined);
});

test("진행 중이 아니면 아무것도 하지 않는다", () => {
  for (const status of ["finished", "waiting", "dealing"]) {
    const state = game({status});
    assert.equal(applyControllerPauseToTurnTimer(state, false, 1000), "ignored");
    assert.equal(state.public.turnDeadlineAt, 51_000);
  }
});

test("이미 멈춘 상태에서 다시 끊겨도 남은 시간을 덮어쓰지 않는다", () => {
  // 두 번 보관하면 두 번째가 null(이미 멈춘 상태의 마감)로 덮어써 복구할 값이
  // 사라진다. 트리거는 순간적으로 두 번 뜰 수 있다.
  const state = game({turnDeadlineAt: 51_000});
  applyControllerPauseToTurnTimer(state, false, 1000);

  const outcome = applyControllerPauseToTurnTimer(state, false, 5000);

  assert.equal(outcome, "ignored");
  assert.equal(state.server.controllerPause.previousTurnRemainingMs, 50_000);
});

test("보관한 것이 없으면 복구도 하지 않는다", () => {
  const state = game({turnDeadlineAt: 51_000});
  const outcome = applyControllerPauseToTurnTimer(state, true, 5000);
  assert.equal(outcome, "ignored");
  assert.equal(state.public.turnDeadlineAt, 51_000);
});

test("마감이 없는 구간에서 끊겨도 NaN이 생기지 않는다", () => {
  // 마피아 아침·개표 발표는 turnDeadlineAt이 없는 구간이다. NaN을 쓰면 RTDB가
  // 쓰기를 거부한다(Data returned contains NaN).
  const state = game({turnDeadlineAt: null});

  applyControllerPauseToTurnTimer(state, false, 1000);
  assert.equal(state.server.controllerPause.previousTurnRemainingMs, null);

  applyControllerPauseToTurnTimer(state, true, 90_000);
  assert.equal(state.public.turnDeadlineAt, null);
  assert.ok(!Number.isNaN(state.public.turnDeadlineAt));
});

test("이미 지난 마감은 0으로 보관한다", () => {
  const state = game({turnDeadlineAt: 1000});
  applyControllerPauseToTurnTimer(state, false, 50_000);
  assert.equal(state.server.controllerPause.previousTurnRemainingMs, 0);
});

test("게임 노드가 없어도 던지지 않는다", () => {
  assert.equal(applyControllerPauseToTurnTimer(undefined, false, 1000), "ignored");
});

//=======================참가자 중단과 겹칠 때==============================
// 두 중단은 동시에 일어날 수 있다. 하나의 슬롯을 공유하면 나중에 온 쪽이 앞의
// 남은 시간을 덮어써 복구할 값이 사라진다.

test("참가자 중단이 먼저면 남은 시간은 그쪽이 들고 있는다", () => {
  const room = {
    players: {leaving: {isConnected: false}, a: {}, b: {}},
    game: {
      public: {
        status: "playing",
        revision: 3,
        updatedAt: 100,
        turnDeadlineAt: 51_000,
        players: {
          leaving: {status: "alive"},
          a: {status: "alive"},
          b: {status: "alive"},
        },
      },
      server: {},
    },
  };
  const interruption = beginGameInterruption(room, "leaving", "left", 1000, {
    minimumPlayerCount: 2,
  });
  assert.equal(room.game.server.interruption.previousTurnRemainingMs, 50_000);

  // 그 뒤 태블릿이 끊깁니다. 마감은 이미 null이라 null을 보관합니다.
  applyControllerPauseToTurnTimer(room.game, false, 2000);
  assert.equal(room.game.server.controllerPause.previousTurnRemainingMs, null);
  assert.equal(room.game.server.interruption.previousTurnRemainingMs, 50_000);

  // 태블릿이 먼저 돌아와도 참가자 중단의 남은 시간은 그대로입니다.
  applyControllerPauseToTurnTimer(room.game, true, 3000);
  assert.equal(room.game.public.turnDeadlineAt, null);
  assert.equal(room.game.server.interruption.previousTurnRemainingMs, 50_000);

  // 이탈자가 돌아오면 진짜 남은 시간이 되살아납니다.
  cancelGameInterruption(room.game, interruption.id, 100_000);
  assert.equal(room.game.public.turnDeadlineAt, 150_000);
});

test("태블릿 중단이 먼저면 참가자 중단이 null을 보관한다", () => {
  const room = {
    players: {leaving: {isConnected: false}, a: {}, b: {}},
    game: {
      public: {
        status: "playing",
        revision: 3,
        updatedAt: 100,
        turnDeadlineAt: 51_000,
        players: {
          leaving: {status: "alive"},
          a: {status: "alive"},
          b: {status: "alive"},
        },
      },
      server: {},
    },
  };
  applyControllerPauseToTurnTimer(room.game, false, 1000);
  assert.equal(room.game.server.controllerPause.previousTurnRemainingMs, 50_000);

  const interruption = beginGameInterruption(room, "leaving", "left", 2000, {
    minimumPlayerCount: 2,
  });
  assert.equal(room.game.server.interruption.previousTurnRemainingMs, null);

  // 이탈자가 먼저 돌아와도 태블릿이 들고 있는 남은 시간은 그대로입니다.
  cancelGameInterruption(room.game, interruption.id, 3000);
  assert.equal(room.game.public.turnDeadlineAt, null);
  assert.equal(room.game.server.controllerPause.previousTurnRemainingMs, 50_000);

  applyControllerPauseToTurnTimer(room.game, true, 100_000);
  assert.equal(room.game.public.turnDeadlineAt, 150_000);
});

test("겹친 중단에서도 남은 시간은 정확히 한 곳에만 있다", () => {
  const state = game({turnDeadlineAt: 51_000});
  applyControllerPauseToTurnTimer(state, false, 1000);

  const held = [
    state.server.controllerPause?.previousTurnRemainingMs,
    state.server.interruption?.previousTurnRemainingMs,
  ].filter((value) => typeof value === "number");

  assert.equal(held.length, 1);
});
