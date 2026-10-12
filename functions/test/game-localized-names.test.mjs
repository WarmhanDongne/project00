import assert from "node:assert/strict";
import test from "node:test";
import {
  localizedGameNames,
  updateGameLocalizedNames,
} from "../scripts/update-game-localized-names.mjs";
import {
  gameCatalogLocales,
  localizedGameDescriptions,
  localizedGameGenres,
} from "../scripts/game-catalog-translations.mjs";
import {gameRules, localizedGameRules} from "../scripts/update-game-rules.mjs";

function database(ids) {
  const records = new Map(ids.map((id) => [`games/${id}`, {enabled: true}]));
  const ref = (path) => ({
    id: path.split("/").at(-1),
    path,
    get: async () => ({exists: records.has(path)}),
  });
  return {
    records,
    collection: (name) => ({doc: (id) => ref(`${name}/${id}`)}),
    batch: () => {
      const writes = [];
      return {
        update: (target, value) => writes.push(() => records.set(
          target.path,
          {...records.get(target.path), ...value},
        )),
        commit: async () => writes.forEach((write) => write()),
      };
    },
  };
}

test("localized catalog update is dry-run by default and atomic on apply", async () => {
  const db = database(["liars", "final_call", "mafia", "holdem"]);
  const before = structuredClone(Object.fromEntries(db.records));
  const dryRun = await updateGameLocalizedNames(db);
  assert.equal(dryRun.status, "dry-run");
  assert.deepEqual(Object.fromEntries(db.records), before);

  const result = await updateGameLocalizedNames(db, {apply: true});
  assert.equal(result.status, "updated");
  assert.deepEqual(result.documents.map((entry) => entry.id), [
    "liars", "final_call", "mafia", "holdem",
  ]);
  for (const [gameId, names] of Object.entries(localizedGameNames)) {
    const documentId = gameId === "liars_poker" ? "liars" : gameId;
    const value = db.records.get(`games/${documentId}`);
    assert.equal(value.name, names.ko);
    assert.deepEqual(value.localizedNames, names);
    assert.equal(value.description, localizedGameDescriptions[gameId].ko);
    assert.deepEqual(
      value.localizedDescriptions,
      localizedGameDescriptions[gameId],
    );
    assert.equal(value.rules, gameRules[gameId]);
    assert.deepEqual(value.localizedRules, localizedGameRules[gameId]);
    assert.deepEqual(value.genres, localizedGameGenres[gameId].ko);
    assert.deepEqual(value.localizedGenres, localizedGameGenres[gameId]);
    for (const field of [
      value.localizedNames,
      value.localizedDescriptions,
      value.localizedRules,
      value.localizedGenres,
    ]) {
      assert.deepEqual(Object.keys(field), gameCatalogLocales);
    }
    assert.equal(value.enabled, true);
  }
});

test("localized catalog update supports the legacy liars document", async () => {
  const db = database(["liars_poker", "final_call", "mafia", "holdem"]);
  const result = await updateGameLocalizedNames(db, {apply: true});
  assert.equal(result.documents[0].id, "liars_poker");
  assert.equal(db.records.get("games/liars_poker").name, "라이어스");
  assert.equal(db.records.has("games/liars"), false);
});
