import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
import vm from "node:vm";
import test from "node:test";

// 실제 rules의 쓰기 조건을 평가합니다. Firebase rules engine 통합 검증은 아닙니다.
const rules = JSON.parse(readFileSync(new URL("../../database.rules.json", import.meta.url), "utf8"));
function snapshot(value) {
  return {
    child: (key) => snapshot(value?.[key]),
    exists: () => value !== null && value !== undefined,
    val: () => value ?? null,
    isBoolean: () => typeof value === "boolean",
    isNumber: () => typeof value === "number" && Number.isFinite(value),
  };
}

const memberRead = ({
  field,
  auth = {uid: "player"},
  controllerUid = "controller",
  players = {player: {status: "active"}},
}) => vm.runInNewContext(
  String(rules.rules.rooms.$roomCode[field][".read"]),
  {
    auth,
    $roomCode: "ABCDE",
    root: snapshot({rooms: {ABCDE: {controllerUid, players}}}),
  },
);

test("방 메타데이터와 참가자 목록은 controller와 참가자만 읽는다", () => {
  const protectedFields = [
    "createdAt",
    "membershipRevision",
    "controllerCurrentConnectionId",
    "controllerConnectionSeq",
    "controllerConnected",
    "maxPlayers",
    "selectedGame",
    "players",
    "presenceProtocol",
  ];
  for (const field of protectedFields) {
    assert.equal(memberRead({field}), true, `${field}: 참가자`);
    assert.equal(
      memberRead({field, auth: {uid: "controller"}}),
      true,
      `${field}: controller`,
    );
    assert.equal(
      memberRead({field, auth: {uid: "outsider"}}),
      false,
      `${field}: 방 밖 사용자`,
    );
    assert.equal(memberRead({field, auth: null}), false, `${field}: 비로그인`);
  }
});

test("roomCode 존재 마커는 방 삭제·강퇴 뒤에도 로그인 사용자가 읽는다", () => {
  // 방이 지워지거나 강퇴되면 참가자 근거가 사라지므로, 존재 확인은 멤버십과
  // 무관하게 허용해야 클라이언트가 삭제·강퇴를 권한 오류와 구분할 수 있습니다.
  assert.equal(memberRead({field: "roomCode", auth: {uid: "outsider"}}), true);
  assert.equal(
    memberRead({
      field: "roomCode",
      auth: {uid: "player"},
      controllerUid: undefined,
      players: {},
    }),
    true,
  );
  assert.equal(memberRead({field: "roomCode", auth: null}), false);
});

test("입장 전에는 방 세션과 자기 참가 기록만 확인할 수 있다", () => {
  const roomInstanceRead = rules.rules.rooms.$roomCode.roomInstanceId[".read"];
  assert.equal(
    vm.runInNewContext(String(roomInstanceRead), {auth: {uid: "outsider"}}),
    true,
  );
  assert.equal(vm.runInNewContext(String(roomInstanceRead), {auth: null}), false);

  const ownPlayerRead =
    rules.rules.rooms.$roomCode.players.$playerUid[".read"];
  assert.equal(
    vm.runInNewContext(String(ownPlayerRead), {
      auth: {uid: "outsider"},
      $playerUid: "outsider",
    }),
    true,
  );
  assert.equal(
    vm.runInNewContext(String(ownPlayerRead), {
      auth: {uid: "outsider"},
      $playerUid: "other",
    }),
    false,
  );
});

for (const field of ["isConnected", "lastSeen"]) {
  test(`${field}: 요약 presence 직접 쓰기는 모든 세션에서 거부한다`, () => {
    const expression = rules.rules.rooms.$roomCode.players.$playerUid[field][".write"];
    const allowed = ({player, roomStatus = "playing", auth = {uid: "me"}} = {}) =>
      vm.runInNewContext(String(expression), {
        auth, $roomCode: "ABCDE", $playerUid: "me",
        root: snapshot({rooms: {ABCDE: {status: roomStatus, players: {me: player}}}}),
      });
    assert.equal(allowed({player: {nickname: "test", status: "active"}}), false);
    assert.equal(allowed({player: {nickname: "legacy"}}), false);
    assert.equal(allowed({player: {nickname: "test", status: "active"}, roomStatus: "finished"}), false);
    assert.equal(allowed({}), false, "삭제된 참가자는 heartbeat/onDisconnect로 재생성 불가");
    assert.equal(allowed({player: {isConnected: true, lastSeen: 1000}}), false);
    assert.equal(allowed({player: {nickname: "test", status: "inactive"}}), false);
    assert.equal(allowed({player: {nickname: "test"}, roomStatus: "closed"}), false);
    assert.equal(allowed({player: {nickname: "test"}, roomStatus: null}), false);
    assert.equal(allowed({player: {nickname: "test"}, auth: null}), false);
    assert.equal(allowed({player: {nickname: "test"}, auth: {uid: "other"}}), false);
  });
}

for (const role of ["player", "controller"]) {
  for (const field of ["connected", "lastSeen"]) {
    test(`${role}/${field}: 현재 접속만 허용하고 재가입·코드 재사용·옛 접속을 거부한다`, () => {
      const expression = rules.rules.rooms.$roomCode.connections.$connectionUid.$connectionId[field][".write"];
      const room = {
        roomInstanceId: "room-one", status: "playing", controllerUid: role === "controller" ? "me" : "tablet",
        controllerCurrentConnectionId: "connection-one",
        players: {me: {status: "active", membershipId: "member-one", currentConnectionId: "connection-one"}},
        connections: {me: {"connection-one": {roomInstanceId: "room-one", membershipId: "member-one"}}},
      };
      if (role === "controller") {
        room.players = {};
        delete room.connections.me["connection-one"].membershipId;
      }
      const allowed = (value = field === "connected" ? true : 1000, auth = {uid: "me"}) =>
        vm.runInNewContext(expression, {auth, $roomCode: "ABCDE", $connectionUid: "me",
          $connectionId: "connection-one", now: 1000, newData: snapshot(value),
          root: snapshot({rooms: {ABCDE: room}})});
      assert.equal(allowed(), true);
      assert.equal(allowed(undefined, {uid: "other"}), false);
      assert.equal(allowed(null), false, "node 삭제로 metadata를 제거할 수 없음");
      assert.equal(allowed("invalid"), false);
      if (field === "lastSeen") assert.equal(allowed(11001), false);
      room.status = "closed";
      assert.equal(allowed(), false);
      room.status = "terminal";
      assert.equal(allowed(), false);
      room.status = "playing";
      if (role === "player") room.players.me.currentConnectionId = "connection-new";
      else room.controllerCurrentConnectionId = "connection-new";
      assert.equal(allowed(), false);
      if (role === "player") {
        room.players.me.currentConnectionId = "connection-one";
        room.players.me.membershipId = "member-new";
        assert.equal(allowed(), false);
        delete room.players.me;
        assert.equal(allowed(), false);
      } else room.controllerCurrentConnectionId = "connection-one";
      room.roomInstanceId = "room-new";
      assert.equal(allowed(), false);
    });
  }
}
