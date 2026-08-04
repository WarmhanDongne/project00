import 'package:flutter_test/flutter_test.dart';
import 'package:project00/platform/home/gamelist/models/game_info.dart';
import 'package:project00/platform/home/room/models/room_data.dart';
import 'package:project00/platform/home/room/models/room_device.dart';
import 'package:project00/platform/home/room/models/room_player.dart';
import 'package:project00/platform/home/room/models/user_room.dart';

void main() {
  group('Firestore DTO', () {
    test('games 문서의 실제 필드명을 변환한다', () {
      final game = GameInfo.fromJson({
        'id': 'liars_poker',
        'name': "Liar's Poker",
        'description': '거짓말과 심리전으로 살아남는 카드 게임',
        'enabled': true,
        'genres': ['Bluff', 'Card', 'Psychology'],
        'imageUrl': 'https://example.com/poster.png',
        'maxPlayers': 6,
        'minPlayers': 2,
        'order': 1,
        'playTime': 20,
        'ruleVideoUrl': null,
      });

      expect(game.id, 'liars_poker');
      expect(game.playTime, 20);
      expect(game.order, 1);
      expect(game.enabled, isTrue);
      expect(game.genres, ['Bluff', 'Card', 'Psychology']);
      expect(game.ruleVideoUrl, isEmpty);
      expect(game.description, '거짓말과 심리전으로 살아남는 카드 게임');
    });

    test('rooms 문서 필드를 변환한다', () {
      final room = RoomData.fromJson({
        'code': '3298Y',
        'gameId': 'liars_poker',
        'hostUid': 'host-uid',
        'maxMembers': 6,
        'memberCount': 0,
        'selectedGameId': 'liars_poker',
        'currentMatchId': null,
        'status': 'waiting',
      });

      expect(room.code, '3298Y');
      expect(room.selectedGameId, 'liars_poker');
      expect(room.currentMatchId, isNull);
    });

    test('userRooms, devices, members 문서 필드를 변환한다', () {
      final userRoom = UserRoom.fromJson({
        'uid': 'host-uid',
        'roomCode': '3298Y',
      });
      final device = RoomDevice.fromJson({'uid': 'host-uid', 'role': 'table'});
      final member = RoomMember.fromJson({
        'uid': 'player-uid',
        'nickname': '플레이어',
        'role': 'player',
        'status': 'active',
        'isReady': false,
      });

      expect(userRoom.roomCode, '3298Y');
      expect(device.isTable, isTrue);
      expect(member.isPlayer, isTrue);
      expect(member.isActive, isTrue);
    });
  });
}
