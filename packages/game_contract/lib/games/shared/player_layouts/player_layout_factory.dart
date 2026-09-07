import 'package:game_contract/games/shared/player_layouts/player_layout_model.dart';
import 'package:game_contract/games/shared/models/game_room_context.dart';

class PlayerLayoutFactory {
  static PlayerLayoutModel create(List<GameRoomPlayer> players) {
    return PlayerLayoutModel(
      players: List.unmodifiable(
        List.generate(players.length, (index) {
          final player = players[index];

          return PlayerLayoutPlayer(
            uid: player.uid,
            nickname: player.nickname,
            characterId: player.characterId,

            seatIndex: index,
          );
        }),
      ),
    );
  }
}
