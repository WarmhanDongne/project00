import assert from "node:assert/strict";
import test from "node:test";

import {
  beginGameInterruption,
  cancelGameInterruption,
  reconcileGamePlayerConnection,
} from "../lib/game-interruption/state.js";

function room() {
  return {
    players: {
      leaving: {
        nickname: "나간 사람",
        characterId: "frog",
        isConnected: false,
      },
      a: {isConnected: true},
      b: {isConnected: true},
      c: {isConnected: true},
    },
    game: {
      public: {
        status: "playing",
        revision: 3,
        updatedAt: 100,
        turnDeadlineAt: 51000,
        players: {
          leaving: {status: "alive", nickname: "fallback"},
          a: {status: "alive"},
          b: {status: "alive"},
          c: {status: "alive"},
        },
      },
      server: {},
    },
  };
}

test("연결 중단은 턴 시간을 멈추고 남은 접속자의 과반 투표를 만든다", () => {
  const value = room();
  const interruption = beginGameInterruption(
    value,
    "leaving",
    "disconnected",
    1000,
  );

  assert.equal(interruption.playerNickname, "나간 사람");
  assert.equal(interruption.playerCharacterId, "frog");
  assert.equal(interruption.deadlineAt, 61000);
  assert.deepEqual(interruption.eligibleVoterUids, ["a", "b", "c"]);
  assert.equal(interruption.requiredVotes, 2);
  assert.equal(interruption.remainingPlayerCount, 3);
  assert.equal(interruption.minimumPlayerCount, 2);
  assert.equal(interruption.canContinue, true);
  assert.equal(value.game.public.turnDeadlineAt, null);
  assert.equal(value.game.server.interruption.previousTurnRemainingMs, 50000);
});

test("남은 인원이 게임 최소 인원보다 적으면 계속할 수 없다", () => {
  const value = room();
  value.game.public.players.b.status = "eliminated";
  value.game.public.players.c.status = "eliminated";
  const interruption = beginGameInterruption(
    value,
    "leaving",
    "left",
    1000,
    {minimumPlayerCount: 2},
  );

  assert.equal(interruption.remainingPlayerCount, 1);
  assert.equal(interruption.minimumPlayerCount, 2);
  assert.equal(interruption.requiredVotes, 0);
  assert.equal(interruption.canContinue, false);
});

test("연결이 복구되면 중단 상태를 없애고 남은 턴 시간을 복원한다", () => {
  const value = room();
  const interruption = beginGameInterruption(
    value,
    "leaving",
    "disconnected",
    1000,
  );

  assert.equal(cancelGameInterruption(value.game, interruption.id, 4000), true);
  assert.equal(value.game.public.interruption, undefined);
  assert.equal(value.game.server.interruption, undefined);
  assert.equal(value.game.public.turnDeadlineAt, 54000);
});

test("재접속 뒤 늦게 도착한 단절 이벤트는 게임을 다시 멈추지 않는다", () => {
  const value = room();
  value.players.leaving.isConnected = true;

  reconcileGamePlayerConnection(value, "leaving", true, false, 1000);

  assert.equal(value.game.public.interruption, undefined);
  assert.equal(value.game.public.turnDeadlineAt, 51000);
});

test("재접속 확정은 중단 상태와 턴 남은 시간을 복원한다", () => {
  const value = room();
  const interruption = beginGameInterruption(
    value,
    "leaving",
    "disconnected",
    1000,
  );
  value.players.leaving.isConnected = true;

  reconcileGamePlayerConnection(value, "leaving", false, true, 4000);

  assert.equal(value.game.public.interruption, undefined);
  assert.equal(value.game.server.interruption, undefined);
  assert.equal(value.game.public.turnDeadlineAt, 54000);
  assert.ok(interruption);
});
