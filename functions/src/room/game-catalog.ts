/* eslint-disable require-jsdoc */
import {getFirestore} from "firebase-admin/firestore";

export function runtimeGameId(id: string): string {
  return id === "liars" ? "liars_poker" : id;
}

export function catalogDocumentId(id: string): string {
  return runtimeGameId(id) === "liars_poker" ? "liars" : id;
}

/**
 * A catalog entry is playable only when it explicitly opts in.
 * @param {unknown} data Firestore catalog document data.
 * @return {boolean} Whether the entry is explicitly enabled.
 */
export function isCatalogGameEnabled(data: unknown): boolean {
  return typeof data === "object" && data !== null &&
    (data as {enabled?: unknown}).enabled === true;
}

/**
 * Fall back only when the canonical document is missing.
 * @param {string} id Stable runtime ID or catalog document ID.
 * @param {Function} read Catalog reader; failures propagate without fallback.
 */
export async function readGameCatalog<T extends {exists: boolean}>(
  id: string,
  read: (documentId: string) => Promise<T>,
): Promise<T> {
  const canonical = catalogDocumentId(id);
  const result = await read(canonical);
  const legacy = runtimeGameId(id);
  return !result.exists && canonical !== legacy ? read(legacy) : result;
}

export function getGameCatalog(id: string) {
  return readGameCatalog(id, (key) =>
    getFirestore().collection("games").doc(key).get());
}
