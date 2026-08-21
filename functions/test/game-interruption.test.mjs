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

// =========================================================================
// 마감 시각이 **없는 구간**에서 중단이 걸릴 때 (2026-08 실제 오류 재현)
//
// RTDB는 null을 저장하지 않고 키를 지웁니다. 그래서 `turnDeadlineAt = null`로
// 둔 뒤 다시 읽으면 그 키가 **아예 없습니다**(undefined). 이것을 계산에 쓰면
// NaN이 되고 RTDB가 쓰기를 거부해, 실제로 아침·개표 발표 중에 나가면
// `game_mafia_leave_game`이 다음 오류로 실패했습니다.
//
//   transaction failed: Data returned contains NaN in property
//   'rooms.XXXXX.game.server.interruption.previousTurnRemainingMs'
// =========================================================================

test("마감 시각이 없는 구간(아침·개표 발표)에서도 NaN이 되지 않는다", () => {
  const value = room();
  // 마피아 아침·개표 발표 구간을 재현합니다. RTDB에서 읽으면 키가 없습니다.
  delete value.game.public.turnDeadlineAt;

  beginGameInterruption(value, "leaving", "left", 1000);

  const saved = value.game.server.interruption.previousTurnRemainingMs;
  assert.equal(saved, null, "남은 시간이 null이어야 합니다(NaN 금지)");
  assert.equal(Number.isNaN(saved), false);
});

test("보관된 남은 시간이 없어도 복구가 NaN을 만들지 않는다", () => {
  const value = room();
  delete value.game.public.turnDeadlineAt;
  const interruption = beginGameInterruption(value, "leaving", "left", 1000);
  // 저장 뒤 다시 읽은 상태를 재현합니다(null이던 키가 사라집니다).
  delete value.game.server.interruption.previousTurnRemainingMs;

  cancelGameInterruption(value.game, interruption.id, 5000);

  assert.equal(value.game.public.turnDeadlineAt, null);
  assert.equal(Number.isNaN(value.game.public.turnDeadlineAt), false);
});

test("마감 시각이 있으면 남은 시간을 그대로 보관하고 복구한다", () => {
  const value = room();
  const interruption = beginGameInterruption(value, "leaving", "left", 1000);
  assert.equal(value.game.server.interruption.previousTurnRemainingMs, 50000);

  // 복구 시점(5000)부터 남은 시간만큼 다시 갑니다.
  cancelGameInterruption(value.game, interruption.id, 5000);
  assert.equal(value.game.public.turnDeadlineAt, 55000);
});
