import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
import test from "node:test";

import {
  gamePreviewDescriptions,
} from "../scripts/update-game-preview.mjs";

test("tablet preview descriptions cover the catalog and fit the target length", () => {
  assert.deepEqual(
    Object.keys(gamePreviewDescriptions).sort(),
    ["final_call", "liars_poker", "mafia"],
  );
  for (const description of Object.values(gamePreviewDescriptions)) {
    assert.equal(description, description.trim());
    assert.ok(description.length >= 110, `${description.length} is too short`);
    assert.ok(description.length <= 150, `${description.length} is too long`);
  }
});

test("client and server default room limits remain 12", () => {
  const serverSource = readFileSync(
    new URL("../src/room/realtime-room-functions.ts", import.meta.url),
    "utf8",
  );
  const clientSource = readFileSync(
    new URL("../../lib/platform/home/room/services/room_common.dart", import.meta.url),
    "utf8",
  );
  assert.match(serverSource, /const DEFAULT_MAX_PLAYERS = 12;/);
  assert.match(clientSource, /defaultMaxPlayers = 12;/);
});
