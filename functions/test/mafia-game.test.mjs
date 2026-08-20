import assert from "node:assert/strict";
import test from "node:test";

import {excludeMafiaPlayer} from "../lib/mafia/exclude-player.js";
import {
  advanceMafiaAfterDeaths,
  assignMafiaRoles,
  checkMafiaWinner,
  createInitialMafiaGame,
  mafiaInvestigationVerdict,
  resolveMafiaNight,
  resolveMafiaVoting,
} from "../lib/mafia/game.js";
import {MAFIA_COMPOSITION, MAFIA_NIGHT_PHASE_ORDER} from "../lib/mafia/roles.js";

/** 역할만 정해 주면 나머지는 채워 주는 시험용 상태입니다. */
function makeGame(roleMap, {phase = "night", round = 1} = {}) {
  const players = {};
  Object.keys(roleMap).forEach((uid, index) => {
    players[uid] = {
      uid,
      nickname: uid,
      profileImageUrl: "",
      seatIndex: index,
      status: "alive",
    };
  });
  const privateState = {};
  for (const uid of Object.keys(roleMap)) {
    privateState[uid] = {roleId: roleMap[uid]};
  }
  return {
    public: {
      gameType: "mafia",
      status: "playing",
      phase,
      round,
      revision: 1,
      turnDeadlineAt: null,
      players,
      roleRevealedUids: [],
      nightSubmittedCount: 0,
      nightActorCount: 0,
      discussionSkipCount: 0,
      voteSubmittedCount: 0,
      voteEligibleCount: Object.keys(roleMap).length,
      winner: null,
      winnerUids: [],
      startedAt: 0,
      updatedAt: 0,
    },
    private: privateState,
    server: {roles: {...roleMap}},
  };
}

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

test("마피아는 서로를 알고 시작하고 시민은 모른다", () => {
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
  // 12인 구성은 보스 1 + 마피아 2 = 3명이므로 서로 2명씩 압니다.
  for (const [uid, entry] of Object.entries(game.private)) {
    const faction = game.server.roles[uid] === "mafia" ||
      game.server.roles[uid] === "mafia_boss" ? "mafia" : "citizen";
    if (faction === "mafia") {
      assert.equal(entry.allyUids.length, 2, `${uid} 동료 수`);
      assert.ok(!entry.allyUids.includes(uid), "자신은 동료에 없다");
    } else {
      assert.equal(entry.allyUids, undefined, `${uid}는 동료를 몰라야 한다`);
    }
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

// ===== 승패 판정 =====

test("마피아가 모두 죽으면 시민 승리", () => {
  const game = makeGame(SIX);
  game.public.players.m1.status = "dead";
  assert.equal(checkMafiaWinner(game), "citizen");
});

test("마피아 수가 나머지와 같아지면 마피아 승리", () => {
  const game = makeGame(SIX);
  // 마피아 1명, 시민팀 1명만 남김
  game.public.players.p1.status = "dead";
  game.public.players.d1.status = "dead";
  game.public.players.c1.status = "dead";
  game.public.players.c2.status = "dead";
  assert.equal(checkMafiaWinner(game), "mafia");
});

test("아직 진행 중이면 승자가 없다", () => {
  const game = makeGame(SIX);
  assert.equal(checkMafiaWinner(game), null);
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

test("마지막 밤 행동자가 빠지면 그 자리에서 밤을 해결한다", () => {
  const game = makeGame(SIX);
  game.public.nightActorCount = 3;
  game.public.nightSubmittedCount = 2;
  game.server.nightActions = {m1: "c1", p1: "c2"};

  // 아직 안 낸 사람은 의사 한 명뿐. 그 사람이 빠지면 남은 사람이 다 낸 셈입니다.
  excludeMafiaPlayer(game, "d1", 6000);

  assert.equal(game.public.players.d1.status, "dead");
  assert.equal(game.public.phase, "morning");
  assert.deepEqual(game.public.morningResult.deadUids, ["c1"]);
});

test("퇴장으로 인원이 최소치 미달이면 게임을 끝낸다", () => {
  const game = makeGame({m1: "mafia", p1: "police", c1: "citizen", c2: "citizen"});
  excludeMafiaPlayer(game, "c2", 6000);

  assert.equal(game.public.status, "finished");
  assert.equal(game.public.finishReason, "insufficientPlayers");
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
