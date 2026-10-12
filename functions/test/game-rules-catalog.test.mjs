import assert from "node:assert/strict";
import test from "node:test";

import {
  gameRules,
  localizedGameRules,
} from "../scripts/update-game-rules.mjs";
import {gameCatalogLocales} from "../scripts/game-catalog-translations.mjs";

test("game rules catalog contains the four Firestore game ids", () => {
  assert.deepEqual(Object.keys(gameRules).sort(), [
    "final_call",
    "holdem",
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

test("every game rule has every supported catalog locale", () => {
  for (const [gameId, rules] of Object.entries(localizedGameRules)) {
    assert.deepEqual(Object.keys(rules), gameCatalogLocales, gameId);
    assert.equal(rules.ko, gameRules[gameId]);
    for (const [locale, text] of Object.entries(rules)) {
      assert.ok(text.includes("\n"), `${gameId}/${locale}`);
      assert.equal(text.trim(), text, `${gameId}/${locale}`);
    }
  }
});
