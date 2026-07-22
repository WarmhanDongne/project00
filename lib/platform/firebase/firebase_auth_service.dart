abstract interface class FirebaseAuthService {
  Stream<String?> get userIdChanges;
  Future<void> signOut();
}
