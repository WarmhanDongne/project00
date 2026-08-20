import 'package:flutter_test/flutter_test.dart';
import 'package:project00/platform/home/room/models/room_character.dart';
import 'package:project00/platform/home/room/models/room_player.dart';

void main() {
  group('room character catalog', () {
    test('모든 캐릭터 ID와 에셋 경로가 고유하다', () {
      final ids = roomCharacters.map((character) => character.id).toSet();
      final paths = roomCharacters
          .map((character) => character.assetPath)
          .toSet();

      expect(ids.length, roomCharacters.length);
      expect(paths.length, roomCharacters.length);
      expect(roomCharacters, hasLength(17));
      expect(ids, contains(defaultRoomCharacterId));
    });

    test('알 수 없는 ID는 기본 캐릭터 에셋으로 대체한다', () {
      expect(
        roomCharacterAssetPath('legacy-character'),
        roomCharacterAssetPath(defaultRoomCharacterId),
      );
    });

    test('마이그레이션 전 RoomPlayer는 기본 캐릭터를 사용한다', () {
      final player = RoomPlayer.fromJson({
        'uid': 'player-1',
        'nickname': '플레이어',
        'isConnected': true,
      });

      expect(player.characterId, defaultRoomCharacterId);
      expect(player.toJson()['characterId'], defaultRoomCharacterId);
      expect(player.toJson(), isNot(contains('profileImageUrl')));
      expect(player.toJson(), isNot(contains('accentColor')));
    });
  });
}
