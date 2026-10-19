import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/phone/widgets/rulebook_dialog.dart';

void main() {
  Future<void> pump(WidgetTester tester, String markdown, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PhoneGameRulebookDialog(title: 'TEST', markdown: markdown),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('`#` 제목이 없으면 `##` 제목으로 항목을 나눈다', (tester) async {
    await pump(
      tester,
      '## 진행 순서\n\n밤 → 낮\n\n## 밤\n\n마피아가 고릅니다.',
      const Size(390, 844),
    );
    expect(find.bySemanticsLabel('진행 순서'), findsOneWidget);
    expect(find.bySemanticsLabel('밤'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('밤'));
    await tester.pump();
    expect(find.textContaining('마피아가 고릅니다'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('`#` 제목이 있으면 그 아래 `##`는 본문에 남긴다', (tester) async {
    await pump(
      tester,
      '# 게임 목표\n\n이기세요.\n\n## 세부\n\n내용\n\n# 내 차례\n\n뽑으세요.',
      const Size(844, 390),
    );
    expect(find.bySemanticsLabel('게임 목표'), findsOneWidget);
    expect(find.bySemanticsLabel('내 차례'), findsOneWidget);
    // `## 세부`는 첫 항목 본문 안에 남습니다.
    expect(find.textContaining('내용'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('내 차례'));
    await tester.pump();
    expect(find.textContaining('뽑으세요'), findsOneWidget);
    expect(find.textContaining('내용'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
