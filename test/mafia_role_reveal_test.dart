import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/games/mafia/models/mafia_roles.dart';
import 'package:project00/games/mafia/widgets/phone/role_reveal_view.dart';

//=======================P1 역할 카드 확인 연출==============================
// 확정 흐름: 아래(뒷면) → 탭 → 중앙으로 → 뒤집기(확인 처리·문구) → 3초
// → 다시 뒤집기 → 아래로.
void main() {
  const size = Size(402, 874);

  Future<void> pumpView(
    WidgetTester tester, {
    VoidCallback? onRevealed,
    bool initiallyRevealed = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: MafiaRoleRevealView(
          role: MafiaRoles.find('citizen'),
          initiallyRevealed: initiallyRevealed,
          onRevealed: onRevealed,
        ),
      ),
    );
  }

  Finder card() => find.descendant(
    of: find.byType(MafiaRoleRevealView),
    matching: find.byType(GestureDetector),
  );

  // 아래에 꽂힌 카드는 위쪽 일부만 화면에 보이므로 그 부분을 누릅니다.
  // (카드 중심은 화면 밖이라 tester.tap(card())는 빗나갑니다.)
  Future<void> tapStoredCard(WidgetTester tester) =>
      tester.tapAt(const Offset(201, 820));

  testWidgets('카드가 아래(보관 자리)에서 시작하고 문구는 없다', (tester) async {
    await pumpView(tester);

    expect(tester.getTopLeft(card()).dy, closeTo(776, 0.5));
    expect(find.textContaining('당신은'), findsNothing);
  });

  testWidgets('누르면 중앙으로 올라와 뒤집히고 확인 처리와 설명이 나온다', (tester) async {
    var revealed = 0;
    await pumpView(tester, onRevealed: () => revealed += 1);

    await tapStoredCard(tester);
    // 올라오는 중에는 아직 확인 처리가 없습니다.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(revealed, 0);

    // 슬라이드(520ms)·뒤집기(620ms)가 끝나면 중앙에서 공개된 상태로 멈춥니다.
    // (3초 보여 주기는 프레임이 아니라 Timer라 settle이 여기서 멈춥니다.)
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(card()).dy, closeTo(208, 0.5));
    expect(revealed, 1);
    expect(find.textContaining('당신은'), findsOneWidget);
    expect(find.textContaining('입니다'), findsWidgets);
  });

  testWidgets('3초 보여 준 뒤 다시 뒤집혀 아래로 돌아간다', (tester) async {
    await pumpView(tester, onRevealed: () {});

    await tapStoredCard(tester);
    await tester.pumpAndSettle();
    expect(find.textContaining('당신은'), findsOneWidget);

    // 3초 대기 → 문구가 사라지고 다시 뒤집힌 뒤 아래(보관 자리)로 돌아갑니다.
    await tester.pump(const Duration(seconds: 3));
    expect(find.textContaining('당신은'), findsNothing);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(card()).dy, closeTo(776, 0.5));
  });

  testWidgets('재접속 복원은 힌트 없이 아래에 멈춰 있고 다시 눌리지 않는다', (tester) async {
    var revealed = 0;
    await pumpView(
      tester,
      onRevealed: () => revealed += 1,
      initiallyRevealed: true,
    );

    expect(tester.getTopLeft(card()).dy, closeTo(776, 0.5));
    await tapStoredCard(tester);
    await tester.pump(const Duration(seconds: 5));
    expect(revealed, 0);
    expect(tester.getTopLeft(card()).dy, closeTo(776, 0.5));
  });
}
