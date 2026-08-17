import assert from "node:assert/strict";
import test from "node:test";

import {
  beginGameInterruption,
  cancelGameInterruption,
} from "../lib/game-interruption/state.js";

function room() {
  return {
    players: {
      leaving: {
        nickname: "나간 사람",
        profileImageUrl: "https://example.com/profile.png",
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
  assert.equal(interruption.deadlineAt, 61000);
  assert.deepEqual(interruption.eligibleVoterUids, ["a", "b", "c"]);
  assert.equal(interruption.requiredVotes, 2);
  assert.equal(value.game.public.turnDeadlineAt, null);
  assert.equal(value.game.server.interruption.previousTurnRemainingMs, 50000);
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

