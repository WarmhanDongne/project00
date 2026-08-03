import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:project00/platform/home/room/models/room_member.dart';
import 'package:project00/platform/home/room/services/room_service.dart';

class RoomProvider extends ChangeNotifier {
  final RoomService _service = RoomService();

  String? roomCode;
  StreamSubscription<DatabaseEvent>? roomSubscription;
  StreamSubscription<List<RoomMember>>? memberSubscription;
  List<RoomMember> members = [];
  bool isLoading = false;

  String? errorMessage;
  String? selectedGameId;

  Future<List<RoomMember>> getRoomPlayers(String roomCode) async {
    members = await _service.getRoomPlayers(roomCode);
    notifyListeners();
    return members;
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

  Future<bool> savePlayerSeatIndexes(Map<String, int> seatIndexesByUid) async {
    final code = roomCode;
    if (code == null) {
      errorMessage = '방 정보를 확인할 수 없습니다.';
      notifyListeners();
      return false;
    }

    try {
      await _service.savePlayerSeatIndexes(
        roomCode: code,
        seatIndexesByUid: seatIndexesByUid,
      );
      errorMessage = null;
      return true;
    } catch (error) {
      errorMessage = error.toString();
      notifyListeners();
      return false;
    }
  }

  void listenRoom() {
    if (roomCode == null) return;

    roomSubscription?.cancel();
    memberSubscription?.cancel();

    roomSubscription = _service.watchRoom(roomCode!).listen((event) {
      final value = event.snapshot.value;
      if (value is Map) {
        final selectedGame = value['selectedGame'];
        selectedGameId = selectedGame is String ? selectedGame : null;
      }
      notifyListeners();
    }, onError: _handleSubscriptionError);
    memberSubscription = _service.watchRoomPlayers(roomCode!).listen((
      roomMembers,
    ) {
      members = roomMembers;
      notifyListeners();
    }, onError: _handleSubscriptionError);
  }

  void _handleSubscriptionError(Object error) {
    errorMessage = error.toString();
    notifyListeners();
  }

  @override
  void dispose() {
    roomSubscription?.cancel();
    memberSubscription?.cancel();
    super.dispose();
  }
}
