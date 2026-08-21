import assert from "node:assert/strict";
import test from "node:test";

import {gameRules} from "../scripts/update-game-rules.mjs";

test("game rules catalog contains the three Firestore game ids", () => {
  assert.deepEqual(Object.keys(gameRules).sort(), [
    "final_call",
    "liars_poker",
    "mafia",
  ]);
});

test("game rules preserve headings and multiline copy", () => {
  assert.match(gameRules.mafia, /\[게임 목표\]/);
  assert.match(gameRules.liars_poker, /조커 2장/);
  assert.match(gameRules.final_call, /\[CALL 선언\]/);
  for (const rules of Object.values(gameRules)) {
    assert.ok(rules.includes("\n"));
    assert.equal(rules.trim(), rules);
  }
});
