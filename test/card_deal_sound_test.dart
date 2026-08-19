import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/games/shared/animations/card_deal.dart';

void main() {
  //=======================사운드는 연출을 막지 않는다==============================
  // 분배 애니메이션은 SoundProvider가 없는 환경에서도 그대로 돌아야 합니다.
  // 사운드는 보조 기능이라, 없다고 해서 카드 분배가 멈추면 게임이 진행되지
  // 않습니다. 위젯 테스트에는 Provider가 없으므로 이 조건을 그대로 검증합니다.
  testWidgets('SoundProvider가 없어도 카드 분배가 끝까지 재생된다', (tester) async {
    var completed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CardDealAnimation(
            playerCount: 4,
            cardsPerPlayer: 5,
            autoplay: true,
            duration: const Duration(milliseconds: 300),
            deckEntryDuration: const Duration(milliseconds: 60),
            cardBuilder: (context, playerIndex, cardIndex) =>
                const ColoredBox(color: Colors.white),
            onCompleted: () => completed = true,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(completed, isTrue);
  });
}
