import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:project00/platform/home/room/models/room_player.dart';
import 'package:project00/platform/home/room/services/phone_room_command_service.dart';
import 'package:project00/platform/home/room/services/room_common.dart';
import 'package:project00/platform/home/room/services/room_service.dart';

class RoomProvider extends ChangeNotifier {
  // PhoneRoomCommandService 의존성 주입
  RoomProvider({PhoneRoomCommandService? commandService})
    : _commandService = commandService ?? RtdbPhoneRoomCommandService();
  final PhoneRoomCommandService _commandService;
  final RoomService _service = RoomService();

  String? roomCode;
  StreamSubscription<DatabaseEvent>? roomSubscription;
  List<RoomPlayer> players = [];
  bool isLoading = false;
  bool get isInRoom => roomCode != null; // 사용자가 Room 안인지 판단하는 기준 변수.

  String? errorMessage;
  String? selectedGameId;

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
    isLoading = true;
    roomCode = await _service.createRoom();
    isLoading = false;
    notifyListeners();
    listenRoom();
  }

  Future<bool> selectGame(String gameId) async {
    if (roomCode == null) return false;

    try {
      await _service.selectGame(roomCode: roomCode!, gameId: gameId);
      return true;
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  void listenRoom() {
    if (roomCode == null) return;

    roomSubscription?.cancel();

    roomSubscription = _service.watchRoom(roomCode!).listen((event) {
      // 나중에 event.snapshot.value를 읽어서
      // players 등을 갱신하면 됩니다.
      notifyListeners();
    });
  }

  // ============================================== Phone을 위한 CODE ====================================
  Future<bool> joinRoom(String rawRoomCode) async {
    // 지역 변수 선언
    final code = rawRoomCode.trim().toUpperCase();
    if (code.isEmpty) return false;

    final result = await _runCommand(() async {
      await _commandService.joinRoom(code);
      return true;
    });
    if (result == true) {
      roomCode = code;
      listenRoom();
    }
    return result ?? false;
  }

  @override
  void dispose() {
    roomSubscription?.cancel();
    super.dispose();
  }
}
