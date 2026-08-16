import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:project00/games/game_registry.dart';
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
  List<GameInfo> groupGames = [];
  bool isLoading = false;
  bool get isInRoom => roomCode != null; // 사용자가 Room 안인지 판단하는 기준 변수.

  String? errorMessage;
  String? selectedGameId;
  GameInfo? selectedGame;

  bool _isDisposed = false;

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

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

  /// 휴대폰 대기실에서 게임 종류와 무관하게 시작 상태를 한 번만 구독합니다.
  Stream<String?> watchGameStatus(String code) =>
      _service.watchGameStatus(code.trim().toUpperCase());

  /// 태블릿이 방을 열고 있는지 구독합니다. 휴대폰이 무한 대기하지 않도록
  /// 태블릿이 사라지면 알려 줍니다.
  Stream<bool?> watchControllerConnected(String code) =>
      _service.watchControllerConnected(code.trim().toUpperCase());

  /// 태블릿이 방 화면을 열고 있는 동안 접속 표시를 유지합니다.
  Future<void> markControllerConnected() async {
    final code = roomCode;
    if (code == null) return;
    try {
      await _service.markControllerConnected(code);
    } catch (_) {
      // 접속 표시 실패가 방 진행을 막지 않습니다.
    }
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

    roomSubscription = _service.watchRoom(roomCode!).listen((event) {
      final gameId = event.snapshot.value as String?;

      if (gameId != selectedGameId) {
        selectedGameId = gameId;
        selectedGame = null;
        // 게임 시작 판단에 필요한 ID는 Firestore 메타데이터보다 먼저 전달합니다.
        notifyListeners();

        if (gameId != null) {
          unawaited(_loadSelectedGame(gameId));
        }
      }
    }, onError: _handleSubscriptionError);
    playerSubscription = _service.watchRoomPlayers(roomCode!).listen((
      roomPlayer,
    ) async {
      players = roomPlayer;
      // 활성화된 유저의 uids 추출
      final activeUids = players
          .where((p) => p.isActive)
          .map((p) => p.uid)
          .toList(growable: false);
      // 활성화된 유저들이 보유한 gameInfo 객체 리스트 노티
      groupGames = await _gameService.fetchGroupGames(activeUids);
      notifyListeners();
    }, onError: _handleSubscriptionError);
  }

  /// 썸네일·설명 같은 화면용 Firestore 정보는 게임 시작 신호와 분리해 불러옵니다.
  /// 조회가 늦거나 실패해도 Realtime Database의 게임 시작 처리는 계속됩니다.
  Future<void> _loadSelectedGame(String gameId) async {
    try {
      final game = await _gameService.getGame(gameId);
      if (selectedGameId != gameId) return;
      selectedGame = game;
      notifyListeners();
    } catch (_) {
      // 게임 ID와 RTDB 상태만으로 게임 화면을 열 수 있으므로 메타데이터 실패는
      // 대기실의 시작 흐름을 중단하지 않습니다.
    }
  }

  void _handleSubscriptionError(Object error) {
    final message = error.toString().toLowerCase();
    // Realtime Database 스트림은 네트워크 복구 시 자동으로 다시 연결됩니다.
    // iOS 플러그인의 native unknown Stacktrace는 화면에 노출하지 않습니다.
    if (message.contains('firebase_database/unknown') ||
        message.contains('stacktrace:')) {
      errorMessage = null;
      notifyListeners();
      return;
    }
    errorMessage = error.toString();
    notifyListeners();
  }

  // ============================================== Phone을 위한 메서드 ========================================
  Future<bool> joinRoom(
    String rawRoomCode,
    String nickname, {
    String accentColor = '#6557D2',
  }) async {
    // Room code 받기
    final code = rawRoomCode.trim().toUpperCase();
    if (code.isEmpty) return false;

    // joinRoom 실행
    final result = await _runCommand(() async {
      await _service.joinRoom(code, nickname, accentColor: accentColor);
      return true;
    });

    // return 분기
    if (result == true) {
      roomCode = code;
      listenRoom();
    }
    return result ?? false;
  }

  Future<bool> updateJoinedPlayerProfile(
    String nickname, {
    required String accentColor,
  }) async {
    final code = roomCode;
    if (code == null) return false;
    final result = await _runCommand<bool>(() async {
      await _service.updateRoomPlayerProfile(
        code,
        nickname,
        accentColor: accentColor,
      );
      return true;
    });
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

  /// 게임 중 퇴장: 서버가 다음 턴 또는 인원 부족 종료까지 결정합니다.
  Future<bool> leaveGame(String gameId) async {
    final code = roomCode;
    final game = GameRegistry.find(gameId);
    if (code == null || game == null) return false;

    final result = await _runCommand<bool>(() async {
      await _service.leaveGame(
        cloudFunctionName: game.leaveFunctionName,
        roomCode: code,
      );
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
    playerSubscription?.cancel();
    roomSubscription = null;
    playerSubscription = null;
    roomCode = null;
    players = [];
    selectedGameId = null;
    selectedGame = null;
    groupGames = [];
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    roomSubscription?.cancel();
    playerSubscription?.cancel();
    super.dispose();
  }
}
