import 'package:flutter/material.dart';
import 'package:project00/platform/home/gamelist/service/game_list_service.dart';
import 'package:project00/platform/home/gamelist/models/game_info.dart';
import 'package:project00/platform/home/store/models/game_bundle.dart';
import 'package:project00/platform/home/store/services/game_bundle_service.dart';

enum GameListScope { library, store }

class GameProvider extends ChangeNotifier {
  GameProvider({
    GameService? service,
    GameBundleService? bundleService,
    this.scope = GameListScope.library,
  }) : _service = service ?? GameService(),
       _bundleService = bundleService ?? GameBundleService();

  final GameService _service;
  final GameBundleService _bundleService;
  final GameListScope scope;

  List<GameInfo> games = [];
  List<GameBundle> bundles = [];
  bool isLoading = false;
  String? errorMessage;
  String? bundleErrorMessage;

  bool _isDisposed = false;
  Future<void>? _fetchInFlight;
  Future<void>? _fetchBundlesInFlight;

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

      final result = switch (scope) {
        GameListScope.library => await _service.fetchGames(),
        GameListScope.store => await _service.fetchStoreGames(),
      };
      if (!_isDisposed) games = result;
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchStoreBundles() {
    if (_isDisposed || scope != GameListScope.store) return Future.value();
    return _fetchBundlesInFlight ??=
        Future<void>.microtask(() async {
          try {
            bundleErrorMessage = null;
            bundles = await _bundleService.fetchStoreBundles();
          } catch (error) {
            bundleErrorMessage = error.toString();
          } finally {
            notifyListeners();
          }
        }).whenComplete(() {
          _fetchBundlesInFlight = null;
        });
  }
}
