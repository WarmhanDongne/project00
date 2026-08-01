import 'package:project00/platform/profile/models/user_model.dart';

abstract interface class UserRepository {
  Future<UserModel?> findById(String id);
  Future<void> save(UserModel user);
}
