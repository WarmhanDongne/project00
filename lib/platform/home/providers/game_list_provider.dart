import 'package:flutter/material.dart';
import 'package:project00/platform/home/models/game_info.dart';
import 'package:project00/platform/home/services/game_service.dart';

class GameProvider extends ChangeNotifier {
  GameProvider({GameService? service})
      : _service = service ?? GameService();

  final GameService _service;

  List<GameInfo> games = [];
  bool isLoading = false;
  String? errorMessage;

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