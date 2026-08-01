import 'package:project00/games/shared/models/game_room_model.dart';

abstract interface class RealtimeRoomService {
  Stream<GameRoomModel> watchRoom(String roomId);
  Future<void> leaveRoom(String roomId);
}
