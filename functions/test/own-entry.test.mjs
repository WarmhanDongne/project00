import assert from "node:assert/strict";
import test from "node:test";

import {isSafeRecordKey, ownEntry} from "../lib/common/own-entry.js";
import {
  parseCardIds,
  parseCommandId,
} from "../lib/liars-poker/common/validator.js";
import {finalCallCommandId} from "../lib/final-call/validation.js";

const PROTOTYPE_KEYS = ["__proto__", "constructor", "toString", "hasOwnProperty"];

test("손패에 없는 기본 속성 이름은 카드로 인정하지 않는다", () => {
  // RTDB에서 읽은 손패와 같은 일반 객체입니다.
  const hand = JSON.parse('{"c1": {"id": "c1", "rank": "A"}}');
  assert.deepEqual(ownEntry(hand, "c1"), {id: "c1", rank: "A"});
  assert.equal(ownEntry(hand, "c2"), undefined);
  for (const key of PROTOTYPE_KEYS) {
    assert.equal(ownEntry(hand, key), undefined, key);
  }
  assert.equal(ownEntry(undefined, "c1"), undefined);
  assert.equal(ownEntry(null, "c1"), undefined);
});

test("기본 속성 이름은 객체 키로 받지 않는다", () => {
  for (const key of PROTOTYPE_KEYS) {
    assert.equal(isSafeRecordKey(key), false, key);
  }
  assert.equal(isSafeRecordKey("card_1-A"), true);
  assert.equal(isSafeRecordKey("cmd_0a1b2c3d4e5f"), true);
});

test("라이어스 포커는 기본 속성 이름의 카드 ID와 명령 ID를 거절한다", () => {
  assert.deepEqual(parseCardIds(["c1", "c2"]), ["c1", "c2"]);
  for (const key of PROTOTYPE_KEYS) {
    assert.throws(() => parseCardIds([key]), {code: "invalid-argument"}, key);
    assert.throws(() => parseCommandId(key), {code: "invalid-argument"}, key);
  }
  assert.equal(parseCommandId("submit_0a1b2c"), "submit_0a1b2c");
});

test("파이널 콜은 기본 속성 이름의 명령 ID를 거절한다", () => {
  for (const key of PROTOTYPE_KEYS) {
    assert.throws(
      () => finalCallCommandId(key),
      {code: "invalid-argument"},
      key,
    );
  }
  assert.equal(finalCallCommandId("draw_0a1b2c"), "draw_0a1b2c");
});
