import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_holdem/phone/widgets/top_bar.dart';
import 'package:game_kit/phone/widgets/game_top_bar.dart';

import '../support/fixtures.dart';

void main() {
  testWidgets('홀덤 휴대폰은 다른 게임과 같은 공용 상단 메뉴를 사용한다', (tester) async {
    var exited = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HoldemPhoneTopBar(
            game: playingState(),
            onExit: () => exited = true,
          ),
        ),
      ),
    );

    expect(find.byType(SharedPhoneGameTopBar), findsOneWidget);
    expect(find.textContaining('블라인드'), findsNothing);
    expect(find.bySemanticsLabel('게임 규칙 열기'), findsOneWidget);
    expect(find.bySemanticsLabel('게임과 그룹 나가기'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('게임과 그룹 나가기'));
    expect(exited, isTrue);

    await tester.tap(find.bySemanticsLabel('게임 규칙 열기'));
    await tester.pump(const Duration(milliseconds: 450));
    expect(find.text('TEXAS HOLD’EM'), findsOneWidget);
  });
}
