import 'package:flutter/foundation.dart';
import 'package:project00/games/liars_bar/models/liars_bar_state.dart';

class LiarsBarProvider extends ChangeNotifier {
  LiarsBarState _state = const LiarsBarState();
  LiarsBarState get state => _state;
  void update(LiarsBarState value) {
    _state = value;
    notifyListeners();
  }
}
