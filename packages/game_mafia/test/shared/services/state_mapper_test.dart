import 'package:flutter_test/flutter_test.dart';
import 'package:game_mafia/shared/services/private_state_mapper.dart';
import 'package:game_mafia/shared/services/public_state_mapper.dart';

void main() {
  test('공개 플레이어를 좌석 순서로 정렬하고 공개 신분을 변환한다', () {
    final players = parseMafiaPlayers({
      'u2': {'nickname': '둘', 'seatIndex': 2},
      'u1': {'nickname': '하나', 'seatIndex': 0},
    });

    expect(players.keys, ['u1', 'u2']);
    expect(parseMafiaStringMap({'u1': 'citizen'}), {'u1': 'citizen'});
  });

  test('개인 snapshot은 가장 최근 조사 기록을 선택한다', () {
    final snapshot = MafiaPrivateSnapshot.fromValue({
      'roleId': 'detective',
      'investigations': {
        '1': {'round': 1, 'targetUid': 'u1', 'verdict': '시민'},
        '3': {'round': 3, 'targetUid': 'u2', 'verdict': '마피아'},
      },
      'allySelections': {'u3': 'u2'},
    });

    expect(snapshot.roleId, 'detective');
    expect(snapshot.latestInvestigation?.round, 3);
    expect(snapshot.latestInvestigation?.targetUid, 'u2');
    expect(snapshot.allySelections, {'u3': 'u2'});
  });
}
