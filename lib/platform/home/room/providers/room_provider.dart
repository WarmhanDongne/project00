import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:project00/platform/home/room/models/room_player.dart';
import 'package:project00/platform/home/room/services/phone_room_command_service.dart';
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

  @override
  void dispose() {
    roomSubscription?.cancel();
    super.dispose();
  }
}
