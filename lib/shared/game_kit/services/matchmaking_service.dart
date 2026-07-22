import 'package:project00/shared/game_kit/models/game_room_model.dart';

abstract interface class MatchmakingService {
  Future<GameRoomModel> createRoom();
  Future<GameRoomModel> joinRoom(String code);
}
