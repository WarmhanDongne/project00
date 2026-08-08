import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';

import '../services/liars_poker_command_service.dart';
import '../services/liars_poker_query_service.dart';

class LiarsPokerProvider extends ChangeNotifier {
  LiarsPokerProvider({
    LiarsPokerCommandService? command,
    LiarsPokerQueryService? query,
  }) : _command = command ?? LiarsPokerCommandService(),
       _query = query ?? LiarsPokerQueryService();

  final LiarsPokerCommandService _command;
  final LiarsPokerQueryService _query;

  StreamSubscription<DatabaseEvent>? _publicSubscription;
  StreamSubscription<DatabaseEvent>? _handSubscription;

  String? _roomCode;
  String? _uid;

  Map<String, dynamic> publicGame = {};
  List<dynamic> myHand = [];

  bool isLoading = false;

  String? errorMessage;

  // ===================== initialize =====================

  Future<void> initialize({
    required String roomCode,
    required String uid,
  }) async {
    _roomCode = roomCode;
    _uid = uid;

    await _publicSubscription?.cancel();
    await _handSubscription?.cancel();

    _publicSubscription =
        _query.watchPublicGame(roomCode).listen(_onPublicChanged);

    _handSubscription =
        _query.watchPrivateHand(
          roomCode: roomCode,
          uid: uid,
        ).listen(_onHandChanged);
  }

  // ===================== listeners =====================

  void _onPublicChanged(DatabaseEvent event) {
    final value = event.snapshot.value;

    if (value is Map) {
      publicGame = Map<String, dynamic>.from(value);
    } else {
      publicGame = {};
    }

    notifyListeners();
  }

  void _onHandChanged(DatabaseEvent event) {
    final value = event.snapshot.value;

    if (value is List) {
      myHand = value;
    } else if (value is Map) {
      myHand = value.values.toList();
    } else {
      myHand = [];
    }

    notifyListeners();
  }

  // ===================== commands =====================

  Future<void> startGame() async {
    if (_roomCode == null) return;

    await _runLoading(() async {
      await _command.startGame(
        roomCode: _roomCode!,
      );
    });
  }

  Future<void> submitCards(
    List<String> cardIds,
  ) async {
    if (_roomCode == null) return;

    await _runLoading(() async {
      await _command.submitCards(
        roomCode: _roomCode!,
        cardIds: cardIds,
      );
    });
  }

  Future<void> callLiar() async {
    if (_roomCode == null) return;

    await _runLoading(() async {
      await _command.callLiar(
        roomCode: _roomCode!,
      );
    });
  }

  Future<void> passChallenge() async {
    if (_roomCode == null) return;

    await _runLoading(() async {
      await _command.passLastCardChallenge(
        roomCode: _roomCode!,
      );
    });
  }

  Future<void> resolvePenalty(
    String result,
  ) async {
    if (_roomCode == null) return;

    await _runLoading(() async {
      await _command.resolvePenalty(
        roomCode: _roomCode!,
        result: result,
      );
    });
  }

  // ===================== common =====================

  Future<void> _runLoading(
    Future<void> Function() action,
  ) async {
    try {
      errorMessage = null;
      isLoading = true;
      notifyListeners();

      await action();
    } catch (e) {
      errorMessage = e.toString();
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _publicSubscription?.cancel();
    _handSubscription?.cancel();
    super.dispose();
  }
}