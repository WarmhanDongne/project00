import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:project00/platform/home/room/services/room_common.dart';
import 'package:project00/platform/home/gamelist/models/game_info.dart';
import 'package:project00/platform/home/gamelist/service/game_list_service.dart';
import 'package:project00/platform/home/room/services/room_service.dart';

class RoomProvider extends ChangeNotifier {
  final RoomService _service = RoomService();
  final GameService _gameService = GameService();

  String? roomCode;
  StreamSubscription<DatabaseEvent>? roomSubscription;

  StreamSubscription<List<RoomPlayer>>? playerSubscription;

  List<RoomPlayer> players = [];
  bool isLoading = false;
  bool get isInRoom => roomCode != null; // 사용자가 Room 안인지 판단하는 기준 변수.

  String? errorMessage;
  String? selectedGameId;
  GameInfo? selectedGame;

  // phone용 공통함수
  Future<T?> _runCommand<T>(Future<T> Function() command) async {
    // 로딩 시작 및 이전 에러 초기화
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      return await command();
    } on RoomCommandException catch (error) {
      // 비즈니스 로직 예외 처리
      errorMessage = error.message;
      return null;
    } catch (error) {
      // 기타 일반 예외 처리
      errorMessage = error.toString();
      return null;
    } finally {
      // 로딩 종료 및 UI 갱신
      isLoading = false;
      notifyListeners();
    }
  }

  Future<List<RoomPlayer>> getRoomPlayers(String roomCode) async {
    players = await _service.getRoomPlayers(roomCode);
    notifyListeners();
    return players;
  }

  Future<void> createRoom() async {
    final code = await _runCommand<String>(() async {
      return await _service.createRoom();
    });

    if (code != null) {
      roomCode = code;
      listenRoom();
    }
  }

  Future<bool> selectGame(String gameId) async {
    if (roomCode == null) return false;

    final result = await _runCommand<bool>(() async {
      await _service.selectGame(roomCode: roomCode!, gameId: gameId);
      return true;
    });

    return result ?? false;
  }

  Future<bool> removePlayer(String userUid) async {
    final result = await _runCommand<bool>(() async {
      await _service.removePlayer(roomCode!, userUid);
      return true;
    });
    return result ?? false;
  }

  Future<bool> savePlayerSeatIndexes(Map<String, int> seatIndexesByUid) async {
    final code = roomCode;
    if (code == null) {
      errorMessage = '방 정보를 확인할 수 없습니다.';
      notifyListeners();
      return false;
    }

    final result = await _runCommand<bool>(() async {
      await _service.savePlayerSeatIndexes(
        roomCode: code,
        seatIndexesByUid: seatIndexesByUid,
      );
      return true;
    });

    return result ?? false;
  }

  void listenRoom() {
    if (roomCode == null) return;

    roomSubscription?.cancel();
    playerSubscription?.cancel();

    roomSubscription = _service.watchRoom(roomCode!).listen((event) async {
      final value = event.snapshot.value;

      if (value is Map) {
        final gameId = value['selectedGame'] as String?;

        if (gameId != selectedGameId) {
          selectedGameId = gameId;

          if (gameId != null) {
            selectedGame = await _gameService.getGame(gameId);
          } else {
            selectedGame = null;
          }
        }
      }

      notifyListeners();
    }, onError: _handleSubscriptionError);
    playerSubscription = _service.watchRoomPlayers(roomCode!).listen((
      roomPlayer,
    ) {
      players = roomPlayer;
      notifyListeners();
    }, onError: _handleSubscriptionError);
  }

  void _handleSubscriptionError(Object error) {
    errorMessage = error.toString();
    notifyListeners();
  }

  // ============================================== Phone을 위한 CODE ========================================
  Future<bool> joinRoom(String rawRoomCode, String nickname) async {
    // Room code 받기
    final code = rawRoomCode.trim().toUpperCase();
    if (code.isEmpty) return false;

    // joinRoom 실행
    final result = await _runCommand(() async {
      await _service.joinRoom(code, nickname); // 서비스에 roomcode와 nickname 전달
      return true;
    });

    // return 분기
    if (result == true) {
      roomCode = code;
      listenRoom();
    }
    return result ?? false;
  }

  Future<bool> leaveRoom() async {
    final code = roomCode;
    if (code == null) return false;

    final result = await _runCommand<bool>(() async {
      await _service.leaveRoom(code);
      return true;
    });
    if (result == true) {
      clearRoom();
    }
    return result ?? false;
  }

  // 메모리 초기화 leaveRoom에서 사용
  void clearRoom() {
    roomSubscription?.cancel();
    roomCode = null;
    players = [];
    selectedGameId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    roomSubscription?.cancel();
    playerSubscription?.cancel();
    super.dispose();
  }
}
