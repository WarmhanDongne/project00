import 'package:flutter/foundation.dart';

class AuthProvider extends ChangeNotifier {
  bool _isSignedIn = false;
  bool get isSignedIn => _isSignedIn;
  void setSignedIn(bool value) {
    _isSignedIn = value;
    notifyListeners();
  }
}
