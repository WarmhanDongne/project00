/** Resolve an existing catalog document without recreating a retired alias. */
export async function resolveCatalogDocument(firestore, gameId) {
  const canonical = gameId === "liars_poker" ? "liars" : gameId;
  const ref = firestore.collection("games").doc(canonical);
  if ((await ref.get()).exists) return ref;
  if (canonical !== gameId) {
    const legacy = firestore.collection("games").doc(gameId);
    if ((await legacy.get()).exists) return legacy;
  }
  throw new Error(`Missing catalog document: ${canonical}`);
}
