import 'package:project00/games/liars_poker/models/player_layout_model.dart';
import 'package:project00/platform/home/room/services/room_common.dart';

class PlayerLayoutFactory {
  static PlayerLayoutModel create(List<RoomPlayer> members) {
    return PlayerLayoutModel(
      players: List.unmodifiable(
        List.generate(members.length, (index) {
          final member = members[index];

          return PlayerLayoutPlayer(
            uid: member.uid,
            nickname: member.nickname,
            profileImageUrl: member.profileImageUrl,
            isHost: member.isHost,
            seatIndex: index,
          );
        }),
      ),
    );
  }
}
