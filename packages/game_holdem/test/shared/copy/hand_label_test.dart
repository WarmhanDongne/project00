import 'package:flutter_test/flutter_test.dart';
import 'package:game_holdem/game_copy.dart';
import 'package:game_holdem/game_theme.dart';
import 'package:game_holdem/shared/models/game_models.dart';

List<HoldemCardModel> _cards(List<(String, String)> values) => [
  for (final (rank, suit) in values)
    HoldemCardModel(id: '${rank}_$suit', rank: rank, suit: suit),
];

void main() {
  test('족보 설명은 대표 rank와 무늬를 함께 보여 준다', () {
    expect(
      HoldemCopy.handLabel(
        'onePair',
        _cards([('k', 'diamonds'), ('k', 'spades'), ('q', 'diamonds')]),
      ),
      '원 페어 · K',
    );
    expect(
      HoldemCopy.handLabel(
        'flush',
        _cards([
          ('a', 'spades'),
          ('k', 'spades'),
          ('j', 'spades'),
          ('7', 'spades'),
          ('2', 'spades'),
        ]),
      ),
      '스페이드 플러시 · A 하이',
    );
    expect(
      HoldemCopy.handLabel(
        'straight',
        _cards([
          ('a', 'hearts'),
          ('2', 'clubs'),
          ('3', 'spades'),
          ('4', 'clubs'),
          ('5', 'diamonds'),
        ]),
      ),
      '스트레이트 · 5 하이',
    );
    expect(
      HoldemCopy.handLabel(
        'fullHouse',
        _cards([
          ('9', 'hearts'),
          ('9', 'clubs'),
          ('9', 'spades'),
          ('k', 'clubs'),
          ('k', 'diamonds'),
        ]),
      ),
      '풀하우스 · 9, K',
    );
    expect(
      HoldemCopy.handLabel(
        'straightFlush',
        _cards([
          ('a', 'hearts'),
          ('k', 'hearts'),
          ('q', 'hearts'),
          ('j', 'hearts'),
          ('10', 'hearts'),
        ]),
      ),
      '하트 로열 플러시',
    );
    expect(HoldemCopy.handLabel('highCard', const []), '하이 카드');
  });

  test('태블릿 좌석 족보는 짧게 줄인다', () {
    expect(
      HoldemCopy.shortHandLabel(
        'threeOfAKind',
        _cards([('k', 'hearts'), ('k', 'diamonds'), ('k', 'spades')]),
      ),
      '트리플 K',
    );
    expect(
      HoldemCopy.shortHandLabel('flush', _cards([('a', 'spades')])),
      '플러시',
    );
  });

  test('행동 문장과 칩 금액을 읽기 쉽게 만든다', () {
    expect(HoldemCopy.actionSentence('하준', 'bet', 400), '하준 님이 400 벳 했어요');
    expect(HoldemCopy.actionSentence('하준', 'check', 0), '하준 님이 체크 했어요');
    expect(holdemChips(1234567), '1,234,567');
    expect(holdemChips(800), '800');
  });
}
