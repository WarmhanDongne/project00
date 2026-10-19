import assert from "node:assert/strict";
import test from "node:test";
import {
  isCatalogGameEnabled,
  readGameCatalog,
} from "../lib/room/game-catalog.js";
import {resolveCatalogDocument} from "../scripts/catalog-document.mjs";
import {migrateLiarsCatalog} from "../scripts/migrate-liars-catalog.mjs";

for (const id of ["liars", "liars_poker"]) {
  test(`${id} reads canonical catalog and respects disabled policy`, async () => {
    const calls = [];
    const result = await readGameCatalog(id, async (key) => {
      calls.push(key); return {exists: true, enabled: false};
    });
    assert.deepEqual(calls, ["liars"]);
    assert.equal(result.enabled, false);
  });
}
test("catalog availability requires an explicit enabled true", () => {
  assert.equal(isCatalogGameEnabled({enabled: true}), true);
  assert.equal(isCatalogGameEnabled({enabled: false}), false);
  assert.equal(isCatalogGameEnabled({}), false);
  assert.equal(isCatalogGameEnabled(null), false);
});
test("legacy fallback only for absence, not permission/network failure", async () => {
  const calls = [];
  assert.equal((await readGameCatalog("liars_poker", async (id) => {
    calls.push(id); return {exists: id === "liars_poker"};
  })).exists, true);
  assert.deepEqual(calls, ["liars", "liars_poker"]);
  let count = 0;
  await assert.rejects(readGameCatalog("liars", async () => {
    count++; throw new Error("unavailable");
  }));
  assert.equal(count, 1);
});

function database(entries, subcollections = []) {
  const records = new Map(Object.entries(entries));
  const ref = (path) => ({path,
    listCollections: async () => subcollections,
    get: async () => snapshot(path)});
  const snapshot = (path) => ({exists: records.has(path), data: () => records.get(path)});
  return {records, doc: ref, collection: (name) => ({doc: (id) => ref(`${name}/${id}`)}),
    runTransaction: async (action) => {
      const writes = [];
      const result = await action({
        getAll: async (...refs) => refs.map((r) => snapshot(r.path)),
        create: (r, data) => writes.push(() => records.set(r.path, data)),
        delete: (r) => writes.push(() => records.delete(r.path)),
      });
      writes.forEach((write) => write()); return result;
    }};
}
const entry = {name: "라이어스 (Liars) 거짓말쟁이들", enabled: true,
  rules: "rules", deck: ["A"], extra: {preserve: true}, createdAt: new Date(0)};
test("dry run keeps source; atomic move preserves fields; repeat and rollback", async () => {
  const db = database({"games/liars_poker": entry});
  assert.equal((await migrateLiarsCatalog(db)).status, "dry-run");
  assert.equal(db.records.size, 1);
  assert.ok(db.records.has("games/liars_poker"));
  await assert.rejects(migrateLiarsCatalog(db, {apply: true}));
  const options = {apply: true, clientsUpdated: true};
  assert.equal((await migrateLiarsCatalog(db, options)).status, "moved");
  assert.equal(db.records.has("games/liars_poker"), false);
  assert.deepEqual(db.records.get("games/liars"), entry);
  assert.equal((await migrateLiarsCatalog(db, options)).status, "already-moved");
  await migrateLiarsCatalog(db, {apply: true, rollback: true});
  assert.deepEqual(db.records.get("games/liars_poker"), entry);
  assert.equal(db.records.has("games/liars"), false);
});
test("conflicts, missing source and subcollections cannot mutate documents", async () => {
  for (const db of [database({}), database({"games/liars_poker": entry,
    "games/liars": {...entry, name: "other"}}),
  database({"games/liars_poker": entry}, ["nested"])]) {
    const before = [...db.records];
    await assert.rejects(migrateLiarsCatalog(db, {apply: true, clientsUpdated: true}));
    assert.deepEqual([...db.records], before);
  }
});
test("catalog maintenance scripts target migrated document, never recreate alias", async () => {
  for (const key of ["liars", "liars_poker"]) {
    const db = database({[`games/${key}`]: entry});
    assert.equal((await resolveCatalogDocument(db, "liars_poker")).path, `games/${key}`);
  }
  await assert.rejects(resolveCatalogDocument(database({}), "liars_poker"));
});
