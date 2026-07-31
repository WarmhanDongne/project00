import 'package:project00/platform/hub/providers/room_session_provider.dart';
import 'package:project00/platform/hub/services/mobile_room_command_service.dart';

class MobileRoomProvider extends RoomSessionProvider {
  MobileRoomProvider({
    super.queryService,
    MobileRoomCommandService? commandService,
  }) : _commandService = commandService ?? FirebaseMobileRoomCommandService();

  final MobileRoomCommandService _commandService;

  Future<bool> joinRoom(String rawRoomCode) async {
    final roomCode = rawRoomCode.trim().toUpperCase();
    if (roomCode.isEmpty) return false;

    final result = await runCommand(() async {
      await _commandService.joinRoom(roomCode);
      return true;
    });
    if (result == true) {
      await attachRoom(roomCode);
    }
    return result ?? false;
  }

  Future<bool> setReady(bool isReady) async {
    final code = roomCode;
    if (code == null) return false;

    final result = await runCommand(() async {
      await _commandService.setReady(roomCode: code, isReady: isReady);
      return true;
    });
    return result ?? false;
  }

  Future<bool> leaveRoom() async {
    final code = roomCode;
    if (code == null) return false;

    final result = await runCommand(() async {
      await _commandService.leaveRoom(code);
      return true;
    });
    if (result == true) {
      await clearRoom();
    }
    return result ?? false;
  }
}
