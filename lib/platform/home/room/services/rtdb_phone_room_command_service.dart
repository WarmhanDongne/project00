import 'package:firebase_database/firebase_database.dart';
import 'package:project00/platform/home/room/services/phone_room_command_service.dart';

class RtdbPhoneRoomCommandService implements PhoneRoomCommandService {
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  @override
  Future<void> joinRoom(String roomCode) {
    // TODO: implement joinRoom
    throw UnimplementedError();
  }

  @override
  Future<void> leaveRoom(String roomCode) {
    // TODO: implement leaveRoom
    throw UnimplementedError();
  }

  @override
  Future<void> setReady({required String roomCode, required bool isReady}) {
    // TODO: implement setReady
    throw UnimplementedError();
  }
}
