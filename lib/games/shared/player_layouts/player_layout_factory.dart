import 'package:project00/games/shared/player_layouts/player_layout_model.dart';
import 'package:project00/platform/home/room/services/room_common.dart';

class PlayerLayoutFactory {
  static PlayerLayoutModel create(List<RoomPlayer> players) {
    return PlayerLayoutModel(
      players: List.unmodifiable(
        List.generate(players.length, (index) {
          final player = players[index];

          return PlayerLayoutPlayer(
            uid: player.uid,
            nickname: player.nickname,
            profileImageUrl: player.profileImageUrl,

            seatIndex: index,
          );
        }),
      ),
    );
  }
}
