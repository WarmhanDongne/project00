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
  };
}
for (const field of ["isConnected", "lastSeen"]) {
  test(`${field}: 기존 참가자 presence만 허용하고 퇴장 뒤 지연 쓰기를 거부한다`, () => {
    const expression = rules.rules.rooms.$roomCode.players.$playerUid[field][".write"];
    const allowed = ({player, roomStatus = "playing", auth = {uid: "me"}} = {}) =>
      vm.runInNewContext(expression, {
        auth, $roomCode: "ABCDE", $playerUid: "me",
        root: snapshot({rooms: {ABCDE: {status: roomStatus, players: {me: player}}}}),
      });
    assert.equal(allowed({player: {nickname: "test", status: "active"}}), true);
    assert.equal(allowed({player: {nickname: "legacy"}}), true);
    assert.equal(allowed({player: {nickname: "test", status: "active"}, roomStatus: "finished"}), true);
    assert.equal(allowed({}), false, "삭제된 참가자는 heartbeat/onDisconnect로 재생성 불가");
    assert.equal(allowed({player: {isConnected: true, lastSeen: 1000}}), false);
    assert.equal(allowed({player: {nickname: "test", status: "inactive"}}), false);
    assert.equal(allowed({player: {nickname: "test"}, roomStatus: "closed"}), false);
    assert.equal(allowed({player: {nickname: "test"}, roomStatus: null}), false);
    assert.equal(allowed({player: {nickname: "test"}, auth: null}), false);
    assert.equal(allowed({player: {nickname: "test"}, auth: {uid: "other"}}), false);
  });
}
