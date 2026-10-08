/* eslint-disable no-console, require-jsdoc */

import {createHash} from "node:crypto";
import {readFile} from "node:fs/promises";
import {dirname, resolve} from "node:path";
import {fileURLToPath, pathToFileURL} from "node:url";

import {getApps, initializeApp} from "firebase-admin/app";
import {getStorage} from "firebase-admin/storage";

const scriptDirectory = dirname(fileURLToPath(import.meta.url));
export const holdemAssetRoot = resolve(
  scriptDirectory,
  "../../assets/game-assets/holdem",
);

function assertManifest(manifest) {
  if (manifest.gameId !== "holdem" || manifest.assetVersion !== 2) {
    throw new Error("Expected the holdem v2 asset manifest.");
  }
  if (!Array.isArray(manifest.files) || manifest.files.length !== 5) {
    throw new Error("Expected exactly 5 Hold'em asset files.");
  }
}

export async function loadVerifiedHoldemAssets(root = holdemAssetRoot) {
  const manifestBytes = await readFile(resolve(root, "manifest.json"));
  const manifest = JSON.parse(manifestBytes.toString("utf8"));
  assertManifest(manifest);

  const files = await Promise.all(manifest.files.map(async (entry) => {
    if (entry.path.startsWith("/") || entry.path.includes("..")) {
      throw new Error(`Unsafe asset path: ${entry.path}`);
    }
    const bytes = await readFile(resolve(root, String(manifest.assetVersion), entry.path));
    const sha256 = createHash("sha256").update(bytes).digest("hex");
    if (bytes.length !== entry.bytes || sha256 !== entry.sha256) {
      throw new Error(`Asset integrity mismatch: ${entry.path}`);
    }
    return {entry, bytes};
  }));

  return {manifest, manifestBytes, files};
}

async function uploadInBatches(items, upload, batchSize = 8) {
  for (let index = 0; index < items.length; index += batchSize) {
    await Promise.all(items.slice(index, index + batchSize).map(upload));
  }
}

export async function uploadHoldemAssets({dryRun = false} = {}) {
  const verified = await loadVerifiedHoldemAssets();
  const versionPrefix = [
    "game-assets",
    verified.manifest.gameId,
    String(verified.manifest.assetVersion),
  ].join("/");

  if (dryRun) {
    console.log(
      `Verified ${verified.files.length} files for ${versionPrefix}; no upload performed.`,
    );
    return;
  }

  const projectId = process.env.GCLOUD_PROJECT ?? "project0000-ec01e";
  const bucketName = process.env.FIREBASE_STORAGE_BUCKET ??
    "project0000-ec01e.firebasestorage.app";
  if (getApps().length === 0) {
    initializeApp({projectId, storageBucket: bucketName});
  }
  const bucket = getStorage().bucket(bucketName);

  await uploadInBatches(verified.files, async ({entry, bytes}) => {
    await bucket.file(`${versionPrefix}/${entry.path}`).save(bytes, {
      resumable: false,
      contentType: "image/webp",
      metadata: {
        cacheControl: "public,max-age=31536000,immutable",
        metadata: {sha256: entry.sha256},
      },
    });
  });

  await bucket.file("game-assets/holdem/manifest.json").save(
    verified.manifestBytes,
    {
      resumable: false,
      contentType: "application/json; charset=utf-8",
      metadata: {cacheControl: "private,max-age=0,no-cache"},
    },
  );
  console.log(
    `Uploaded ${verified.files.length} files and manifest to ${bucketName}.`,
  );
}

const isMain = process.argv[1] &&
  import.meta.url === pathToFileURL(process.argv[1]).href;
if (isMain) {
  try {
    await uploadHoldemAssets({dryRun: process.argv.includes("--dry-run")});
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error(`Hold'em asset upload failed: ${message}`);
    console.error(
      "Authenticate with Application Default Credentials, then run " +
      "npm run assets:holdem:upload again.",
    );
    process.exitCode = 1;
  }
}
