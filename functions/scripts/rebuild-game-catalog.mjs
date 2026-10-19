/* eslint-disable max-len, no-console, require-jsdoc */

import {mkdir, writeFile} from "node:fs/promises";
import {dirname, resolve} from "node:path";
import {pathToFileURL} from "node:url";
import {getApps, initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";

import {localizedGameNames} from "./update-game-localized-names.mjs";
import {
  localizedGameDescriptions,
  localizedGameGenres,
} from "./game-catalog-translations.mjs";
import {gameRules, localizedGameRules} from "./update-game-rules.mjs";
import {yutGameCatalog} from "./yut-game-catalog.mjs";

const PROJECT = "project0000-ec01e";

export const minimalGameCatalog = Object.freeze({
  liars: Object.freeze({
    name: "라이어스",
    localizedNames: localizedGameNames.liars_poker,
    description: localizedGameDescriptions.liars_poker.ko,
    localizedDescriptions: localizedGameDescriptions.liars_poker,
    rules: gameRules.liars_poker,
    localizedRules: localizedGameRules.liars_poker,
    enabled: true,
    genres: localizedGameGenres.liars_poker.ko,
    localizedGenres: localizedGameGenres.liars_poker,
    minPlayers: 2,
    maxPlayers: 6,
    playTime: 15,
    order: 1,
    accessType: "free",
    storeVisible: true,
  }),
  final_call: Object.freeze({
    name: "파이널콜",
    localizedNames: localizedGameNames.final_call,
    description: localizedGameDescriptions.final_call.ko,
    localizedDescriptions: localizedGameDescriptions.final_call,
    rules: gameRules.final_call,
    localizedRules: localizedGameRules.final_call,
    enabled: true,
    genres: localizedGameGenres.final_call.ko,
    localizedGenres: localizedGameGenres.final_call,
    minPlayers: 4,
    maxPlayers: 6,
    playTime: 20,
    order: 2,
    accessType: "free",
    storeVisible: true,
  }),
  mafia: Object.freeze({
    name: "마피아",
    localizedNames: localizedGameNames.mafia,
    description: localizedGameDescriptions.mafia.ko,
    localizedDescriptions: localizedGameDescriptions.mafia,
    rules: gameRules.mafia,
    localizedRules: localizedGameRules.mafia,
    enabled: false,
    genres: localizedGameGenres.mafia.ko,
    localizedGenres: localizedGameGenres.mafia,
    minPlayers: 4,
    maxPlayers: 12,
    playTime: 30,
    order: 3,
    accessType: "paid",
    storeVisible: true,
  }),
  holdem: Object.freeze({
    name: "홀덤",
    localizedNames: localizedGameNames.holdem,
    description: localizedGameDescriptions.holdem.ko,
    localizedDescriptions: localizedGameDescriptions.holdem,
    rules: gameRules.holdem,
    localizedRules: localizedGameRules.holdem,
    enabled: true,
    genres: localizedGameGenres.holdem.ko,
    localizedGenres: localizedGameGenres.holdem,
    minPlayers: 2,
    maxPlayers: 8,
    playTime: 30,
    order: 4,
    accessType: "free",
    storeVisible: true,
    minAppVersion: "1.0.0",
  }),
  ...yutGameCatalog,
});

const catalogIds = Object.freeze(Object.keys(minimalGameCatalog));

export async function rebuildGameCatalog(
  firestore,
  {apply = false, writeBackup: saveBackup} = {},
) {
  const snapshot = await firestore.collection("games").get();
  const existing = snapshot.docs;
  const nested = [];
  for (const document of existing) {
    if (typeof document.ref.listCollections !== "function") continue;
    const collections = await document.ref.listCollections();
    if (collections.length > 0) nested.push(document.id);
  }
  if (nested.length > 0) {
    throw new Error(`Nested collections exist under: ${nested.join(", ")}`);
  }

  const removedIds = existing
    .map((document) => document.id)
    .filter((id) => !catalogIds.includes(id));
  const result = {
    status: apply ? "rebuilt" : "dry-run",
    existingIds: existing.map((document) => document.id),
    removedIds,
    documentIds: catalogIds,
    fields: Object.fromEntries(
      Object.entries(minimalGameCatalog).map(([id, value]) => [
        id,
        Object.keys(value),
      ]),
    ),
    availability: Object.fromEntries(
      Object.entries(minimalGameCatalog).map(([id, value]) => [
        id,
        {
          enabled: value.enabled,
          accessType: value.accessType,
          storeVisible: value.storeVisible,
        },
      ]),
    ),
  };
  if (!apply) return result;

  if (existing.length + catalogIds.length > 500) {
    throw new Error("The games collection is too large for one atomic batch.");
  }
  if (saveBackup) {
    await saveBackup({
      projectId: PROJECT,
      exportedAt: new Date().toISOString(),
      documents: existing.map((document) => ({
        id: document.id,
        data: document.data(),
      })),
    });
  }

  const batch = firestore.batch();
  for (const document of existing) {
    if (!catalogIds.includes(document.id)) batch.delete(document.ref);
  }
  for (const [id, value] of Object.entries(minimalGameCatalog)) {
    batch.set(firestore.collection("games").doc(id), value);
  }
  await batch.commit();
  return result;
}

function backupWriter(path) {
  return async (value) => {
    await mkdir(dirname(path), {recursive: true});
    await writeFile(path, `${JSON.stringify(value, null, 2)}\n`, "utf8");
  };
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const args = process.argv.slice(2);
  const apply = args.includes("--apply");
  const confirmation = `--confirm-project=${PROJECT}`;
  try {
    if (args.some((arg) => arg !== "--apply" && arg !== confirmation)) {
      throw new Error("Unknown argument.");
    }
    if (apply && !args.includes(confirmation)) {
      throw new Error(`Apply requires ${confirmation}.`);
    }
    const app = getApps()[0] ?? initializeApp({projectId: PROJECT});
    if (app.options.projectId !== PROJECT) throw new Error("Wrong Firebase project.");
    const stamp = new Date().toISOString().replaceAll(":", "-");
    const backupPath = resolve(
      process.cwd(),
      `../build/firestore-games-backup-${stamp}.json`,
    );
    const result = await rebuildGameCatalog(getFirestore(app), {
      apply,
      writeBackup: apply ? backupWriter(backupPath) : undefined,
    });
    console.log(JSON.stringify({...result, backupPath: apply ? backupPath : null}));
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error(`Game catalog rebuild failed: ${message}`);
    process.exitCode = 1;
  }
}
