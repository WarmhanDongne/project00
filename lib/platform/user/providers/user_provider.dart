import 'package:flutter/foundation.dart';
import 'package:project00/platform/user/models/user_model.dart';

class UserProvider extends ChangeNotifier {
  UserModel? _user;
  UserModel? get user => _user;
  void setUser(UserModel? value) {
    _user = value;
    notifyListeners();
  }
}
