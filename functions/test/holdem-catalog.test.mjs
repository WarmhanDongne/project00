import assert from "node:assert/strict";
import test from "node:test";

import {holdemCatalogEntry} from "../scripts/register-holdem.mjs";
import {gamePreviewDescriptions} from "../scripts/update-game-preview.mjs";
import {gameRules} from "../scripts/update-game-rules.mjs";

test("Hold'em catalog entry is complete and uses the shared copy", () => {
  assert.equal(holdemCatalogEntry.name, "텍사스 홀덤");
  assert.equal(holdemCatalogEntry.tabletDescription, gamePreviewDescriptions.holdem);
  assert.equal(holdemCatalogEntry.rules, gameRules.holdem);
  assert.equal(holdemCatalogEntry.enabled, true);
  assert.equal(holdemCatalogEntry.accessType, "free");
  assert.equal(holdemCatalogEntry.minPlayers, 2);
  assert.equal(holdemCatalogEntry.maxPlayers, 8);
  assert.equal(holdemCatalogEntry.minAppVersion, "1.0.0");
  assert.ok(holdemCatalogEntry.playTime > 0);
  assert.ok(holdemCatalogEntry.order > 0);
  assert.deepEqual(holdemCatalogEntry.genres, ["카드", "전략", "심리"]);
});
