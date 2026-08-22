import assert from "node:assert/strict";
import test from "node:test";

import {excludeMafiaPlayer} from "../lib/mafia/exclude-player.js";
import {
  advanceMafiaAfterDeaths,
  assignMafiaRoles,
  bumpNightActionCue,
  checkMafiaWinner,
  createInitialMafiaGame,
  mafiaCompositionToUse,
  mafiaInvestigationVerdict,
  resolveMafiaNight,
  resolveMafiaVoting,
} from "../lib/mafia/game.js";
import {mafiaComposition} from "../lib/mafia/validation.js";
import {
  MAFIA_COMPOSITION,
  MAFIA_NIGHT_PHASE_ORDER,
  MAFIA_ROLES,
} from "../lib/mafia/roles.js";
import {makeGame} from "./mafia-test-state.mjs";

const SIX = {
  m1: "mafia",
  p1: "police",
  d1: "doctor",
  c1: "citizen",
  c2: "citizen",
  c3: "citizen",
};

// ===== 역할 배분 =====

test("구성표에 있는 모든 인원에 역할을 배분할 수 있다", () => {
  for (const count of Object.keys(MAFIA_COMPOSITION).map(Number)) {
    const players = {};
    for (let index = 0; index < count; index += 1) {
      players[`u${index}`] = {
        uid: `u${index}`,
        nickname: `u${index}`,
        profileImageUrl: "",
        seatIndex: index,
        status: "alive",
      };
    }
    const roles = assignMafiaRoles(players);
    assert.equal(Object.keys(roles).length, count, `${count}인 배분 인원`);

    // 배분 결과가 구성표와 정확히 같은지 셉니다.
    const counted = {};
    for (const roleId of Object.values(roles)) {
      counted[roleId] = (counted[roleId] ?? 0) + 1;
    }
    assert.deepEqual(counted, MAFIA_COMPOSITION[count], `${count}인 구성`);
  }
});

test("서로를 아는 역할끼리만 동료 목록을 받는다", () => {
  const players = {};
  for (let index = 0; index < 12; index += 1) {
    players[`u${index}`] = {
      uid: `u${index}`,
      nickname: `u${index}`,
      profileImageUrl: "",
      seatIndex: index,
      status: "alive",
    };
  }
  const game = createInitialMafiaGame(players, 1000);
  const roles = game.server.roles;

  for (const [uid, entry] of Object.entries(game.private)) {
    const role = MAFIA_ROLES[roles[uid]];
    // 기대값을 역할 표에서 다시 계산합니다. 구성표가 바뀌어도 이 테스트는
    // 그대로 유효합니다.
    const expected = Object.keys(roles).filter((other) => {
      if (other === uid) return false;
      const otherRole = MAFIA_ROLES[roles[other]];
      return otherRole.knowsAllies && otherRole.faction === role.faction;
    });
    if (!role.knowsAllies || expected.length === 0) {
      assert.equal(entry.allyUids, undefined, `${uid}는 동료를 몰라야 한다`);
      continue;
    }
    assert.deepEqual(
      [...entry.allyUids].sort(),
      expected.sort(),
      `${uid}(${roles[uid]}) 동료 목록`,
    );
    assert.ok(!entry.allyUids.includes(uid), "자신은 동료에 없다");
  }
});

test("살아 있는 사람의 신분은 public에 절대 없다", () => {
  const players = {};
  for (let index = 0; index < 8; index += 1) {
    players[`u${index}`] = {
      uid: `u${index}`,
      nickname: `u${index}`,
      profileImageUrl: "",
      seatIndex: index,
      status: "alive",
    };
  }
  const game = createInitialMafiaGame(players, 1000);

  // 역할 배분표는 server에만 있습니다.
  assert.equal(Object.keys(game.server.roles).length, 8);
  // 아직 아무도 죽지 않았으므로 공개된 신분이 없어야 합니다.
  assert.equal(game.public.revealedRoles, undefined);

  // `gameType: "mafia"`는 역할이 아니라 게임 이름이므로 검사에서 뺍니다.
  const {gameType, ...rest} = game.public;
  assert.equal(gameType, "mafia");
  const serialized = JSON.stringify(rest);
  for (const roleId of new Set(Object.values(game.server.roles))) {
    assert.ok(
      !serialized.includes(`"${roleId}"`),
      `public에 역할 '${roleId}'가 노출됩니다`,
    );
  }
  // uid와 역할이 짝지어 나타나는 곳도 없어야 합니다.
  for (const uid of Object.keys(game.server.roles)) {
    assert.ok(
      !serialized.includes(`"${uid}":"${game.server.roles[uid]}"`),
      `public에 ${uid}의 역할이 노출됩니다`,
    );
  }
});

// ===== 밤 해결 =====

test("보호한 대상은 마피아 공격에서 살아난다", () => {
  const game = makeGame(SIX);
  game.server.nightActions = {m1: "c1", d1: "c1"};
  resolveMafiaNight(game, 2000);

  assert.deepEqual(game.public.morningResult.deadUids, []);
  assert.equal(game.public.morningResult.savedCount, 1);
  assert.equal(game.public.players.c1.status, "alive");
  assert.equal(game.public.phase, "morning");
});

test("보호하지 않은 대상은 사망하고 관전용 신분표를 받는다", () => {
  const game = makeGame(SIX);
  game.server.nightActions = {m1: "c1", d1: "c2"};
  resolveMafiaNight(game, 2000);

  assert.deepEqual(game.public.morningResult.deadUids, ["c1"]);
  assert.equal(game.public.players.c1.status, "dead");
  assert.equal(game.public.players.c1.deathCause, "nightAttack");
  // 사망자만 전원 신분을 봅니다.
  assert.deepEqual(game.private.c1.spectatorRoles, SIX);
  assert.equal(game.private.c2.spectatorRoles, undefined);
  // 밤에 죽은 사람의 신분은 공개하지 않습니다.
  assert.equal(game.public.revealedRoles, undefined);
});

test("마피아가 여러 명이면 다수결로 한 명만 죽인다", () => {
  const roles = {...SIX, c3: "mafia"};
  const game = makeGame(roles);
  // m1과 c3(마피아)이 서로 다른 대상을 고르면 표가 갈립니다.
  game.server.nightActions = {m1: "c1", c3: "c1"};
  resolveMafiaNight(game, 2000);

  assert.deepEqual(game.public.morningResult.deadUids, ["c1"]);
});

test("마피아 표가 갈리면 그중 한 명만 죽는다", () => {
  const roles = {...SIX, c3: "mafia"};
  const game = makeGame(roles);
  game.server.nightActions = {m1: "c1", c3: "c2"};
  resolveMafiaNight(game, 2000);

  // 동표는 무작위로 하나를 고릅니다(확정 규칙). 두 명이 죽지는 않습니다.
  assert.equal(game.public.morningResult.deadUids.length, 1);
  assert.ok(["c1", "c2"].includes(game.public.morningResult.deadUids[0]));
});

test("경찰 조사 결과가 본인 private에만 쌓인다", () => {
  const game = makeGame(SIX);
  game.server.nightActions = {p1: "m1"};
  resolveMafiaNight(game, 2000);

  assert.equal(game.private.p1.investigations.r1.verdict, "마피아");
  assert.equal(game.private.p1.investigations.r1.targetUid, "m1");
  // 다른 사람은 결과를 볼 수 없습니다.
  assert.equal(game.private.c1.investigations, undefined);
  assert.ok(!JSON.stringify(game.public).includes("마피아"));
});

test("마피아 보스는 조사에서 시민으로 보인다", () => {
  assert.equal(mafiaInvestigationVerdict("mafia", false), "마피아");
  assert.equal(mafiaInvestigationVerdict("mafia_boss", false), "시민");
  assert.equal(mafiaInvestigationVerdict("citizen", false), "시민");
  // 조작(프레이머)은 실제 진영을 덮습니다.
  assert.equal(mafiaInvestigationVerdict("citizen", true), "마피아");
});

test("밤 해결 순서가 규칙을 지킨다", () => {
  // 차단이 보호보다, 조사 조작이 조사보다 먼저여야 합니다.
  assert.ok(MAFIA_NIGHT_PHASE_ORDER.roleblock < MAFIA_NIGHT_PHASE_ORDER.protect);
  assert.ok(MAFIA_NIGHT_PHASE_ORDER.frame < MAFIA_NIGHT_PHASE_ORDER.investigate);
  assert.ok(MAFIA_NIGHT_PHASE_ORDER.protect < MAFIA_NIGHT_PHASE_ORDER.mafiaAttack);
});

test("죽은 사람의 밤 행동은 무시한다", () => {
  const game = makeGame(SIX);
  game.public.players.m1.status = "dead";
  game.server.nightActions = {m1: "c1"};
  resolveMafiaNight(game, 2000);

  assert.deepEqual(game.public.morningResult.deadUids, []);
});

// ===== 투표 해결 =====

test("최다 득표자가 처형되고 신분이 공개된다", () => {
  const game = makeGame(SIX, {phase: "voting"});
  game.server.votes = {p1: "m1", d1: "m1", c1: "c2", c2: "m1"};
  resolveMafiaVoting(game, 3000);

  assert.equal(game.public.voteResult.executedUid, "m1");
  assert.equal(game.public.voteResult.tie, false);
  assert.equal(game.public.players.m1.status, "dead");
  assert.equal(game.public.players.m1.deathCause, "execution");
  // 처형자 신분은 공개합니다(확정 규칙).
  assert.equal(game.public.revealedRoles.m1, "mafia");
  assert.equal(game.public.phase, "voteResult");
});

test("동표면 아무도 처형되지 않는다", () => {
  const game = makeGame(SIX, {phase: "voting"});
  game.server.votes = {p1: "m1", d1: "c1"};
  resolveMafiaVoting(game, 3000);

  assert.equal(game.public.voteResult.executedUid, null);
  assert.equal(game.public.voteResult.tie, true);
  assert.equal(game.public.revealedRoles, undefined);
  for (const player of Object.values(game.public.players)) {
    assert.equal(player.status, "alive");
  }
});

test("투표하지 않은 사람은 기권으로 센다", () => {
  const game = makeGame(SIX, {phase: "voting"});
  game.server.votes = {p1: "m1", d1: "m1"};
  resolveMafiaVoting(game, 3000);

  assert.equal(game.public.voteResult.abstainCount, 4);
  assert.deepEqual(game.public.voteResult.tally, {m1: 2});
});

test("아무도 투표하지 않으면 무처형이다", () => {
  const game = makeGame(SIX, {phase: "voting"});
  resolveMafiaVoting(game, 3000);

  assert.equal(game.public.voteResult.executedUid, null);
  assert.equal(game.public.voteResult.tie, false);
  assert.equal(game.public.voteResult.abstainCount, 6);
});

// ===== 발표에 담는 종료 힌트 =====
// 확정(2026-08): 발표가 끝나면 게임이 끝나는 경우, 태블릿이 다음 단계 예고
// ('밤이 되었습니다'·'토론을 시작합니다')를 건너뛰도록 결과에 미리 알립니다.
// 판정 자체는 발표가 끝날 때 advanceMafiaAfterDeaths가 다시 합니다.

test("마피아가 전멸하는 처형이면 개표 결과에 종료를 알린다", () => {
  const game = makeGame(
    {m1: "mafia", c1: "citizen", c2: "citizen"},
    {phase: "voting"},
  );
  game.server.votes = {c1: "m1", c2: "m1"};
  resolveMafiaVoting(game, 3000);

  assert.equal(game.public.voteResult.executedUid, "m1");
  assert.equal(game.public.voteResult.endsGame, true);
  // 발표 중에는 아직 진행 중입니다. 끝내는 것은 발표가 끝난 뒤입니다.
  assert.equal(game.public.phase, "voteResult");

  assert.equal(advanceMafiaAfterDeaths(game, "night", 4000), "citizen");
  assert.equal(game.public.phase, "finished");
});

test("게임이 이어지는 처형이면 종료를 알리지 않는다", () => {
  const game = makeGame(SIX, {phase: "voting"});
  game.server.votes = {p1: "c1", d1: "c1"};
  resolveMafiaVoting(game, 3000);

  assert.equal(game.public.voteResult.executedUid, "c1");
  assert.equal(game.public.voteResult.endsGame, false);
  assert.equal(advanceMafiaAfterDeaths(game, "night", 4000), null);
  assert.equal(game.public.phase, "night");
});

test("밤 사망으로 끝나는 아침이면 아침 결과에 종료를 알린다", () => {
  const game = makeGame(
    {m1: "mafia", c1: "citizen", c2: "citizen"},
    {phase: "night"},
  );
  // 마피아가 한 명을 죽이면 1 대 1이 되어 마피아 승리입니다.
  game.server.nightActions = {m1: "c1"};
  resolveMafiaNight(game, 2000);

  assert.deepEqual(game.public.morningResult.deadUids, ["c1"]);
  assert.equal(game.public.morningResult.endsGame, true);
  assert.equal(game.public.phase, "morning");

  assert.equal(advanceMafiaAfterDeaths(game, "day", 3000), "mafia");
  assert.equal(game.public.phase, "finished");
});

test("게임이 이어지는 아침이면 종료를 알리지 않는다", () => {
  const game = makeGame(SIX, {phase: "night"});
  game.server.nightActions = {m1: "c1"};
  resolveMafiaNight(game, 2000);

  assert.equal(game.public.morningResult.endsGame, false);
  assert.equal(advanceMafiaAfterDeaths(game, "day", 3000), null);
  assert.equal(game.public.phase, "day");
});

// ===== 승패 판정 =====

test("마피아가 모두 죽으면 시민 승리", () => {
  const game = makeGame(SIX);
  game.public.players.m1.status = "dead";
  assert.equal(checkMafiaWinner(game).winner, "citizen");
  assert.equal(checkMafiaWinner(game).reason, "citizenWin");
});

test("마피아 수가 나머지와 같아지면 마피아 승리", () => {
  const game = makeGame(SIX);
  // 마피아 1명, 시민팀 1명만 남김
  game.public.players.p1.status = "dead";
  game.public.players.d1.status = "dead";
  game.public.players.c1.status = "dead";
  game.public.players.c2.status = "dead";
  assert.equal(checkMafiaWinner(game).winner, "mafia");
  assert.equal(checkMafiaWinner(game).reason, "mafiaWin");
});

test("아직 진행 중이면 승자가 없다", () => {
  const game = makeGame(SIX);
  assert.equal(checkMafiaWinner(game), null);
});

test("승자 명단에 상대 진영이 섞이지 않는다", () => {
  const game = makeGame(SIX);
  game.public.players.m1.status = "dead";
  const outcome = checkMafiaWinner(game);
  assert.ok(!outcome.winnerUids.includes("m1"), "마피아가 승자에 없어야 한다");
});

test("끝나면 전원 신분이 공개되고 승리 진영이 채워진다", () => {
  const game = makeGame(SIX);
  game.public.players.m1.status = "dead";
  const winner = advanceMafiaAfterDeaths(game, "day", 4000);

  assert.equal(winner, "citizen");
  assert.equal(game.public.status, "finished");
  assert.equal(game.public.finishReason, "citizenWin");
  assert.deepEqual(game.public.revealedRoles, SIX);
  assert.deepEqual(game.public.winnerUids.sort(), ["c1", "c2", "c3", "d1", "p1"]);
});

test("승패가 안 났으면 다음 단계로 넘어간다", () => {
  const game = makeGame(SIX);
  assert.equal(advanceMafiaAfterDeaths(game, "day", 4000), null);
  assert.equal(game.public.phase, "day");
  assert.ok(game.public.turnDeadlineAt > 4000);

  assert.equal(advanceMafiaAfterDeaths(game, "night", 5000), null);
  assert.equal(game.public.phase, "night");
  assert.equal(game.public.round, 2, "밤으로 넘어가면 라운드가 오른다");
});

// ===== 중도 퇴장 =====

test("마지막 밤 행동자가 빠져도 밤은 마감까지 유지한다", () => {
  // 확정(2026-08): 전원 제출·전원 퇴장 어느 쪽이든 밤을 일찍 끝내지 않습니다.
  const game = makeGame(SIX);
  game.public.nightActorCount = 3;
  game.public.nightSubmittedCount = 2;
  game.server.nightActions = {m1: "c1", p1: "c2"};

  // 아직 안 낸 사람은 의사 한 명뿐. 그 사람이 빠져도 밤은 계속됩니다.
  excludeMafiaPlayer(game, "d1", 6000);

  assert.equal(game.public.players.d1.status, "dead");
  assert.equal(game.public.phase, "night");
  // 남은 사람 기준으로 인원만 다시 셉니다. 해결은 timeout_night 몫입니다.
  assert.equal(game.public.nightActorCount, 2);
  assert.equal(game.public.nightSubmittedCount, 2);
});

test("퇴장으로 인원이 최소치 미달이면 게임을 끝낸다", () => {
  const game = makeGame({m1: "mafia", p1: "police", c1: "citizen", c2: "citizen"});
  excludeMafiaPlayer(game, "c2", 6000);

  assert.equal(game.public.status, "finished");
  assert.equal(game.public.finishReason, "insufficientPlayers");
});

test("투표를 마친 사람 목록은 공개하되 표 내용은 감춘다", () => {
  // 태블릿이 그 좌석에서 투표지가 날아가는 연출을 그리려면 '누가 냈는지'가
  // 필요합니다. '어디에 냈는지'는 server에만 남아야 합니다.
  const game = makeGame(SIX, {phase: "voting"});
  game.server.votes = {c1: "m1", c2: "m1"};
  game.public.voteSubmittedUids = Object.keys(game.server.votes);

  assert.deepEqual(game.public.voteSubmittedUids, ["c1", "c2"]);
  // 공개 상태에는 대상이 어디에도 없습니다.
  assert.equal(JSON.stringify(game.public).includes("voteTarget"), false);

  beginMafiaVoting(game, 7000);
  assert.deepEqual(game.public.voteSubmittedUids, []);
});

test("퇴장한 사람의 표는 개표에서 빠진다", () => {
  const roles = {...SIX, c4: "citizen", c5: "citizen"};
  const game = makeGame(roles, {phase: "voting"});
  game.server.votes = {c4: "m1", c5: "p1"};
  game.public.voteSubmittedCount = 2;

  excludeMafiaPlayer(game, "c4", 6000);

  assert.equal(game.server.votes.c4, undefined);
  assert.equal(game.public.voteSubmittedCount, 1);
});

// ===== 기자·탐정 =====

const WITH_SPECIALS = {
  m1: "mafia",
  p1: "police",
  r1: "reporter",
  t1: "detective",
  c1: "citizen",
  c2: "citizen",
};

test("기자가 지목한 사람의 신분은 살아 있어도 전체 공개된다", () => {
  const game = makeGame(WITH_SPECIALS);
  game.server.nightActions = {r1: "m1"};
  resolveMafiaNight(game, 2000);

  // 경찰과 다릅니다. 모두가 보므로 public에 들어갑니다.
  assert.equal(game.public.revealedRoles.m1, "mafia");
  assert.equal(game.public.players.m1.status, "alive");
  // 지목되지 않은 사람은 공개되지 않습니다.
  assert.equal(game.public.revealedRoles.p1, undefined);
});

test("탐정은 대상이 누구를 골랐는지 알려 준다", () => {
  const game = makeGame(WITH_SPECIALS);
  // 마피아가 c1을 고르고, 탐정이 그 마피아를 추적합니다.
  game.server.nightActions = {m1: "c1", t1: "m1"};
  resolveMafiaNight(game, 2000);

  assert.equal(game.private.t1.investigations.r1.targetUid, "m1");
  assert.equal(game.private.t1.investigations.r1.verdict, "c1");
  // 추적 결과는 본인만 봅니다.
  assert.ok(!JSON.stringify(game.public).includes("investigations"));
});

test("탐정이 아무 행동도 안 한 사람을 추적하면 방문 없음이다", () => {
  const game = makeGame(WITH_SPECIALS);
  game.server.nightActions = {t1: "c1"};
  resolveMafiaNight(game, 2000);

  assert.equal(game.private.t1.investigations.r1.verdict, "방문 없음");
});

test("기자와 탐정이 같은 밤에 함께 동작한다", () => {
  const game = makeGame(WITH_SPECIALS);
  game.server.nightActions = {m1: "c1", p1: "m1", r1: "p1", t1: "m1"};
  resolveMafiaNight(game, 2000);

  assert.deepEqual(game.public.morningResult.deadUids, ["c1"]);
  assert.equal(game.public.revealedRoles.p1, "police");
  assert.equal(game.private.p1.investigations.r1.verdict, "마피아");
  assert.equal(game.private.t1.investigations.r1.verdict, "c1");
});

// ===== 토론 조기 종료 (과반수 투표) =====

import {beginMafiaVoting, beginMafiaDay} from "../lib/mafia/game.js";

test("낮을 시작하면 조기 종료 동의가 초기화된다", () => {
  const game = makeGame(SIX, {phase: "morning"});
  game.server.discussionSkipVotes = {c1: true};
  game.public.discussionSkipCount = 1;
  game.private.c1.discussionSkipVoted = true;

  beginMafiaDay(game, 5000);

  assert.equal(game.public.phase, "day");
  assert.equal(game.public.discussionSkipCount, 0);
  assert.equal(game.server.discussionSkipVotes, undefined);
  assert.equal(game.private.c1.discussionSkipVoted, undefined);
});

test("투표를 시작해도 밤 선택·표가 초기화된다 (기존 규칙 유지 확인)", () => {
  const game = makeGame(SIX, {phase: "day"});
  beginMafiaVoting(game, 5000);
  assert.equal(game.public.phase, "voting");
  assert.equal(game.public.voteEligibleCount, 6);
});

// ===== 제출 즉시 조사 결과 =====

import {recordImmediateInvestigation} from "../lib/mafia/game.js";

test("경찰은 제출한 순간 결과를 받는다", () => {
  const game = makeGame(SIX);
  game.server.nightActions = {p1: "m1"};
  recordImmediateInvestigation(game, "p1", "m1", 1000);

  assert.equal(game.private.p1.investigations.r1.verdict, "마피아");
});

test("탐정의 즉시 결과는 잠정값이고 밤 해결이 최종값으로 덮어쓴다", () => {
  const roles = {...SIX, c3: "detective"};
  const game = makeGame(roles);
  // 탐정이 먼저 제출한 시점에는 마피아가 아직 아무도 안 골랐습니다.
  game.server.nightActions = {c3: "m1"};
  recordImmediateInvestigation(game, "c3", "m1", 1000);
  assert.equal(game.private.c3.investigations.r1.verdict, "방문 없음");

  // 그 뒤 마피아가 c1을 고르고 밤이 끝나면 최종값이 덮어씁니다.
  game.server.nightActions.m1 = "c1";
  resolveMafiaNight(game, 2000);
  assert.equal(game.private.c3.investigations.r1.verdict, "c1");
});

test("일반 시민 제출은 즉시 결과를 만들지 않는다", () => {
  const game = makeGame(SIX);
  game.server.nightActions = {d1: "c1"};
  recordImmediateInvestigation(game, "d1", "c1", 1000);
  assert.equal(game.private.d1.investigations, undefined);
});

// =========================================================================
// 밤 행동 소리 신호
//
// 확정(2026-08): 직업 효과음은 밤이 시작될 때 자동으로 울리지 않고, 그 직업이
// **선택을 완료한 순간** 태블릿에서 울립니다.
// =========================================================================

test("첫 제출에 행동 종류로 소리 신호가 올라간다", () => {
  const game = makeGame(SIX);
  bumpNightActionCue(game, "m1");

  assert.deepEqual(game.public.nightActionCue, {id: 1, action: "eliminate"});
  // 누가 냈는지는 절대 들어가지 않습니다.
  assert.equal(JSON.stringify(game.public.nightActionCue).includes("m1"), false);
});

test("대상을 바꿔 다시 제출하면 신호가 올라가지 않는다", () => {
  const game = makeGame(SIX);
  bumpNightActionCue(game, "m1");
  game.server.nightActions = {m1: "c1"};

  bumpNightActionCue(game, "m1");
  assert.equal(game.public.nightActionCue.id, 1);
});

test("다른 직업이 제출하면 그 직업의 소리로 신호가 올라간다", () => {
  const game = makeGame(SIX);
  bumpNightActionCue(game, "m1");
  game.server.nightActions = {m1: "c1"};

  bumpNightActionCue(game, "p1");
  assert.deepEqual(game.public.nightActionCue, {id: 2, action: "investigate"});
});

test("밤에 할 일이 없는 신분은 신호를 올리지 않는다", () => {
  const game = makeGame(SIX);
  bumpNightActionCue(game, "c1");
  assert.equal(game.public.nightActionCue, undefined);
});

// =========================================================================
// 역할 배치 화면에서 고른 구성
//
// 확정(2026-08): 마피아는 시작 전에 자리 배치 대신 역할 배치를 합니다.
// 서버가 막지 않으면 게임이 시작조차 못 하는 구성이 들어옵니다.
// =========================================================================

test("구성을 보내지 않으면 인원별 추천 표를 쓴다", () => {
  assert.equal(mafiaComposition(undefined, 6), null);
  assert.equal(mafiaComposition(null, 6), null);
});

test("인원과 합이 맞는 구성은 그대로 쓴다", () => {
  const chosen = {mafia: 1, police: 1, doctor: 1, citizen: 3};
  assert.deepEqual(mafiaComposition(chosen, 6), chosen);
});

test("합이 인원과 다르면 거부한다", () => {
  assert.throws(() => mafiaComposition({mafia: 1, citizen: 2}, 6), /맞지 않습니다/);
});

test("이 빌드가 구현하지 않은 역할은 거부한다", () => {
  assert.throws(
    () => mafiaComposition({mafia: 1, vampire: 1, citizen: 4}, 6),
    /쓸 수 없는 역할/,
  );
});

test("마피아가 없거나 전원 마피아면 거부한다", () => {
  assert.throws(() => mafiaComposition({police: 1, citizen: 5}, 6), /마피아가 최소/);
  assert.throws(() => mafiaComposition({mafia: 6}, 6), /마피아만으로는/);
});

test("고른 구성대로 역할이 배분된다", () => {
  const game = makeGame(SIX, {phase: "roleReveal"});
  const roles = assignMafiaRoles(game.public.players, {
    mafia: 2,
    doctor: 1,
    citizen: 3,
  });
  const counts = {};
  for (const roleId of Object.values(roles)) {
    counts[roleId] = (counts[roleId] ?? 0) + 1;
  }
  assert.deepEqual(counts, {mafia: 2, doctor: 1, citizen: 3});
});

test("쓴 구성을 남겨 다시하기가 이어 쓴다", () => {
  const players = {};
  ["u1", "u2", "u3", "u4", "u5", "u6"].forEach((uid, index) => {
    players[uid] = {
      uid,
      nickname: uid,
      profileImageUrl: "",
      seatIndex: index,
      status: "alive",
    };
  });
  const chosen = {mafia: 1, jester: 1, citizen: 4};
  const game = createInitialMafiaGame(players, 1000, chosen);

  // 다시하기가 같은 구성으로 돌 수 있게 남깁니다.
  assert.deepEqual(game.server.composition, chosen);
});

test("인원이 바뀌면 지난 구성 대신 추천 표로 돌아간다", () => {
  // 6인 구성을 5인 판에 그대로 쓰면 자리가 남습니다.
  assert.deepEqual(
    mafiaCompositionToUse(5, {mafia: 1, jester: 1, citizen: 4}),
    MAFIA_COMPOSITION[5],
  );
  // 합이 맞으면 그대로 씁니다.
  const same = {mafia: 1, jester: 1, citizen: 4};
  assert.deepEqual(mafiaCompositionToUse(6, same), same);
});
