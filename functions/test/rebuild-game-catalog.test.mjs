import assert from "node:assert/strict";
import test from "node:test";

import {
  minimalGameCatalog,
  rebuildGameCatalog,
} from "../scripts/rebuild-game-catalog.mjs";

function database(initial, {nested = []} = {}) {
  const records = new Map(
    Object.entries(initial).map(([id, value]) => [`games/${id}`, value]),
  );
  const reference = (id) => ({
    id,
    path: `games/${id}`,
    listCollections: async () => nested.includes(id) ? [{id: "nested"}] : [],
  });
  return {
    records,
    collection: (name) => ({
      doc: (id) => reference(id),
      get: async () => ({
        docs: [...records.entries()]
          .filter(([path]) => path.startsWith(`${name}/`))
          .map(([path, value]) => {
            const id = path.split("/").at(-1);
            return {id, ref: reference(id), data: () => value};
          }),
      }),
    }),
    batch: () => {
      const writes = [];
      return {
        delete: (ref) => writes.push(() => records.delete(ref.path)),
        set: (ref, value) => writes.push(() => records.set(ref.path, value)),
        commit: async () => writes.forEach((write) => write()),
      };
    },
  };
}

test("dry-run reports the replacement without changing Firestore", async () => {
  const db = database({liars_poker: {legacy: true}, extra: {keep: false}});
  const before = structuredClone(Object.fromEntries(db.records));
  const result = await rebuildGameCatalog(db);
  assert.equal(result.status, "dry-run");
  assert.deepEqual(result.removedIds, ["liars_poker", "extra"]);
  assert.deepEqual(result.documentIds, [
    "liars", "final_call", "mafia", "holdem",
    "yut", "strategy_yut", "strategy_yut_edition",
  ]);
  for (const id of ["yut", "strategy_yut", "strategy_yut_edition"]) {
    assert.deepEqual(result.availability[id], {
      enabled: false,
      accessType: "paid",
      storeVisible: true,
    });
  }
  assert.deepEqual(result.availability.mafia, {
    enabled: false,
    accessType: "paid",
    storeVisible: true,
  });
  assert.deepEqual(Object.fromEntries(db.records), before);
});

test("apply backs up, removes old documents, and writes only the minimal schema", async () => {
  const db = database({
    liars_poker: {name: "old"},
    final_call: {name: "old", unnecessary: true},
    extra: {value: 1},
  });
  let backup;
  const result = await rebuildGameCatalog(db, {
    apply: true,
    writeBackup: async (value) => backup = value,
  });
  assert.equal(result.status, "rebuilt");
  assert.deepEqual(
    [...db.records.keys()].sort(),
    [
      "games/final_call", "games/holdem", "games/liars", "games/mafia",
      "games/strategy_yut", "games/strategy_yut_edition", "games/yut",
    ],
  );
  assert.equal(backup.documents.length, 3);
  for (const id of ["yut", "strategy_yut", "strategy_yut_edition"]) {
    assert.deepEqual(db.records.get(`games/${id}`), minimalGameCatalog[id]);
    assert.equal(db.records.get(`games/${id}`).enabled, false);
    assert.equal(db.records.get(`games/${id}`).accessType, "paid");
  }
  assert.deepEqual(db.records.get("games/liars"), minimalGameCatalog.liars);
  assert.equal(db.records.get("games/mafia").enabled, false);
  assert.equal(db.records.get("games/final_call").unnecessary, undefined);
  assert.deepEqual(Object.keys(db.records.get("games/liars")), [
    "name",
    "localizedNames",
    "description",
    "localizedDescriptions",
    "rules",
    "localizedRules",
    "enabled",
    "genres",
    "localizedGenres",
    "minPlayers",
    "maxPlayers",
    "playTime",
    "order",
    "accessType",
    "storeVisible",
  ]);
});

test("nested collections stop the destructive rebuild", async () => {
  const db = database({liars_poker: {name: "old"}}, {nested: ["liars_poker"]});
  await assert.rejects(
    rebuildGameCatalog(db, {apply: true}),
    /Nested collections exist under: liars_poker/,
  );
  assert.equal(db.records.has("games/liars_poker"), true);
});
