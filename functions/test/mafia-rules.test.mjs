import assert from "node:assert/strict";
import test from "node:test";
import {makeGame} from "./mafia-test-state.mjs";
import {
  advanceMafiaTrial, beginMafiaNight, finalizeMafiaInvestigations,
  resolveMafiaNight, resolveMafiaVoting, submitMafiaTrialVote,
} from "../lib/mafia/game.js";
import {assertValidNightTarget} from "../lib/mafia/night.js";
import {excludeMafiaPlayer} from "../lib/mafia/exclude-player.js";
import {mafiaComposition, mafiaRules} from "../lib/mafia/validation.js";

const SIX = {m: "mafia", p: "police", d: "doctor", a: "citizen", b: "citizen", c: "citizen"};
function trialGame(roles = SIX, reveal = "role") {
  const game = makeGame(roles, {phase: "voting"});
  game.public.rules = {trial: true, executionReveal: reveal};
  game.server.votes = {m: "a", p: "a", d: "a"};
  resolveMafiaVoting(game, 1000);
  return game;
}
function verdictGame(roles = SIX, reveal = "role") {
  const game = trialGame(roles, reveal);
  advanceMafiaTrial(game, 31000);
  return game;
}

test("규칙 누락은 기존 즉시 처형·직업 공개이며 잘못된 옵션은 거부한다", () => {
  assert.deepEqual(mafiaRules(undefined), {trial: false, executionReveal: "role"});
  assert.deepEqual(mafiaRules({trial: true, executionReveal: "hidden"}), {trial: true, executionReveal: "hidden"});
  for (const value of [[], "trial", {trial: 1}, {executionReveal: "all"}]) {
    assert.throws(() => mafiaRules(value));
  }
});

test("시작부터 승리하는 구성을 막고 경쟁 중립이 있는 구성은 허용한다", () => {
  assert.throws(() => mafiaComposition({mafia: 3, citizen: 3}, 6), /시작부터/);
  assert.throws(() => mafiaComposition({mafia: 2, spy: 1, citizen: 3}, 6), /시작부터/);
  assert.deepEqual(mafiaComposition({mafia: 2, citizen: 4}, 6), {mafia: 2, citizen: 4});
  assert.ok(mafiaComposition({mafia: 3, citizen: 2, serial_killer: 1}, 6));
  assert.ok(mafiaComposition({mafia: 3, citizen: 2, cult_leader: 1}, 6));
});

test("밤 제출 확정 후 다른 대상과 같은 대상 모두 다시 제출할 수 없다", () => {
  const game = makeGame(SIX);
  assert.doesNotThrow(() => assertValidNightTarget(game, "p", "m"));
  game.server.nightActions = {p: "m"};
  assert.throws(() => assertValidNightTarget(game, "p", "a"), /이미 행동/);
  assert.throws(() => assertValidNightTarget(game, "p", "m"), /이미 행동/);
});

test("차단된 조사자는 잠정 결과를 받지 않으며 예전 잠정값도 지운다", () => {
  const game = makeGame({...SIX, c: "madam"});
  game.server.nightActions = {c: "p", p: "m", m: "a"};
  game.private.p.investigations = {r1: {round: 1, targetUid: "m", verdict: "마피아"}};
  finalizeMafiaInvestigations(game);
  assert.equal(game.private.p.investigations.r1, undefined);
  assert.equal(game.public.players.a.status, "alive");
  assert.equal(game.public.phase, "night");
  assert.equal(game.server.voteBans, undefined);
  resolveMafiaNight(game, 5000);
  assert.equal(game.private.p.investigations.r1, undefined);
  assert.equal(game.public.players.a.status, "dead");
});

test("조사 사전 판정은 전향을 반영하지만 원본 역할·사용 횟수·공개 정보는 바꾸지 않는다", () => {
  const game = makeGame({...SIX, b: "cult_leader", c: "reporter"});
  game.server.nightActions = {b: "a", p: "a", c: "m"};
  const beforeServer = structuredClone(game.server);
  const beforePublic = structuredClone(game.public);
  finalizeMafiaInvestigations(game);
  const finalResult = structuredClone(game.private.p.investigations.r1);
  assert.deepEqual(game.server, beforeServer);
  assert.deepEqual(game.public, beforePublic);
  assert.equal(game.private.a.roleId, "citizen");
  resolveMafiaNight(game, 5000);
  assert.equal(game.server.roles.a, "cultist");
  assert.deepEqual(game.private.p.investigations.r1, finalResult);
});

test("후보가 정해지면 죽이지 않고 변론 30초를 보장한다", () => {
  const game = trialGame();
  assert.equal(game.public.phase, "voting");
  assert.deepEqual(game.public.trial, {stage: "defense", candidateUid: "a"});
  assert.equal(game.public.players.a.status, "alive");
  assert.equal(game.public.turnDeadlineAt, 31000);
  assert.throws(() => submitMafiaTrialVote(game, "m", true, 2000));
  advanceMafiaTrial(game, 30999);
  assert.equal(game.public.trial.stage, "defense");
  advanceMafiaTrial(game, 31000);
  assert.equal(game.public.trial.stage, "verdict");
  assert.equal(game.public.turnDeadlineAt, 61000);
});

test("지목 동률·전원 기권은 변론 없이 무처형이다", () => {
  for (const votes of [{m: "a", p: "b"}, {}]) {
    const game = makeGame(SIX, {phase: "voting"});
    game.public.rules = {trial: true, executionReveal: "role"};
    game.server.votes = votes;
    resolveMafiaVoting(game, 1000);
    assert.equal(game.public.trial, undefined);
    assert.equal(game.public.phase, "voteResult");
    assert.equal(game.public.voteResult.executedUid, null);
  }
});

test("정치인도 찬반에서는 한 표이며 과반 미달·기권은 무처형이다", () => {
  const game = verdictGame({...SIX, p: "politician"});
  for (const uid of ["m", "p", "d"]) submitMafiaTrialVote(game, uid, true, 32000);
  submitMafiaTrialVote(game, "b", false, 32000);
  resolveMafiaVoting(game, 61000);
  assert.equal(game.public.voteResult.executedUid, null);
  assert.deepEqual(game.public.voteResult.verdict, {yes: 3, no: 1});
  assert.equal(game.public.voteResult.abstainCount, 2);
  assert.equal(game.public.voteResult.rejected, true);
  assert.equal(game.public.players.a.status, "alive");
});

test("전원 찬반 제출 시 즉시 개표하고 과반 찬성 후보만 처형한다", () => {
  const game = verdictGame();
  for (const uid of ["m", "p", "d", "a"]) submitMafiaTrialVote(game, uid, true, 32000);
  for (const uid of ["b", "c"]) submitMafiaTrialVote(game, uid, false, 32000);
  assert.equal(game.public.phase, "voteResult");
  assert.equal(game.public.voteResult.executedUid, "a");
  assert.deepEqual(game.public.voteResult.verdict, {yes: 4, no: 2});
  assert.equal(game.public.trial, undefined);
  assert.equal(game.server.trialVotes, undefined);
  assert.equal(game.private.p.trialVote, undefined);
});

test("찬반 중복·사망자·투표 금지·마감 뒤 제출을 거부한다", () => {
  const game = verdictGame();
  submitMafiaTrialVote(game, "m", false, 32000);
  assert.throws(() => submitMafiaTrialVote(game, "m", true, 33000), /이미 투표/);
  game.public.players.p.status = "dead";
  assert.throws(() => submitMafiaTrialVote(game, "p", true, 33000));
  game.private.d.voteBanned = true;
  assert.throws(() => submitMafiaTrialVote(game, "d", true, 33000));
  assert.throws(() => submitMafiaTrialVote(game, "a", true, 61000), /시간이 끝/);
  assert.equal(JSON.stringify(game.public).includes('"trialVotes"'), false);
  assert.equal(game.private.m.trialVote, false);
});

test("투표 금지자는 찬반 과반수 분모에 포함하지 않는다", () => {
  const game = trialGame();
  game.private.c.voteBanned = true;
  advanceMafiaTrial(game, 31000);
  assert.equal(game.public.voteEligibleCount, 5);
  for (const uid of ["m", "p", "d"]) submitMafiaTrialVote(game, uid, true, 32000);
  resolveMafiaVoting(game, 61000);
  assert.equal(game.public.voteResult.executedUid, "a");
});

test("변론 후보 이탈은 무처형으로 진행하고 일반 이탈은 변론 마감을 유지한다", () => {
  const game = trialGame();
  const revision = game.public.revision;
  excludeMafiaPlayer(game, "c", 2000);
  assert.equal(game.public.trial.stage, "defense");
  assert.equal(game.public.turnDeadlineAt, 31000);
  assert.ok(game.public.revision > revision);
  excludeMafiaPlayer(game, "a", 3000);
  assert.equal(game.public.phase, "voteResult");
  assert.equal(game.public.voteResult.executedUid, null);
});

test("찬반 투표자 이탈 시 표를 지우고 남은 유권자로 개표한다", () => {
  const game = verdictGame();
  for (const uid of ["m", "p", "d"]) submitMafiaTrialVote(game, uid, true, 32000);
  for (const uid of ["b", "c"]) submitMafiaTrialVote(game, uid, false, 32000);
  excludeMafiaPlayer(game, "c", 33000);
  assert.equal(game.public.voteSubmittedCount, 4);
  assert.equal(game.public.voteEligibleCount, 5);
  submitMafiaTrialVote(game, "a", false, 34000);
  assert.deepEqual(game.public.voteResult.verdict, {yes: 3, no: 2});
  assert.equal(game.public.voteResult.executedUid, "a");
});

for (const reveal of ["role", "faction", "hidden"]) {
  test(`처형 공개 ${reveal}: 서버 공개 데이터와 관전 정보 경계를 지킨다`, () => {
    const game = makeGame(SIX, {phase: "voting"});
    game.public.rules = {trial: false, executionReveal: reveal};
    game.server.votes = {m: "p", a: "p"};
    resolveMafiaVoting(game, 1000);
    assert.equal(game.public.revealedRoles?.p, reveal === "role" ? "police" : undefined);
    assert.equal(game.public.revealedFactions?.p, reveal === "faction" ? "citizen" : undefined);
    assert.equal(game.private.p.spectatorRoles.m, "mafia");
    assert.equal(game.private.a.spectatorRoles, undefined);
    assert.equal(game.public.voteResult.executedUid, "p");
  });
}

test("기자 공개는 비공개 처형 설정에서도 유지된다", () => {
  const game = makeGame(SIX, {phase: "voting"});
  game.public.rules = {trial: false, executionReveal: "hidden"};
  game.public.revealedRoles = {p: "police"};
  game.server.votes = {m: "p"};
  resolveMafiaVoting(game, 1000);
  assert.equal(game.public.revealedRoles.p, "police");
});

test("광대는 찬반 부결로 이기지 않으며 실제 처형 때만 승리한다", () => {
  for (const execute of [false, true]) {
    const game = verdictGame({...SIX, a: "jester"});
    for (const uid of Object.keys(SIX)) submitMafiaTrialVote(game, uid, execute, 32000);
    assert.deepEqual(game.server.pendingNeutralWinUids, execute ? ["a"] : undefined);
  }
});

test("새 밤은 재판 private 및 server 선택을 초기화한다", () => {
  const game = verdictGame();
  submitMafiaTrialVote(game, "m", true, 32000);
  beginMafiaNight(game, 62000);
  assert.equal(game.public.trial, undefined);
  assert.equal(game.private.m.trialVote, undefined);
  assert.equal(game.server.nominationTally, undefined);
  assert.equal(game.server.trialVotes, undefined);
});
