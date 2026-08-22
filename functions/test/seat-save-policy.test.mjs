import assert from "node:assert/strict";
import test from "node:test";

import {decideSeatSave} from "../lib/room/room-seating-policy.js";

//=======================자리 배치 중 참가자 변경 (C-13)==============================
// 이 판정의 요점은 **명단 불일치와 좌석 번호 오류를 나누는 것**입니다.
// 두 경우를 한 결과로 묶으면, 자리 배치 중 누가 나가서 생긴 실패까지
// "중복 없이 지정하라"로 안내되어 진행자가 무엇을 고쳐야 하는지 알 수 없습니다.

const base = {
  roomStatus: "seating",
  playerIds: ["a", "b", "c"],
  seatEntries: [
    ["a", 0],
    ["b", 1],
    ["c", 2],
  ],
  minPlayers: 2,
  maxPlayers: 12,
};

test("자리 배치 중이고 명단·좌석이 맞으면 저장한다", () => {
  assert.equal(decideSeatSave(base), "save");
});

test("좌석 순서가 뒤섞여도 저장한다", () => {
  assert.equal(
    decideSeatSave({
      ...base,
      seatEntries: [
        ["c", 1],
        ["a", 2],
        ["b", 0],
      ],
    }),
    "save",
  );
});

test("자리 배치 상태가 아니면 저장하지 않는다", () => {
  for (const roomStatus of ["waiting", "playing", "finished", "closed", undefined]) {
    assert.equal(decideSeatSave({...base, roomStatus}), "not-seating");
  }
});

test("참가자가 나가면 좌석 오류가 아니라 명단 변경으로 판정한다", () => {
  // C-13의 핵심. 진행자에게 "다시 배치하세요"라고 안내할 수 있어야 합니다.
  assert.equal(
    decideSeatSave({
      ...base,
      playerIds: ["a", "b"],
      seatEntries: [
        ["a", 0],
        ["b", 1],
        ["c", 2],
      ],
    }),
    "roster-changed",
  );
});

test("좌석을 보내지 않은 참가자가 있으면 명단 변경이다", () => {
  assert.equal(
    decideSeatSave({
      ...base,
      seatEntries: [
        ["a", 0],
        ["b", 1],
      ],
    }),
    "roster-changed",
  );
});

test("명단은 같은데 좌석이 겹치면 좌석 오류다", () => {
  assert.equal(
    decideSeatSave({
      ...base,
      seatEntries: [
        ["a", 0],
        ["b", 0],
        ["c", 2],
      ],
    }),
    "invalid-seats",
  );
});

test("좌석 번호가 범위를 벗어나면 좌석 오류다", () => {
  assert.equal(
    decideSeatSave({
      ...base,
      seatEntries: [
        ["a", 0],
        ["b", 1],
        ["c", 3],
      ],
    }),
    "invalid-seats",
  );
});

test("정수가 아닌 좌석 번호는 좌석 오류다", () => {
  assert.equal(
    decideSeatSave({
      ...base,
      seatEntries: [
        ["a", 0],
        ["b", 1.5],
        ["c", 2],
      ],
    }),
    "invalid-seats",
  );
});

test("명단 불일치와 좌석 오류가 함께면 명단 변경을 먼저 알린다", () => {
  // 진행자가 고칠 수 있는 것은 좌석이 아니라 배치를 다시 하는 것뿐입니다.
  assert.equal(
    decideSeatSave({
      ...base,
      playerIds: ["a", "b"],
      seatEntries: [
        ["a", 0],
        ["b", 0],
        ["c", 9],
      ],
    }),
    "roster-changed",
  );
});

test("참가자가 없으면 저장하지 않는다", () => {
  assert.equal(
    decideSeatSave({...base, playerIds: [], seatEntries: []}),
    "no-players",
  );
});

test("최소·최대 인원을 벗어나면 저장하지 않는다", () => {
  assert.equal(
    decideSeatSave({
      ...base,
      playerIds: ["a"],
      seatEntries: [["a", 0]],
    }),
    "too-few-players",
  );
  assert.equal(
    decideSeatSave({...base, maxPlayers: 2}),
    "too-many-players",
  );
});
