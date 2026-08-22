import assert from "node:assert/strict";
import test from "node:test";

import {
  advanceMafiaNightStage,
  beginMafiaNight,
  beginMafiaNightStage,
  canActInNightStage,
  resolveMafiaNight,
  resolveMafiaVoting,
} from "../lib/mafia/game.js";
import {
  MAFIA_NIGHT_ACTION_MS,
  MAFIA_NIGHT_BLOCK_MS,
  MAFIA_NIGHT_WAIT_MS,
} from "../lib/mafia/types.js";
import {makeGame} from "./mafia-test-state.mjs";

// =========================================================================
// 밤의 두 구간 (확정 2026-08)
//
// 마담이 막은 사람의 능력은 무효라, **마담 판정이 끝나야** 뒤 역할들의 행동이
// 의미를 가집니다. 그래서 밤을 `block → action → wrapUp`으로 나눕니다.
//
//   block   능력을 막는 역할만 고릅니다(1분)
//   action  그 밖의 밤 역할이 고릅니다(1분)
//   wrapUp  아무도 못 고릅니다. 아침까지 10초
//
// 앞 구간이 일찍 끝나면 남은 시간을 버리고 곧바로 다음 구간을 엽니다.
// =========================================================================

const WITH_MADAM = {
  mad: "madam", m1: "mafia", p1: "police", d1: "doctor",
  c1: "citizen", c2: "citizen",
};

test("마담이 있으면 밤은 차단 구간으로 시작한다", () => {
  const game = makeGame(WITH_MADAM, {phase: "roleReveal"});
  beginMafiaNight(game, 1000);

  assert.equal(game.public.phase, "night");
  assert.equal(game.public.nightStage, "block");
  assert.equal(game.public.turnDeadlineAt, 1000 + MAFIA_NIGHT_BLOCK_MS);
  // 이번 구간에 기다리는 사람은 마담 한 명입니다.
  assert.equal(game.public.nightStageActorCount, 1);
  assert.equal(game.public.nightStageSubmittedCount, 0);
  // 밤 전체 인원은 그대로 셉니다(마담·마피아·경찰·의사).
  assert.equal(game.public.nightActorCount, 4);
});

test("차단 구간에는 마담만 고를 수 있다", () => {
  const game = makeGame(WITH_MADAM, {phase: "roleReveal"});
  beginMafiaNight(game, 1000);

  assert.equal(canActInNightStage(game, "mad"), true);
  assert.equal(canActInNightStage(game, "m1"), false);
  assert.equal(canActInNightStage(game, "p1"), false);
});

test("마담이 일찍 고르면 남은 시간을 버리고 행동 구간이 열린다", () => {
  const game = makeGame(WITH_MADAM, {phase: "roleReveal"});
  beginMafiaNight(game, 1000);

  game.server.nightActions = {mad: "d1"};
  const advanced = advanceMafiaNightStage(game, 5000);

  assert.equal(advanced, true);
  assert.equal(game.public.nightStage, "action");
  assert.equal(game.public.turnDeadlineAt, 5000 + MAFIA_NIGHT_ACTION_MS);
  // 이제 마담을 뺀 세 명을 기다립니다.
  assert.equal(game.public.nightStageActorCount, 3);
  assert.equal(canActInNightStage(game, "m1"), true);
});

test("마담이 없는 판은 곧바로 행동 구간으로 시작한다", () => {
  const game = makeGame({m1: "mafia", p1: "police", c1: "citizen",
    c2: "citizen"}, {phase: "roleReveal"});
  beginMafiaNight(game, 1000);

  assert.equal(game.public.nightStage, "action");
  assert.equal(game.public.turnDeadlineAt, 1000 + MAFIA_NIGHT_ACTION_MS);
  assert.equal(game.public.nightStageActorCount, 2);
});

test("밤에 아무도 행동하지 않는 판은 곧바로 마무리 구간이 된다", () => {
  // 스파이는 밤에 하는 일이 없습니다.
  const game = makeGame({m1: "mafia", s1: "spy", c1: "citizen"},
    {phase: "roleReveal"});
  game.server.roles.m1 = "citizen";
  beginMafiaNight(game, 1000);

  assert.equal(game.public.nightStage, "wrapUp");
  assert.equal(game.public.turnDeadlineAt, 1000 + MAFIA_NIGHT_WAIT_MS);
});

test("행동할 사람이 전원 제출하면 10초 뒤 아침이 온다", () => {
  const game = makeGame(WITH_MADAM, {phase: "roleReveal"});
  beginMafiaNight(game, 1000);
  game.server.nightActions = {mad: "d1"};
  advanceMafiaNightStage(game, 2000);

  game.server.nightActions.m1 = "c1";
  game.server.nightActions.p1 = "m1";
  assert.equal(advanceMafiaNightStage(game, 3000), false, "의사가 남았다");

  game.server.nightActions.d1 = "c2";
  assert.equal(advanceMafiaNightStage(game, 4000), true);
  assert.equal(game.public.nightStage, "wrapUp");
  assert.equal(game.public.turnDeadlineAt, 4000 + MAFIA_NIGHT_WAIT_MS);
  // 마무리 구간에는 아무도 고를 수 없습니다.
  assert.equal(canActInNightStage(game, "m1"), false);
});

test("죽은 사람은 구간 인원에서 빠진다", () => {
  const game = makeGame(WITH_MADAM, {phase: "roleReveal"});
  game.public.players.d1.status = "dead";
  beginMafiaNight(game, 1000);
  game.server.nightActions = {mad: "c1"};
  advanceMafiaNightStage(game, 2000);

  // 의사가 죽었으므로 마피아·경찰 둘만 기다립니다.
  assert.equal(game.public.nightStageActorCount, 2);
});

test("구간 값은 아침이 되면 지워진다", () => {
  const game = makeGame(WITH_MADAM, {phase: "roleReveal"});
  beginMafiaNight(game, 1000);
  beginMafiaNightStage(game, "wrapUp", 2000);
  resolveMafiaNight(game, 3000);

  assert.equal(game.public.phase, "morning");
  assert.equal(game.public.nightStage, undefined);
  assert.equal(game.public.nightStageActorCount, undefined);
  assert.equal(game.public.nightStageSubmittedCount, undefined);
});

test("구간 값에 누가 무엇인지 드러나지 않는다", () => {
  const game = makeGame(WITH_MADAM, {phase: "roleReveal"});
  beginMafiaNight(game, 1000);
  const text = JSON.stringify(game.public);

  assert.ok(!text.includes("madam"), "역할 이름이 public에 없다");
  assert.ok(!text.includes("mad\":\""), "누가 마담인지 없다");
});

// =========================================================================
// 개표 (확인 요청 2026-08)
//
// 표는 무게를 반영하고(정치인 2표), 동표면 아무도 처형하지 않으며, 기권 인원이
// 남습니다. 누가 누구를 찍었는지는 개표 결과에 들어가지 않습니다.
// =========================================================================

test("개표는 표 무게를 반영하고 최다 득표자를 처형한다", () => {
  const game = makeGame({pol: "politician", m1: "mafia", c1: "citizen",
    c2: "citizen", c3: "citizen"}, {phase: "voting"});
  // 정치인 1명이 c1에게(2표), 시민 둘이 m1에게(1+1표) → 동표 2:2.
  game.server.votes = {pol: "c1", c1: "m1", c2: "m1"};
  resolveMafiaVoting(game, 1000);

  assert.deepEqual(game.public.voteResult.tally, {c1: 2, m1: 2});
  assert.equal(game.public.voteResult.tie, true);
  assert.equal(game.public.voteResult.executedUid, null);
  // 5명 중 3명이 냈으니 기권 2명입니다.
  assert.equal(game.public.voteResult.abstainCount, 2);
});

test("최다 득표가 한 명이면 그 사람이 처형되고 신분이 공개된다", () => {
  const game = makeGame({m1: "mafia", c1: "citizen", c2: "citizen",
    c3: "citizen"}, {phase: "voting"});
  game.server.votes = {c1: "m1", c2: "m1", c3: "m1", m1: "c1"};
  resolveMafiaVoting(game, 1000);

  assert.equal(game.public.voteResult.executedUid, "m1");
  assert.equal(game.public.voteResult.tie, false);
  assert.equal(game.public.voteResult.abstainCount, 0);
  assert.equal(game.public.players.m1.status, "dead");
  assert.equal(game.public.players.m1.deathCause, "execution");
  // 처형된 사람의 신분만 공개됩니다.
  assert.equal(game.public.revealedRoles.m1, "mafia");
  assert.equal(game.public.revealedRoles.c1, undefined);
});

test("개표 결과에 누가 찍었는지는 남지 않는다", () => {
  const game = makeGame({m1: "mafia", c1: "citizen", c2: "citizen"},
    {phase: "voting"});
  game.server.votes = {c1: "m1", c2: "m1"};
  resolveMafiaVoting(game, 1000);

  assert.equal(game.server.votes, undefined, "표는 개표 뒤 지워진다");
  assert.deepEqual(Object.keys(game.public.voteResult), [
    "tally", "executedUid", "tie", "abstainCount", "endsGame", "resolvedAt",
  ]);
});
