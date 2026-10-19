/* eslint-disable max-len, no-console, require-jsdoc */

import {getApps, initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";
import {pathToFileURL} from "node:url";
import {yutGameBundles, yutGameCatalog} from "./yut-game-catalog.mjs";

const PROJECT = "project0000-ec01e";

/** Plan or upsert Yut catalog documents; never deletes existing documents. */
export async function seedYutCatalog(firestore, {apply = false} = {}) {
  const planned = [
    ...Object.entries(yutGameCatalog).map(([id, data]) => ({collection: "games", id, data})),
    ...Object.entries(yutGameBundles).map(([id, data]) => ({collection: "gameBundles", id, data})),
  ];
  const result = {
    status: apply ? "upserted" : "dry-run",
    documents: planned.map(({collection, id, data}) => ({
      collection,
      id,
      fields: Object.keys(data).sort(),
      enabled: data.enabled,
      storeVisible: data.storeVisible,
      gameIds: data.gameIds,
    })),
  };
  if (!apply) return result;

  const batch = firestore.batch();
  for (const {collection, id, data} of planned) {
    batch.set(firestore.collection(collection).doc(id), data, {merge: true});
  }
  await batch.commit();
  return result;
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
    if (!apply) {
      console.log(JSON.stringify(await seedYutCatalog(null)));
    } else {
      const app = getApps()[0] ?? initializeApp({projectId: PROJECT});
      if (app.options.projectId !== PROJECT) throw new Error("Wrong Firebase project.");
      console.log(JSON.stringify(await seedYutCatalog(getFirestore(app), {apply: true})));
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error(`Yut catalog seed failed: ${message}`);
    process.exitCode = 1;
  }
}
