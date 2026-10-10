import assert from "node:assert/strict";
import test from "node:test";

import {
  assertStartGameSnapshot,
  startGameFingerprint,
} from "../lib/common/start-game-transaction.js";

const room = () => ({
  selectedGame: "mafia",
  status: "seating",
  players: {
    u2: {role: "player", status: "active", seatIndex: 1},
    u1: {role: "player", status: "active", seatIndex: 0},
  },
});

test("로비 fingerprint는 객체 키 순서와 무관하다", () => {
  const reordered = {
    ...room(),
    players: {
      u1: {seatIndex: 0, status: "active", role: "player"},
      u2: {seatIndex: 1, status: "active", role: "player"},
    },
  };
  assert.equal(startGameFingerprint(room()), startGameFingerprint(reordered));
  assert.doesNotThrow(() =>
    assertStartGameSnapshot(startGameFingerprint(room()), reordered));
});

test("게임 준비 중 좌석이 바뀌면 시작 커밋을 거부한다", () => {
  const changed = room();
  changed.players.u2.seatIndex = 3;
  assert.throws(
    () => assertStartGameSnapshot(startGameFingerprint(room()), changed),
    /참가자 또는 좌석이 바뀌었습니다/,
  );
});

test("heartbeat와 접속 교체는 같은 시작 입력으로 비교한다", () => {
  const initial = room();
  Object.assign(initial.players.u1, {lastSeen: 1000, isConnected: true,
    currentConnectionId: 'connection-old', connectionSeq: 1});
  const changed = structuredClone(initial);
  Object.assign(changed.players.u1, {lastSeen: 2000, isConnected: false,
    currentConnectionId: 'connection-new', connectionSeq: 2});
  assert.doesNotThrow(() => assertStartGameSnapshot(startGameFingerprint(initial), changed));
});

test("참가 자격·명단·표시 정보·게임 선택의 실제 변경은 시작을 거절한다", () => {
  for (const mutate of [
    value => { delete value.players.u2; },
    value => { value.players.u1.role = 'spectator'; },
    value => { value.players.u1.status = 'left'; },
    value => { value.players.u1.membershipId = 'new-membership'; },
    value => { value.players.u1.nickname = 'new-name'; },
    value => { value.players.u1.characterId = 'new-character'; },
    value => { value.players.u1.profileImageUrl = 'new-image'; },
    value => { value.selectedGame = 'holdem'; },
    value => { value.status = 'waiting'; },
  ]) {
    const changed = room();
    mutate(changed);
    assert.throws(() => assertStartGameSnapshot(startGameFingerprint(room()), changed),
      error => error.code === 'aborted');
  }
});
