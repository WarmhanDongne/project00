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
  Future<void>? _fetchInFlight;

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

  Future<void> fetchGames() {
    if (_isDisposed) return Future.value();
    return _fetchInFlight ??= Future<void>.microtask(_fetchGames).whenComplete(
      () {
        _fetchInFlight = null;
      },
    );
  }

  Future<void> _fetchGames() async {
    if (_isDisposed) return;
    try {
      isLoading = true;
      errorMessage = null;
      notifyListeners();

      final result = await _service.fetchGames();
      if (!_isDisposed) games = result;
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
