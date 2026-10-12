/// Firestore catalog document IDs are independent of game protocol/asset IDs.
/// Existing rooms, purchases and binaries retain the stable runtime ID.
String runtimeGameId(String id) => id == 'liars' ? 'liars_poker' : id;

String catalogDocumentId(String id) =>
    runtimeGameId(id) == 'liars_poker' ? 'liars' : id;

/// During rollout, prefer the canonical document even when it is disabled.
/// Falling back to an enabled legacy duplicate would bypass catalog policy.
Map<String, T> preferredCatalogEntries<T>(
  Iterable<T> entries,
  String Function(T) documentId,
) {
  final result = <String, T>{};
  for (final entry in entries) {
    final id = documentId(entry);
    final runtimeId = runtimeGameId(id);
    if (!result.containsKey(runtimeId) || id == catalogDocumentId(id)) {
      result[runtimeId] = entry;
    }
  }
  return result;
}
