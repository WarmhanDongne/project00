abstract interface class FirestoreService {
  Future<Map<String, Object?>?> getDocument(String path);
  Future<void> setDocument(String path, Map<String, Object?> data);
}
