import 'package:flutter/material.dart';
import 'package:project00/platform/home/gamelist/service/game_list_service.dart';
import 'package:project00/platform/home/gamelist/models/game_info.dart';

class GameProvider extends ChangeNotifier {
  GameProvider({GameService? service}) : _service = service ?? GameService();

  final GameService _service;

  List<GameInfo> games = [];
  bool isLoading = false;
  String? errorMessage;

  bool _isDisposed = false;

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  Future<void> fetchGames() async {
    try {
      isLoading = true;
      errorMessage = null;
      notifyListeners();

      games = await _service.fetchGames();
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
