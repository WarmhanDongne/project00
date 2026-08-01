import 'package:flutter/foundation.dart';
import 'package:project00/games/liars_poker/models/liars_poker_state.dart';

class LiarsPokerProvider extends ChangeNotifier {
  LiarsPokerState _state = const LiarsPokerState();
  LiarsPokerState get state => _state;
  void update(LiarsPokerState value) {
    _state = value;
    notifyListeners();
  }
}
