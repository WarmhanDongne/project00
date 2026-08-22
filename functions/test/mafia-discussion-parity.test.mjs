import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
import test from "node:test";

import {mafiaDiscussionMs} from "../lib/mafia/types.js";

// =========================================================================
// Dart ↔ TypeScript 토론 시간 대조
//
// 토론 시간은 생존 인원마다 다릅니다(확정 2026-08). 서버가 원본이고 연습장
// (lib/games/mafia/mafia_flow_config.dart)이 같은 표를 따라 흐름을 재현합니다.
// 한쪽만 고치면 연습장에서 본 흐름과 실제 게임이 조용히 달라지므로, Dart
// 파일을 직접 읽어 비교합니다.
// =========================================================================

const source = readFileSync(
  new URL("../../lib/games/mafia/mafia_flow_config.dart", import.meta.url),
  "utf8",
);
const table = source.slice(
  source.indexOf("discussionSecondsByAliveCount = {"),
  source.indexOf("};", source.indexOf("discussionSecondsByAliveCount = {")),
);
const dartSeconds = new Map(
  [...table.matchAll(/(\d+):\s*(\d+),/g)].map(([, count, seconds]) => [
    Number(count),
    Number(seconds),
  ]),
);

test("Dart 표가 2~12명을 모두 담고 있다", () => {
  for (let alive = 2; alive <= 12; alive += 1) {
    assert.ok(dartSeconds.has(alive), `${alive}명 값이 없습니다.`);
  }
});

test("Dart 표와 서버 계산이 같다", () => {
  for (const [alive, seconds] of dartSeconds) {
    assert.equal(
      seconds * 1000,
      mafiaDiscussionMs(alive),
      `${alive}명 토론 시간이 서버와 다릅니다.`,
    );
  }
});

test("확정된 값 그대로다", () => {
  assert.equal(mafiaDiscussionMs(2), 90000);
  assert.equal(mafiaDiscussionMs(3), 90000);
  assert.equal(mafiaDiscussionMs(4), 120000);
  assert.equal(mafiaDiscussionMs(5), 150000);
  assert.equal(mafiaDiscussionMs(6), 180000);
  assert.equal(mafiaDiscussionMs(7), 210000);
  assert.equal(mafiaDiscussionMs(8), 240000);
  assert.equal(mafiaDiscussionMs(9), 300000);
  assert.equal(mafiaDiscussionMs(10), 300000);
  // 방 최대(12명)까지는 9~10명과 같은 시간을 씁니다. 표에 없던 구간입니다.
  assert.equal(mafiaDiscussionMs(12), 300000);
});
