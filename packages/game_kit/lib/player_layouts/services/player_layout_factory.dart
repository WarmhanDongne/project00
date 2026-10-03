// [player_layout_factory.dart] 는 인원과 게임 규칙에 맞는 자리 배치를 생성하는 파일이다.
//
// - [Package] : 게임 공통 기반
// - [PlayerLayout] : 태블릿의 플레이어 자리 배치와 편집 규칙을 관리함
//
// 즉, 인원과 기기 크기에 맞춰 자리를 안정적으로 배치하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'package:game_kit/player_layouts/models/player_layout.dart';
import 'package:game_kit/models/game_room_context.dart';

// ============================================================

//==========[ 기본 자리 배치 생성 ]==========
class PlayerLayoutFactory {
  //[순서배치] 방 참가자 순서를 좌석 번호로 사용해 기본 배치 생성
  static PlayerLayoutModel create(List<GameRoomPlayer> players) {
    return PlayerLayoutModel(
      players: List<PlayerLayoutPlayer>.unmodifiable(
        Iterable.generate(players.length, (index) {
          final player = players[index];

          return PlayerLayoutPlayer(
            uid: player.uid,
            nickname: player.nickname,
            characterId: player.characterId,

            //[좌석번호] 참가자 목록의 현재 순서를 그대로 사용
            seatIndex: index,
          );
        }),
      ),
    );
  }
}
