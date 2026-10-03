import 'package:flutter_test/flutter_test.dart';
import 'package:game_final_call/shared/services/private_state_mapper.dart';
import 'package:game_final_call/shared/services/public_state_mapper.dart';

void main() {
  test('공개 플레이어와 문자열 목록을 서버 값에서 변환한다', () {
    final players = parseFinalCallPlayers({
      'u1': {'nickname': '민호', 'seatIndex': 1, 'team': 'blue', 'lives': 2},
    });

    expect(players['u1']?.nickname, '민호');
    expect(players['u1']?.team.name, 'blue');
    expect(parseFinalCallStringCollection({0: 'u1', 1: 'u2'}), ['u1', 'u2']);
  });

  test('개인 snapshot을 손패와 대기 카드로 구분한다', () {
    final snapshot = FinalCallPrivateSnapshot.fromValue({
      'hand': {
        'c1': {'id': 'c1', 'color': 'red', 'value': 7},
      },
      'pendingDraw': {'id': 'c2', 'color': 'blue', 'value': 3},
    });

    expect(snapshot.hand.single.id, 'c1');
    expect(snapshot.pendingDraw?.id, 'c2');
  });
}
