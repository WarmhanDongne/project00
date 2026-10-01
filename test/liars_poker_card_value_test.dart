import 'package:flutter_test/flutter_test.dart';
import 'package:game_liars_poker/shared/models/game_models.dart';

void main() {
  test('RTDB rank 키를 cardValue로 변환한다', () {
    final card = PhoneHandCard.fromMap('card-1', {'id': 'card-1', 'rank': 'q'});

    expect(card, isNotNull);
    expect(card!.cardValue, 'Q');
  });

  test('RTDB 제출 카드 키를 cardValue 계열 필드로 변환한다', () {
    final play = PublicLastPlay.tryParse({
      'playId': 'play-1',
      'round': 1,
      'playerUid': 'player-1',
      'cardCount': 2,
      'declaredRank': 'K',
      'revealed': true,
      'actualRanks': ['Q', 'JOKER'],
      'submittedAt': 100,
    });

    expect(play, isNotNull);
    expect(play!.declaredCardValue, 'K');
    expect(play.actualCardValues, ['Q', 'JOKER']);
  });
}
