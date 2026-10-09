import assert from "node:assert/strict";
import test from "node:test";

import {
  allocateRoomConnection,
  assertRoomTarget,
  applyRoomPresence,
  recordRoomOperation,
  roomOperationResult,
  leaveRoomMembership,
} from "../lib/room/session-contract.js";

function fixture() {
  return {
    roomInstanceId: "room-one", status: "waiting", controllerUid: "tablet",
    players: {a: {membershipId: "member-a", status: "active", role: "player"}},
  };
}
function connect(room, overrides = {}) {
  return allocateRoomConnection(room, {
    uid: "a", role: "player", operationId: "join-operation",
    roomInstanceId: "room-one", membershipId: "member-a",
    expectedConnectionSeq: 0, connectionId: "connection-one", now: 1000,
    ...overrides,
  });
}

test("동일 복구 작업은 동일 접속을 반환하고 CAS가 옛 작업을 차단한다", () => {
  const room = fixture();
  const first = connect(room);
  assert.deepEqual(connect(room, {connectionId: "unused", now: 2000}), first);
  const second = connect(room, {operationId: "next-operation", expectedConnectionSeq: 1,
    connectionId: "connection-two", now: 3000});
  assert.equal(second.connectionSeq, 2);
  assert.throws(() => connect(room, {operationId: "late-operation"}), /접속/);
  assert.equal(room.players.a.currentConnectionId, "connection-two");
  assert.deepEqual(connect(room), first, "응답 유실 작업의 기존 결과 보존");
  assert.equal(room.players.a.currentConnectionId, "connection-two");
});

test("옛 onDisconnect와 heartbeat는 새 접속과 재가입을 변경하지 않는다", () => {
  const room = fixture();
  connect(room);
  connect(room, {operationId: "next-operation", expectedConnectionSeq: 1,
    connectionId: "connection-two"});
  room.connections.a["connection-one"].connected = false;
  assert.equal(applyRoomPresence(room, "a", "connection-one"), false);
  assert.equal(room.players.a.isConnected, true);
  room.connections.a["connection-two"].connected = false;
  assert.equal(applyRoomPresence(room, "a", "connection-two"), true);
  assert.equal(room.players.a.isConnected, false);
  room.players.a.membershipId = "member-new";
  room.connections.a["connection-two"].connected = true;
  assert.equal(applyRoomPresence(room, "a", "connection-two"), false);
});

test("같은 작업 ID의 UID·종류·내용 변경은 거절한다", () => {
  const room = fixture();
  connect(room);
  assert.throws(() => connect(room, {uid: "other"}));
  assert.throws(() => connect(room, {membershipId: "changed"}));
  assert.throws(() => roomOperationResult(room, "a", "join-operation", "leave", {}));
});

test("자체 퇴장은 멤버십 결과를 보존하며 게임 삭제·재가입 뒤 반복하지 않는다", () => {
  const room = fixture();
  const input = {uid: "a", roomInstanceId: "room-one", membershipId: "member-a",
    operationId: "leave-operation", now: 1000};
  const result = leaveRoomMembership(room, input);
  assert.equal(result.status, "applied");
  assert.equal(room.players.a, undefined);
  room.players.a = {membershipId: "member-new", status: "active"};
  assert.deepEqual(leaveRoomMembership(room, input), result);
  assert.equal(room.players.a.membershipId, "member-new");
  assert.equal(leaveRoomMembership(room, {...input, operationId: "late-operation"}).status,
    "stale");
  assert.equal(room.players.a.membershipId, "member-new");
});

test("방 코드 재사용과 terminal 방에 대한 옛 변경은 거절한다", () => {
  const room = fixture();
  assert.throws(() => assertRoomTarget(room, "room-old"));
  room.status = "terminal";
  assert.throws(() => connect(room));
});

test("결과 ledger는 요청자 한 작업만 확인하며 미처리를 미래 취소로 바꾸지 않는다", () => {
  const room = fixture();
  assert.equal(roomOperationResult(room, "a", "missing-operation"), null);
  recordRoomOperation(room, "a", "test-operation", "join", {}, {status: "applied"}, 1000);
  assert.deepEqual(roomOperationResult(room, "a", "test-operation"), {status: "applied"});
  assert.throws(() => roomOperationResult(room, "other", "test-operation"));
});
