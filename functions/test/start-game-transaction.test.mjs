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
