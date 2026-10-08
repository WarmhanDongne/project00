import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
import test from "node:test";

test("Hold'em download paths match the authenticated read-only Storage rule", () => {
  const rules = readFileSync(new URL("../../storage.rules", import.meta.url), "utf8");
  const source = readFileSync(
    new URL("../../lib/game_assets/firebase_game_asset_source.dart", import.meta.url),
    "utf8",
  );

  assert.match(rules, /match \/game-assets\/\{gameId\}\/\{assetPath=\*\*\}/);
  assert.match(rules, /allow read: if request\.auth != null/);
  assert.match(rules, /allow write: if false/);
  assert.match(source, /game-assets\/\$gameId\/manifest\.json/);
  assert.match(
    source,
    /game-assets\/\$\{manifest\.gameId\}\/\$\{manifest\.assetVersion\}\/\$\{file\.path\}/,
  );
});
