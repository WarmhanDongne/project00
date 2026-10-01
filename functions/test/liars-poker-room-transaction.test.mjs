import assert from "node:assert/strict";
import {readdirSync, readFileSync} from "node:fs";
import test from "node:test";

const sourceDirectory = new URL("../src/liars-poker/", import.meta.url);
const sources = readdirSync(sourceDirectory)
  .filter((name) => name.endsWith(".ts"))
  .map((name) => ({
    name,
    source: readFileSync(new URL(name, sourceDirectory), "utf8"),
  }));

test("Liar's Poker 방 루트 트랜잭션은 서버 값을 먼저 읽는다", () => {
  const transactionalSources = sources.filter(({source}) =>
    source.includes("runPrimedTransaction(roomRef"));

  assert.ok(
    transactionalSources.length > 0,
    "안전 트랜잭션을 사용하는 게임 명령이 하나 이상이어야 합니다.",
  );
  for (const {name, source} of sources) {
    assert.doesNotMatch(
      source,
      /roomRef\.transaction\(/,
      `${name}이 캐시의 null을 방 삭제로 쓸 수 있습니다.`,
    );
  }
});
