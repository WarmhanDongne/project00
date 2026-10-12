import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_final_call/phone/widgets/top_bar.dart';
import 'package:game_kit/phone/widgets/rulebook_dialog.dart';

Future<void> _open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(844, 390);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showFinalCallRules(context),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('휴대폰 규칙 화면은 왼쪽 항목을 고르면 오른쪽 본문이 바뀐다', (tester) async {
    await _open(tester);
    expect(find.byType(PhoneGameRulebookDialog), findsOneWidget);
    // 왼쪽에는 모든 항목이, 오른쪽에는 첫 항목의 본문이 보입니다.
    for (final title in ['게임 목표', '시작할 때', '점수 계산', '내 차례', 'CALL 선언']) {
      expect(find.text(title), findsWidgets);
    }
    expect(find.textContaining('마지막 한 팀이 승리'), findsOneWidget);
    expect(find.textContaining('카드 더미 또는 공개된 카드'), findsNothing);

    await tester.tap(find.text('내 차례'));
    await tester.pumpAndSettle();
    expect(find.textContaining('카드 더미 또는 공개된 카드'), findsOneWidget);
    expect(find.textContaining('마지막 한 팀이 승리'), findsNothing);
    // 항목을 골라도 화면은 닫히지 않습니다.
    expect(find.byType(PhoneGameRulebookDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('휴대폰 규칙 화면은 닫기 버튼이나 판 바깥을 누르면 닫힌다', (tester) async {
    await _open(tester);
    await tester.tap(find.byTooltip('닫기'));
    await tester.pumpAndSettle();
    expect(find.byType(PhoneGameRulebookDialog), findsNothing);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(find.byType(PhoneGameRulebookDialog), findsNothing);
  });
}
