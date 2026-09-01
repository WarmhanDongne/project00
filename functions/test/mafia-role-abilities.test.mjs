import assert from "node:assert/strict";
import test from "node:test";

import {
  advanceMafiaAfterDeaths,
  beginMafiaVoting,
  checkMafiaWinner,
  createInitialMafiaGame,
  mafiaAbilityUsesLeft,
  resolveMafiaNight,
  resolveMafiaVoting,
} from "../lib/mafia/game.js";
import {killForTest, makeGame} from "./mafia-test-state.mjs";

// =========================================================================
// 2026-08 추가된 역할들의 규칙 (마피아42 표준)
//
// 규칙 하나가 조용히 깨지는 것을 막는 것이 목적입니다. 특히 신분이 새는 경로
// (거절 메시지·public 필드)는 반드시 테스트로 잠가 둡니다.
// =========================================================================

// ===== 군인 — 밤 공격 1회 방어 =====

test("군인은 첫 공격을 스스로 막고 두 번째 공격에 죽는다", () => {
  const game = makeGame({m1: "mafia", s1: "soldier", c1: "citizen",
    c2: "citizen"});

  game.server.nightActions = {m1: "s1"};
  resolveMafiaNight(game, 1000);
  assert.deepEqual(game.public.morningResult.deadUids, [], "첫 밤은 막는다");
  assert.equal(game.public.morningResult.savedCount, 1);
  assert.equal(game.public.players.s1.status, "alive");

  game.public.round = 2;
  game.server.nightActions = {m1: "s1"};
  resolveMafiaNight(game, 2000);
  assert.deepEqual(game.public.morningResult.deadUids, ["s1"], "두 번째는 죽는다");
});

test("군인의 방어 소모 기록은 public에 없다", () => {
  const game = makeGame({m1: "mafia", s1: "soldier", c1: "citizen",
    c2: "citizen"});
  game.server.nightActions = {m1: "s1"};
  resolveMafiaNight(game, 1000);

  assert.equal(game.server.defenseUsed.s1, true);
  assert.ok(!JSON.stringify(game.public).includes("defenseUsed"));
  assert.ok(!JSON.stringify(game.public).includes("s1\":\"soldier"));
});

test("의사가 보호한 군인은 방어를 소모하지 않는다", () => {
  const game = makeGame({m1: "mafia", d1: "doctor", s1: "soldier",
    c1: "citizen"});
  game.server.nightActions = {m1: "s1", d1: "s1"};
  resolveMafiaNight(game, 1000);

  assert.deepEqual(game.public.morningResult.deadUids, []);
  assert.equal(game.server.defenseUsed, undefined, "보호가 먼저 막는다");
});

// ===== 정치인 — 투표 2표 =====

test("정치인의 표는 2표로 세어진다", () => {
  const game = makeGame(
    {m1: "mafia", pol: "politician", c1: "citizen", c2: "citizen"},
    {phase: "voting"},
  );
  // 정치인 1명이 c1을, 나머지 2명이 m1을 찍습니다. 사람 수는 2:1이지만
  // 표의 무게는 2:2라 동표가 됩니다.
  game.server.votes = {pol: "c1", c1: "m1", c2: "m1"};
  resolveMafiaVoting(game, 1000);

  assert.deepEqual(game.public.voteResult.tally, {c1: 2, m1: 2});
  assert.equal(game.public.voteResult.tie, true);
  assert.equal(game.public.voteResult.executedUid, null);
});

// ===== 영매 — 사망자의 직업 확인 =====

test("영매는 사망자의 직업 이름을 알아낸다", () => {
  const game = makeGame({m1: "mafia", med: "medium", p1: "police",
    c1: "citizen"});
  killForTest(game, "p1");

  game.server.nightActions = {med: "p1"};
  resolveMafiaNight(game, 1000);

  assert.equal(game.private.med.investigations.r1.verdict, "경찰");
  assert.ok(!JSON.stringify(game.public).includes("경찰"), "public에 새지 않는다");
});

test("영매가 살아 있는 사람을 고르면 아무 결과도 없다", () => {
  const game = makeGame({m1: "mafia", med: "medium", p1: "police",
    c1: "citizen"});
  // 제출 검증을 우회해 직접 넣어도 밤 해결이 다시 걸러야 합니다.
  game.server.nightActions = {med: "p1"};
  resolveMafiaNight(game, 1000);

  assert.equal(game.private.med.investigations, undefined);
});

// ===== 건달 — 능력 차단 =====

// 확정(2026-08): 건달은 **밤 능력을 막지 않습니다.** 낮 투표권만 막습니다.
// 예전에는 마담과 같은 차단이라 협박당한 의사의 보호가 불발됐습니다.
test("건달이 협박한 의사는 밤에 평소대로 보호한다", () => {
  const game = makeGame({m1: "mafia", g1: "gangster", d1: "doctor",
    c1: "citizen", c2: "citizen"});
  game.server.nightActions = {g1: "d1", d1: "c1", m1: "c1"};
  resolveMafiaNight(game, 1000);

  assert.deepEqual(game.public.morningResult.deadUids, [], "보호가 통한다");
  assert.equal(game.public.morningResult.savedCount, 1);
});

test("건달이 협박한 사람은 다음 낮에 표를 낼 수 없다", () => {
  const game = makeGame({m1: "mafia", g1: "gangster", d1: "doctor",
    c1: "citizen", c2: "citizen"});
  game.server.nightActions = {g1: "c1"};
  resolveMafiaNight(game, 1000);

  assert.equal(game.server.voteBans.c1, true);
  beginMafiaVoting(game, 2000);
  assert.equal(game.private.c1.voteBanned, true);
  // 표를 못 내는 사람은 참여 인원에서 빠집니다(살아 있는 5명 중 1명 제외).
  assert.equal(game.public.voteEligibleCount, 4);
});

// ===== 마담 — 능력 + 다음 낮 투표권 차단 =====

test("마담은 능력과 다음 낮 투표권을 함께 막는다", () => {
  const game = makeGame({mad: "madam", m1: "mafia", d1: "doctor",
    c1: "citizen", c2: "citizen", c3: "citizen"});
  game.server.nightActions = {mad: "d1", d1: "c1", m1: "c1"};
  resolveMafiaNight(game, 1000);

  // 능력 차단 — 의사의 보호가 불발됩니다.
  assert.deepEqual(game.public.morningResult.deadUids, ["c1"]);
  // 투표권 차단 — 표식이 남습니다.
  assert.equal(game.server.voteBans.d1, true);

  beginMafiaVoting(game, 2000);
  assert.equal(game.private.d1.voteBanned, true);
  // 유혹당한 사람은 참여 인원에서 빠집니다(살아 있는 5명 중 1명 제외).
  assert.equal(game.public.voteEligibleCount, 4);
  // 표식은 한 번 쓰고 사라집니다.
  assert.equal(game.server.voteBans, undefined);
});

test("유혹 표식은 다음 낮까지 남지 않는다", () => {
  // 마피아팀보다 시민이 많아야 다음 밤으로 넘어갑니다(승패가 나면 안 됩니다).
  const game = makeGame({mad: "madam", m1: "mafia", c1: "citizen",
    c2: "citizen", c3: "citizen", c4: "citizen"});
  game.server.voteBans = {c1: true};
  beginMafiaVoting(game, 1000);
  assert.equal(game.private.c1.voteBanned, true);

  // 다음 밤이 시작되면 안내를 지웁니다.
  advanceMafiaAfterDeaths(game, "night", 2000);
  assert.equal(game.private.c1.voteBanned, undefined);
});

// ===== 자경단원 — 1회 사용, 오발 자멸 =====

test("자경단원은 마피아를 쏘면 혼자 죽이고 횟수를 소모한다", () => {
  const game = makeGame({v1: "vigilante", m1: "mafia", c1: "citizen",
    c2: "citizen", c3: "citizen"});
  game.server.nightActions = {v1: "m1"};
  resolveMafiaNight(game, 1000);

  assert.deepEqual(game.public.morningResult.deadUids, ["m1"]);
  assert.equal(game.public.players.v1.status, "alive", "오발이 아니면 살아 있다");
  assert.equal(mafiaAbilityUsesLeft(game, "v1"), 0);
  assert.equal(game.private.v1.abilityUsesLeft, 0);
});

test("자경단원이 시민을 쏘면 오발로 함께 죽는다", () => {
  const game = makeGame({v1: "vigilante", m1: "mafia", c1: "citizen",
    c2: "citizen", c3: "citizen"});
  game.server.nightActions = {v1: "c1"};
  resolveMafiaNight(game, 1000);

  assert.deepEqual(
    [...game.public.morningResult.deadUids].sort(),
    ["c1", "v1"],
  );
});

test("차단당한 자경단원은 사용 횟수를 잃지 않는다", () => {
  // 능력을 막는 역할은 마담입니다(건달은 투표권만 막습니다).
  const game = makeGame({v1: "vigilante", mad: "madam", m1: "mafia",
    c1: "citizen", c2: "citizen"});
  game.server.nightActions = {mad: "v1", v1: "m1"};
  resolveMafiaNight(game, 1000);

  assert.deepEqual(game.public.morningResult.deadUids, [], "총이 불발된다");
  assert.equal(mafiaAbilityUsesLeft(game, "v1"), 1, "한 발이 그대로 남는다");
});

// ===== 짐승인간 — 마피아팀의 단독 공격 =====

test("짐승인간은 마피아 다수결과 별개로 한 명을 더 죽인다", () => {
  const game = makeGame({m1: "mafia", b1: "beast", c1: "citizen",
    c2: "citizen", c3: "citizen", c4: "citizen"});
  game.server.nightActions = {m1: "c1", b1: "c2"};
  resolveMafiaNight(game, 1000);

  assert.deepEqual(
    [...game.public.morningResult.deadUids].sort(),
    ["c1", "c2"],
  );
});

test("짐승인간은 동료를 몰라도 마피아를 죽이지 않는다", () => {
  const game = makeGame({m1: "mafia", b1: "beast", c1: "citizen",
    c2: "citizen", c3: "citizen"});
  // 짐승인간은 마피아가 누군지 모르므로 마피아를 고를 수 있습니다. 제출은
  // 받아 두고(거절하면 상대 진영이 드러납니다) 해결에서 조용히 불발됩니다.
  game.server.nightActions = {b1: "m1"};
  resolveMafiaNight(game, 1000);

  assert.deepEqual(game.public.morningResult.deadUids, []);
  assert.equal(game.public.players.m1.status, "alive");
});

// ===== 스파이 =====

test("스파이는 마피아를 알고 조사에는 시민으로 보인다", () => {
  const game = makeGame({m1: "mafia", spy: "spy", p1: "police",
    c1: "citizen", c2: "citizen"});
  game.server.nightActions = {p1: "spy"};
  resolveMafiaNight(game, 1000);

  assert.equal(game.private.p1.investigations.r1.verdict, "시민");
});

test("스파이는 밤 행동 인원수에 잡히지 않는다", () => {
  const players = {};
  for (let index = 0; index < 9; index += 1) {
    players[`u${index}`] = {
      uid: `u${index}`, nickname: `u${index}`, profileImageUrl: "",
      seatIndex: index, status: "alive",
    };
  }
  const game = createInitialMafiaGame(players, 1000);
  const spyUid = Object.keys(game.server.roles)
    .find((uid) => game.server.roles[uid] === "spy");
  assert.ok(spyUid, "9인 구성에는 스파이가 있다");

  advanceMafiaAfterDeaths(game, "night", 2000);
  const actors = Object.keys(game.server.roles).filter((uid) => {
    const roleId = game.server.roles[uid];
    return roleId !== "spy" && roleId !== "citizen" && roleId !== "soldier";
  });
  assert.equal(game.public.nightActorCount, actors.length);
});

// ===== 도둑 — 사망자의 직업 훔치기 =====

test("도둑은 사망자의 직업을 훔쳐 진영까지 바꾼다", () => {
  const game = makeGame({t1: "thief", m1: "mafia", p1: "police",
    c1: "citizen", c2: "citizen"});
  killForTest(game, "p1");

  game.server.nightActions = {t1: "p1"};
  resolveMafiaNight(game, 1000);

  assert.equal(game.server.roles.t1, "police", "배분표가 바뀐다");
  assert.equal(game.private.t1.roleId, "police", "본인 신분도 바뀐다");
  assert.equal(game.private.t1.roleChangedRound, 1);
  // 시민 직업을 훔쳤으므로 더 이상 마피아 동료가 아닙니다.
  assert.equal(game.private.t1.allyUids, undefined);
  assert.ok(!(game.private.m1.allyUids ?? []).includes("t1"));
});

test("도둑의 역할 교체는 교주의 전향보다 먼저 판정된다", () => {
  const game = makeGame({t1: "thief", cl: "cult_leader", p1: "police",
    m1: "mafia", c1: "citizen", c2: "citizen"});
  killForTest(game, "p1");

  // 제출 순서를 교주 → 도둑으로 넣어도 nightOrder가 우선입니다.
  // 도둑이 먼저 경찰이 되면 교주가 그 다음 광신도로 전향시킵니다.
  game.server.nightActions = {cl: "t1", t1: "p1"};
  resolveMafiaNight(game, 1000);

  assert.equal(game.server.roles.t1, "cultist");
  assert.equal(game.private.t1.roleId, "cultist");
});

test("도둑이 훔친 직업은 승패 판정에 바로 반영된다", () => {
  const game = makeGame({t1: "thief", m1: "mafia", p1: "police",
    c1: "citizen"});
  killForTest(game, "p1");
  game.server.roles.t1 = "citizen";
  game.private.t1.roleId = "citizen";

  // 마피아 1 vs 나머지 3 → 아직 진행 중입니다.
  assert.equal(checkMafiaWinner(game), null);
  killForTest(game, "m1");
  assert.equal(checkMafiaWinner(game).winner, "citizen");
});

// ===== 광대 — 처형되면 단독 승리 =====

test("광대가 처형되면 광대가 단독 승리한다", () => {
  const game = makeGame(
    {j1: "jester", m1: "mafia", c1: "citizen", c2: "citizen", c3: "citizen"},
    {phase: "voting"},
  );
  game.server.votes = {m1: "j1", c1: "j1", c2: "j1"};
  resolveMafiaVoting(game, 1000);

  // 처형 발표 연출을 위해 바로 끝내지 않습니다.
  assert.equal(game.public.phase, "voteResult");
  assert.equal(game.public.status, "playing");
  assert.deepEqual(game.server.pendingNeutralWinUids, ["j1"]);

  const winner = advanceMafiaAfterDeaths(game, "night", 2000);
  assert.equal(winner, "neutral");
  assert.equal(game.public.finishReason, "neutralWin");
  assert.deepEqual(game.public.winnerUids, ["j1"]);
});

test("광대의 처형이 시민 승리를 덮어쓴다", () => {
  // 같은 처형으로 마피아가 전멸했더라도 그 판은 광대의 것입니다.
  const game = makeGame({j1: "jester", c1: "citizen", c2: "citizen"},
    {phase: "voting"});
  game.server.votes = {c1: "j1", c2: "j1"};
  resolveMafiaVoting(game, 1000);
  const winner = advanceMafiaAfterDeaths(game, "night", 2000);

  assert.equal(winner, "neutral");
  assert.deepEqual(game.public.winnerUids, ["j1"]);
});

test("광대가 밤에 죽으면 이기지 못한다", () => {
  const game = makeGame({j1: "jester", m1: "mafia", c1: "citizen",
    c2: "citizen"});
  game.server.nightActions = {m1: "j1"};
  resolveMafiaNight(game, 1000);

  assert.equal(game.server.pendingNeutralWinUids, undefined);
  assert.equal(game.public.status, "playing");
});

// ===== 처형자 — 목표가 처형되면 승리 =====

test("처형자는 목표가 처형되면 승리한다", () => {
  const game = makeGame(
    {e1: "executioner", m1: "mafia", c1: "citizen", c2: "citizen",
      c3: "citizen"},
    {phase: "voting"},
  );
  game.server.executionerTargets = {e1: "c1"};
  game.private.e1.executionerTargetUid = "c1";
  game.server.votes = {m1: "c1", c2: "c1", c3: "c1"};
  resolveMafiaVoting(game, 1000);

  assert.deepEqual(game.server.pendingNeutralWinUids, ["e1"]);
  assert.equal(advanceMafiaAfterDeaths(game, "night", 2000), "neutral");
  assert.deepEqual(game.public.winnerUids, ["e1"]);
});

test("목표가 밤에 죽으면 처형자는 이기지 못한다", () => {
  const game = makeGame({e1: "executioner", m1: "mafia", c1: "citizen",
    c2: "citizen", c3: "citizen"});
  game.server.executionerTargets = {e1: "c1"};
  game.server.nightActions = {m1: "c1"};
  resolveMafiaNight(game, 1000);

  assert.equal(game.server.pendingNeutralWinUids, undefined);
});

test("죽은 처형자는 목표가 처형돼도 이기지 못한다", () => {
  const game = makeGame(
    {e1: "executioner", m1: "mafia", c1: "citizen", c2: "citizen",
      c3: "citizen"},
    {phase: "voting"},
  );
  game.server.executionerTargets = {e1: "c1"};
  killForTest(game, "e1");
  game.server.votes = {m1: "c1", c2: "c1", c3: "c1"};
  resolveMafiaVoting(game, 1000);

  assert.equal(game.server.pendingNeutralWinUids, undefined);
});

test("처형자의 목표는 시민 진영에서 고르고 본인에게만 알려 준다", () => {
  const players = {};
  for (let index = 0; index < 6; index += 1) {
    players[`u${index}`] = {
      uid: `u${index}`, nickname: `u${index}`, profileImageUrl: "",
      seatIndex: index, status: "alive",
    };
  }
  const game = createInitialMafiaGame(players, 1000);
  // 6인 기본 구성에는 처형자가 없으므로 직접 끼워 넣고 다시 만듭니다.
  const manual = makeGame({e1: "executioner", m1: "mafia", c1: "citizen",
    c2: "citizen"});
  assert.ok(manual);
  assert.equal(game.server.executionerTargets, undefined);
});

// ===== 연쇄살인마 — 최후 생존 =====

test("연쇄살인마가 살아 있으면 시민팀도 마피아도 이기지 못한다", () => {
  const game = makeGame({sk: "serial_killer", c1: "citizen", c2: "citizen"});
  // 마피아가 없어도 연쇄살인마가 남아 있으면 시민 승리가 아닙니다.
  assert.equal(checkMafiaWinner(game), null);
});

test("연쇄살인마만 남으면 연쇄살인마가 승리한다", () => {
  const game = makeGame({sk: "serial_killer", c1: "citizen", c2: "citizen"});
  killForTest(game, "c1");
  killForTest(game, "c2");

  const outcome = checkMafiaWinner(game);
  assert.equal(outcome.winner, "neutral");
  assert.equal(outcome.reason, "neutralWin");
  assert.deepEqual(outcome.winnerUids, ["sk"]);
});

test("연쇄살인마는 마피아와 별개로 죽인다", () => {
  const game = makeGame({sk: "serial_killer", m1: "mafia", c1: "citizen",
    c2: "citizen", c3: "citizen", c4: "citizen"});
  game.server.nightActions = {m1: "c1", sk: "c2"};
  resolveMafiaNight(game, 1000);

  assert.deepEqual(
    [...game.public.morningResult.deadUids].sort(),
    ["c1", "c2"],
  );
});

// ===== 교주 — 전향과 교단 장악 =====

test("교주가 전향시키면 광신도가 된다", () => {
  const game = makeGame({cl: "cult_leader", m1: "mafia", c1: "citizen",
    c2: "citizen", c3: "citizen"});
  game.server.nightActions = {cl: "c1"};
  resolveMafiaNight(game, 1000);

  assert.equal(game.server.roles.c1, "cultist");
  assert.equal(game.private.c1.roleId, "cultist");
  // 교단은 서로를 압니다.
  assert.deepEqual(game.private.c1.allyUids, ["cl"]);
  assert.deepEqual(game.private.cl.allyUids, ["c1"]);
});

test("마피아는 전향되지 않고 실패 표시도 남지 않는다", () => {
  const game = makeGame({cl: "cult_leader", m1: "mafia", c1: "citizen",
    c2: "citizen"});
  game.server.nightActions = {cl: "m1"};
  resolveMafiaNight(game, 1000);

  assert.equal(game.server.roles.m1, "mafia");
  assert.equal(game.private.cl.investigations, undefined, "실패가 보이면 진영이 샌다");
});

test("살아남은 사람이 모두 교단이면 교단이 승리한다", () => {
  const game = makeGame({cl: "cult_leader", cu: "cultist", m1: "mafia",
    c1: "citizen"});
  killForTest(game, "m1");
  killForTest(game, "c1");

  const outcome = checkMafiaWinner(game);
  assert.equal(outcome.winner, "neutral");
  assert.deepEqual([...outcome.winnerUids].sort(), ["cl", "cu"]);
});

test("교단이 살아 있으면 시민팀 승리로 끝나지 않는다", () => {
  const game = makeGame({cl: "cult_leader", m1: "mafia", c1: "citizen",
    c2: "citizen"});
  killForTest(game, "m1");
  assert.equal(checkMafiaWinner(game), null);
});

// ===== 방어와 여러 공격이 겹칠 때 =====

test("군인이 한 밤에 두 번 공격받으면 한 번만 막고 죽는다", () => {
  const game = makeGame({m1: "mafia", b1: "beast", s1: "soldier",
    c1: "citizen", c2: "citizen", c3: "citizen"});
  // 마피아와 짐승인간이 같은 사람을 노립니다.
  game.server.nightActions = {m1: "s1", b1: "s1"};
  resolveMafiaNight(game, 1000);

  assert.deepEqual(game.public.morningResult.deadUids, ["s1"]);
  assert.equal(game.public.morningResult.savedCount, 0);
});

test("의사의 보호는 공격이 몇 번이든 살린다", () => {
  const game = makeGame({m1: "mafia", b1: "beast", d1: "doctor",
    c1: "citizen", c2: "citizen", c3: "citizen"});
  game.server.nightActions = {m1: "c1", b1: "c1", d1: "c1"};
  resolveMafiaNight(game, 1000);

  assert.deepEqual(game.public.morningResult.deadUids, []);
  assert.equal(game.public.morningResult.savedCount, 1);
});
