import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/games/final_call/widgets/phone/game_actions.dart';

void main() {
  testWidgets('초기 조작 안내 화살표가 카드 쪽에서 버튼 방향으로 바운스한다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: FinalCallPrimaryActionHint(
              child: SizedBox(width: 120, height: 160),
            ),
          ),
        ),
      ),
    );

    final topFinder = find.byKey(const Key('final-call-action-hint-top'));
    final bottomFinder = find.byKey(const Key('final-call-action-hint-bottom'));
    expect(topFinder, findsOneWidget);
    expect(bottomFinder, findsOneWidget);

    final initialTop = tester
        .widget<Transform>(topFinder)
        .transform
        .storage[12];
    final initialBottom = tester
        .widget<Transform>(bottomFinder)
        .transform
        .storage[12];
    await tester.pump(const Duration(milliseconds: 340));
    final movedTop = tester.widget<Transform>(topFinder).transform.storage[12];
    final movedBottom = tester
        .widget<Transform>(bottomFinder)
        .transform
        .storage[12];

    expect(movedTop, greaterThan(initialTop));
    expect(movedBottom, greaterThan(initialBottom));
  });
}
