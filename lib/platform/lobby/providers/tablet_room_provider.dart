import 'package:project00/platform/lobby/providers/room_session_provider.dart';
import 'package:project00/platform/lobby/services/tablet_room_command_service.dart';

class TabletRoomProvider extends RoomSessionProvider {
  TabletRoomProvider({
    super.queryService,
    TabletRoomCommandService? commandService,
  }) : _commandService = commandService ?? FirebaseTabletRoomCommandService();

  final TabletRoomCommandService _commandService;

  Future<bool> createRoom() async {
    final roomCode = await runCommand(_commandService.createOrLoadRoom);
    if (roomCode != null) {
      await attachRoom(roomCode);
      return true;
    }
    return false;
  }

  Future<bool> resetRoom() async {
    final roomCode = await runCommand(_commandService.resetRoom);
    if (roomCode != null) {
      await attachRoom(roomCode);
      return true;
    }
    return false;
  }

  Future<bool> selectGame(String gameId) async {
    final code = roomCode;
    if (code == null) return false;

    final result = await runCommand(() async {
      await _commandService.selectGame(roomCode: code, gameId: gameId);
      return true;
    });
    return result ?? false;
  }
}
