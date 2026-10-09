import assert from "node:assert/strict";
import test from "node:test";
import {applyRecoveryReport, beginRecoveryPause, expireRecoveryCauses, extendRecoveryCause,
  registerRecoveryFailure, tryResumeRecovery} from "../lib/game-interruption/recovery-state.js";

function fixture(deadline = 20000) {
  const room = {roomInstanceId: "room-one", status: "playing", controllerUid: "t",
    controllerCurrentConnectionId: "ct", controllerConnectionSeq: 1,
    players: {}, connections: {},
    game: {public: {gameType: "liars_poker", phase: "playing", status: "playing", revision: 1,
      gameInstanceId: "game-one", phaseSeq: 1, turnSeq: 1, dataSeq: 1, resumeEpoch: 0,
      turnDeadlineAt: deadline, updatedAt: 0, players: {}}, private: {}, server: {}}};
  for (const uid of ["t", "a", "b"]) {
    room.connections[uid] = {[`c${uid}`]: {roomInstanceId: "room-one", connectionSeq: 1,
      connected: true, lastSeen: 0, ...(uid === "t" ? {} : {membershipId: `member-${uid}`})}};
    if (uid !== "t") {
      room.players[uid] = {status: "active", membershipId: `member-${uid}`,
        currentConnectionId: `c${uid}`, connectionSeq: 1};
      room.game.public.players[uid] = {status: "alive"};
      room.game.private[uid] = {hand: [], _context: {gameInstanceId: "game-one", phaseSeq: 1, turnSeq: 1, dataSeq: 1}};
    }
  }
  return room;
}
function report(room, uid, seq = 1, state = "ready", context = true) {
  const pub = room.game.public;
  return applyRecoveryReport(room, {uid, role: uid === "t" ? "controller" : "player",
    roomInstanceId: "room-one", membershipId: `member-${uid}`, connectionId: `c${uid}`,
    connectionSeq: 1, reportSeq: seq, state, screenUsable: true, assetsReady: true,
    gameInstanceId: pub.gameInstanceId,
    ...(context ? {gameInstanceId: pub.gameInstanceId, phaseSeq: pub.phaseSeq,
      turnSeq: pub.turnSeq, dataSeq: pub.dataSeq, resumeEpoch: pub.resumeEpoch} : {})}, 5000);
}

test("다중 단절은 시간·마감을 한 번만 보관하고 마지막 필수 준비 뒤 재개한다", () => {
  const room = fixture();
  registerRecoveryFailure(room, "a", "player", 1000);
  const firstCause = structuredClone(room.game.public.recovery.causes["player:a"]);
  registerRecoveryFailure(room, "b", "player", 2000);
  registerRecoveryFailure(room, "t", "controller", 3000);
  assert.equal(room.game.server.recovery.timer.remainingMs, 19000);
  assert.deepEqual(room.game.public.recovery.causes["player:a"], firstCause);
  assert.equal(tryResumeRecovery(room, 4000), false, "connected만 true인 상태는 준비 증거 아님");
  report(room, "a"); report(room, "t");
  assert.equal(room.game.public.recovery.paused, true);
  report(room, "b");
  assert.equal(room.game.public.recovery.paused, false);
  assert.equal(room.game.public.turnDeadlineAt, 24000);
});

test("추가 단절은 정상 기기의 같은 barrier 준비를 무효화하지 않는다", () => {
  const room = fixture(); beginRecoveryPause(room, 1000); report(room, "a");
  const epoch = room.game.public.resumeEpoch;
  registerRecoveryFailure(room, "b", "player", 2000);
  assert.equal(room.game.public.resumeEpoch, epoch);
  report(room, "b"); report(room, "t");
  assert.equal(room.game.public.recovery.paused, false);
});

test("failed는 최신 데이터 없이 수락하고 늦은 ready와 잘못된 높은 ready를 막는다", () => {
  const room = fixture();
  report(room, "a", 3, "failed", false);
  assert.equal(report(room, "a", 2).status, "ignored");
  assert.equal(report(room, "a", 4, "ready", false).status, "staleContext");
  assert.ok(room.game.public.recovery.causes["player:a"]);
  assert.equal(report(room, "a", 3).status, "ignored");
  report(room, "a", 5); report(room, "b"); report(room, "t");
  assert.equal(room.game.public.recovery.paused, false);
});

test("만료는 선택 상태만 만들고 한 번 연장은 서버 수락 시점에서 30초다", () => {
  const room = fixture(); registerRecoveryFailure(room, "a", "player", 1000);
  const incident = room.game.public.recovery.causes["player:a"].incidentId;
  assert.equal(expireRecoveryCauses(room, 61000), 1);
  assert.equal(room.game.public.status, "playing");
  assert.ok(room.players.a);
  assert.deepEqual(extendRecoveryCause(room, "a", incident, 70000), {status: "extended", deadlineAt: 100000});
  assert.equal(extendRecoveryCause(room, "a", incident, 100001).status, "notAllowed");
  assert.equal(expireRecoveryCauses(room, 100000), 1);
  assert.ok(room.players.a);
});

test("0과 마감 없음은 서로 다르게 보존되며 finished는 재개하지 않는다", () => {
  for (const deadline of [0, null, undefined]) {
    const room = fixture(deadline === undefined ? null : deadline);
    if (deadline === undefined) delete room.game.public.turnDeadlineAt;
    beginRecoveryPause(room, 1000);
    report(room, "a"); report(room, "b"); report(room, "t");
    assert.equal(room.game.public.turnDeadlineAt, deadline === 0 ? 5000 : null);
    room.game.public.status = "finished";
    assert.equal(tryResumeRecovery(room, 9000), false);
  }
});

test("dealing의 private 부재·죽은 참가자는 전체 barrier를 막지 않는다", () => {
  const room = fixture(); room.game.public.phase = "dealing"; room.game.private = {};
  room.game.public.players.b.status = "eliminated";
  assert.equal(registerRecoveryFailure(room, "b", "player", 1000), "localOnly");
  beginRecoveryPause(room, 1000); report(room, "a"); report(room, "t");
  assert.equal(room.game.public.recovery.paused, false);
});

function rtdbRoundTrip(value) {
  if(value===null||value===undefined)return undefined;
  if(typeof value!=='object')return value;
  const next=Object.fromEntries(Object.entries(value).map(([key,item])=>[key,rtdbRoundTrip(item)]).filter(([,item])=>item!==undefined));
  return Object.keys(next).length?next:undefined;
}
test('RTDB removal of null and empty maps preserves the initial barrier and timer none/zero distinction',()=>{
  for(const deadline of [null,1000]){
    let room=fixture(deadline);room.game.server.other='keep';beginRecoveryPause(room,1000);
    room=rtdbRoundTrip(room);
    assert.equal(room.game.public.recovery.causes,undefined);assert.equal(room.game.server.recovery.ready,undefined);
    assert.equal(tryResumeRecovery(room,2000),false);
    report(room,'t');room=rtdbRoundTrip(room);report(room,'a');room=rtdbRoundTrip(room);report(room,'b');
    assert.equal(room.game.public.recovery.paused,false);
    assert.equal(room.game.public.turnDeadlineAt,deadline===null?null:5000);
  }
});
test('RTDB missing cause/ready maps accept a later disconnect and preserve the original timer',()=>{
  let room=fixture();beginRecoveryPause(room,1000);room=rtdbRoundTrip(room);
  assert.equal(registerRecoveryFailure(room,'a','player',2000),'paused');
  assert.equal(room.game.server.recovery.timer.remainingMs,19000);
  assert.ok(room.game.public.recovery.causes['player:a']);
});
