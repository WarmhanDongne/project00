/* eslint-disable max-len, no-console, require-jsdoc */

import {getApps, initializeApp} from "firebase-admin/app";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {pathToFileURL} from "node:url";

import {gamePreviewDescriptions} from "./update-game-preview.mjs";
import {gameRules} from "./update-game-rules.mjs";

export const holdemCatalogEntry = Object.freeze({
  name: "텍사스 홀덤",
  description: "두 장의 홀 카드와 다섯 장의 커뮤니티 카드로 최고의 5장 조합을 만드는 토너먼트 포커입니다.",
  tabletDescription: gamePreviewDescriptions.holdem,
  rules: gameRules.holdem,
  imageUrl: "",
  componentImageUrl: "",
  enabled: true,
  genres: ["카드", "전략", "심리"],
  minPlayers: 2,
  maxPlayers: 8,
  playTime: 30,
  order: 4,
  ruleVideoUrl: "",
  accessType: "free",
  minAppVersion: "1.0.0",
});

export async function registerHoldemCatalog({dryRun = false} = {}) {
  if (dryRun) {
    console.log(JSON.stringify({id: "holdem", ...holdemCatalogEntry}, null, 2));
    return;
  }

  if (getApps().length === 0) {
    initializeApp({projectId: process.env.GCLOUD_PROJECT ?? "project0000-ec01e"});
  }
  const database = getFirestore();
  const reference = database.collection("games").doc("holdem");
  await database.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);
    const timestamps = {updatedAt: FieldValue.serverTimestamp()};
    if (!snapshot.exists) {
      timestamps.createdAt = FieldValue.serverTimestamp();
    }
    transaction.set(reference, {...holdemCatalogEntry, ...timestamps}, {merge: true});
  });
  console.log("Registered games/holdem.");
}

const isMain = process.argv[1] &&
  import.meta.url === pathToFileURL(process.argv[1]).href;
if (isMain) {
  try {
    await registerHoldemCatalog({dryRun: process.argv.includes("--dry-run")});
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error(`Hold'em catalog registration failed: ${message}`);
    console.error(
      "Authenticate with Application Default Credentials, then run " +
      "npm run catalog:holdem:register again.",
    );
    process.exitCode = 1;
  }
}
