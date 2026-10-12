import {getApps, initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";
import {pathToFileURL} from "node:url";

const PROJECT = "project0000-ec01e";

/** Atomic rename; keeps every field and refuses to overwrite either catalog. */
export async function migrateLiarsCatalog(firestore, {
  apply = false, clientsUpdated = false, rollback = false,
} = {}) {
  if (apply && !rollback && !clientsUpdated) {
    throw new Error("Update clients and deploy catalog readers before cutover.");
  }
  const from = rollback ? "liars" : "liars_poker";
  const to = rollback ? "liars_poker" : "liars";
  const source = firestore.doc(`games/${from}`);
  const target = firestore.doc(`games/${to}`);
  // Firestore document deletion does not move subcollections. Refuse that case.
  if ((await source.listCollections()).length ||
      (await target.listCollections()).length) {
    throw new Error("Subcollections require a separate migration.");
  }
  return firestore.runTransaction(async (tx) => {
    const [oldDoc, newDoc] = await tx.getAll(source, target);
    if (!oldDoc.exists && newDoc.exists) return {status: "already-moved", from, to};
    if (!oldDoc.exists) throw new Error("Source catalog is missing.");
    if (newDoc.exists) throw new Error("Target catalog exists; refusing overwrite.");
    const data = oldDoc.data();
    if (typeof data.name !== "string" || !data.name.trim()) {
      throw new Error("Source catalog has no display name.");
    }
    if (apply) {
      tx.create(target, data);
      tx.delete(source);
    }
    // No URLs, download tokens or full payload in command output.
    return {status: apply ? "moved" : "dry-run", from, to,
      fields: Object.keys(data).sort()};
  });
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const args = process.argv.slice(2);
  const allowed = new Set(["--apply", "--clients-updated", "--rollback"]);
  try {
    if (args.some((arg) => !allowed.has(arg))) throw new Error("Unknown argument.");
    const app = getApps()[0] ?? initializeApp({projectId: PROJECT});
    if (app.options.projectId !== PROJECT) throw new Error("Wrong Firebase project.");
    console.log(JSON.stringify(await migrateLiarsCatalog(getFirestore(app), {
      apply: args.includes("--apply"),
      clientsUpdated: args.includes("--clients-updated"),
      rollback: args.includes("--rollback"),
    })));
  } catch {
    console.error("Catalog migration failed. Check authentication, rollout prerequisites and document conflicts.");
    process.exitCode = 1;
  }
}
