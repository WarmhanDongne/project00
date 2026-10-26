import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/phone/animations/card_receive_animation.dart';

void main() {
  const hint = '카드를 눌러 펼쳐 보세요';

  Future<void> pumpDeck(WidgetTester tester, {required bool showTapHint}) {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CardReceiveAnimation(
            cardCount: 4,
            cardWidth: 100,
            totalDuration: const Duration(milliseconds: 1000),
            showTapHint: showTapHint,
            cardBuilder: (context, index, front) =>
                ColoredBox(color: front ? Colors.white : Colors.blue),
          ),
        ),
      ),
    );
  }

  testWidgets('첫 배분에서는 덱이 멈춘 뒤 눌러서 펼치라고 안내하고, 누르면 안내를 거둔다', (tester) async {
    await pumpDeck(tester, showTapHint: true);
    // 덱이 내려오는 동안에는 아직 누를 수 없으므로 안내도 없습니다.
    expect(find.text(hint), findsNothing);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(hint), findsOneWidget);
    expect(find.byIcon(Icons.touch_app_rounded), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('카드 확인'));
    await tester.pump();
    expect(find.text(hint), findsNothing);
    expect(find.byIcon(Icons.touch_app_rounded), findsNothing);
  });

  testWidgets('안내를 끄면 덱만 떠 있고 안내 문구는 없다', (tester) async {
    await pumpDeck(tester, showTapHint: false);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.bySemanticsLabel('카드 확인'), findsOneWidget);
    expect(find.text(hint), findsNothing);
    expect(find.byIcon(Icons.touch_app_rounded), findsNothing);
  });
}
