import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:project00/platform/home/room/models/room_member.dart';
import 'package:project00/platform/home/room/services/room_service.dart';

class RoomProvider extends ChangeNotifier {
  final RoomService _service = RoomService();

  String? roomCode;
  StreamSubscription<DatabaseEvent>? roomSubscription;
  List<RoomMember> members = [];
  bool isLoading = false;

  String? errorMessage;
  String? selectedGameId;

  Future<void> createRoom() async {
    isLoading = true;
    notifyListeners();

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
      // members 등을 갱신하면 됩니다.

      notifyListeners();
    });
  }

  @override
  void dispose() {
    roomSubscription?.cancel();
    super.dispose();
  }
}
