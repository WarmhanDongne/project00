import assert from "node:assert/strict";
import test from "node:test";
import {roomSessionContext} from "../lib/room/session-functions.js";
import {allocateRoomConnection, applyRoomPresence} from "../lib/room/session-contract.js";

const token = "12345678-1234-4123-8123-123456789abc";
function fixture() {
  return {
    roomInstanceId: "room-one", status: "waiting", controllerUid: "same-account",
    controllerSessionId: token, controllerCurrentConnectionId: "tablet-connection",
    controllerConnectionSeq: 3,
    players: {"same-account": {status: "active", membershipId: "phone-member",
      currentConnectionId: "phone-connection", connectionSeq: 2}},
  };
}

test("동일 계정 휴대폰의 조회는 태블릿 토큰 없이 참가자 세션을 반환한다", () => {
  assert.deepEqual(roomSessionContext(fixture(), "same-account"), {
    roomInstanceId: "room-one", roomStatus: "waiting", membershipId: "phone-member",
    connectionId: "phone-connection", connectionSeq: 2,
  });
});

test("동일 계정 태블릿의 조회는 유효한 controller 토큰으로 역할을 구분한다", () => {
  assert.deepEqual(roomSessionContext(fixture(), "same-account", token), {
    roomInstanceId: "room-one", roomStatus: "waiting",
    connectionId: "tablet-connection", connectionSeq: 3,
  });
  assert.throws(() => roomSessionContext(fixture(), "same-account",
    "12345678-1234-4123-8123-123456789abd"), /만료된/);
  assert.throws(() => roomSessionContext(fixture(), "other-account", token), /태블릿/);
});

test("추방된 동일 계정 휴대폰은 태블릿 세션을 가져올 수 없다", () => {
  const room = fixture();
  delete room.players["same-account"];
  assert.throws(() => roomSessionContext(room, "same-account"));
  assert.equal(roomSessionContext(room, "same-account", token).connectionId,
    "tablet-connection");
});

test("추방 뒤 늦은 휴대폰 단절은 동일 UID 태블릿 접속을 변경하지 않는다", () => {
  const room = fixture();
  room.players.b = {status: "active", membershipId: "member-b",
    currentConnectionId: "b-current", connectionSeq: 1};
  const otherPlayer = structuredClone(room.players.b);
  allocateRoomConnection(room, {uid: "same-account", role: "controller",
    operationId: "tablet-reconnect", roomInstanceId: "room-one",
    expectedConnectionSeq: 3, connectionId: "tablet-new", now: 1000});
  allocateRoomConnection(room, {uid: "same-account", role: "player",
    operationId: "phone-reconnect", roomInstanceId: "room-one",
    membershipId: "phone-member", expectedConnectionSeq: 2,
    connectionId: "phone-new", now: 1000});
  delete room.players["same-account"];
  room.connections["same-account"]["phone-new"].connected = false;
  assert.equal(applyRoomPresence(room, "same-account", "phone-new"), false);
  assert.equal(room.controllerConnected, true);
  assert.equal(room.controllerCurrentConnectionId, "tablet-new");
  assert.equal(room.status, "waiting");
  assert.deepEqual(room.players.b, otherPlayer);
});
