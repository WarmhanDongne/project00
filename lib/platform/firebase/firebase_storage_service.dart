abstract interface class FirebaseStorageService {
  Future<Uri> upload(String path, List<int> bytes);
}
