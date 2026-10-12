import {getApps, initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";
import {pathToFileURL} from "node:url";
import {resolveCatalogDocument} from "./catalog-document.mjs";
import {
  localizedGameDescriptions,
  localizedGameGenres,
} from "./game-catalog-translations.mjs";
import {gameRules, localizedGameRules} from "./update-game-rules.mjs";

const PROJECT = "project0000-ec01e";

export const localizedGameNames = Object.freeze({
  liars_poker: Object.freeze({
    ko: "라이어스",
    en: "Liars",
    "zh-Hans": "骗子",
    "zh-Hant": "騙子",
  }),
  final_call: Object.freeze({
    ko: "파이널콜",
    en: "FINAL CALL",
    "zh-Hans": "最后通牒",
    "zh-Hant": "最後通牒",
  }),
  mafia: Object.freeze({
    ko: "마피아",
    en: "MAFIA",
    "zh-Hans": "黑手党",
    "zh-Hant": "黑手黨",
  }),
  holdem: Object.freeze({
    ko: "홀덤",
    en: "TEXAS HOLD'EM",
    "zh-Hans": "德州扑克",
    "zh-Hant": "德州撲克",
  }),
});

/** Add locale-specific catalog text while retaining Korean legacy fields. */
export async function updateGameLocalizedNames(firestore, {apply = false} = {}) {
  const entries = await Promise.all(
    Object.entries(localizedGameNames).map(async ([gameId, names]) => ({
      gameId,
      names,
      ref: await resolveCatalogDocument(firestore, gameId),
    })),
  );
  if (apply) {
    const batch = firestore.batch();
    for (const entry of entries) {
      const descriptions = localizedGameDescriptions[entry.gameId];
      const genres = localizedGameGenres[entry.gameId];
      batch.update(entry.ref, {
        name: entry.names.ko,
        localizedNames: entry.names,
        description: descriptions.ko,
        localizedDescriptions: descriptions,
        rules: gameRules[entry.gameId],
        localizedRules: localizedGameRules[entry.gameId],
        genres: genres.ko,
        localizedGenres: genres,
      });
    }
    await batch.commit();
  }
  return {
    status: apply ? "updated" : "dry-run",
    documents: entries.map((entry) => ({
      id: entry.ref.id,
      locales: Object.keys(entry.names),
      fields: ["name", "description", "rules", "genres"],
    })),
  };
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const args = process.argv.slice(2);
  try {
    if (args.some((arg) => arg !== "--apply")) {
      throw new Error("Unknown argument.");
    }
    const app = getApps()[0] ?? initializeApp({projectId: PROJECT});
    if (app.options.projectId !== PROJECT) throw new Error("Wrong Firebase project.");
    console.log(JSON.stringify(await updateGameLocalizedNames(
      getFirestore(app),
      {apply: args.includes("--apply")},
    )));
  } catch {
    console.error("Localized catalog update failed. Check authentication and catalog documents.");
    process.exitCode = 1;
  }
}
