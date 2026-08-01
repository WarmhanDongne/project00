abstract interface class FirebaseFunctionsService {
  Future<Object?> call(String name, [Map<String, Object?>? data]);
}
