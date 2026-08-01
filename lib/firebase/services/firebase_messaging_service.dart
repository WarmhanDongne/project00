abstract interface class FirebaseMessagingService {
  Future<String?> getToken();
  Stream<Map<String, Object?>> get messages;
}
