import assert from "node:assert/strict";
import test from "node:test";

import {
  holdemAssetRoot,
  loadVerifiedHoldemAssets,
} from "../scripts/upload-holdem-assets.mjs";

test("Hold'em upload source matches every manifest hash and byte count", async () => {
  const verified = await loadVerifiedHoldemAssets(holdemAssetRoot);

  assert.equal(verified.manifest.gameId, "holdem");
  assert.equal(verified.manifest.assetVersion, 2);
  assert.equal(verified.files.length, 5);
  assert.ok(verified.manifestBytes.length > 0);
});
