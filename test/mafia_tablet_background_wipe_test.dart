import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/games/mafia/screens/tablet/tablet_game_layout.dart';

//=======================낮↔밤 라디얼 와이프==============================
// 배경이 바뀔 때 옛 배경 위로 새 배경이 쓸려 들어오고(두 겹), 끝나면 옛
// 배경이 정리되는지(한 겹) 확인합니다.
void main() {
  testWidgets('밤으로 바뀌면 전환 중 두 겹, 끝나면 한 겹이 된다', (tester) async {
    tester.view.physicalSize = const Size(1194, 834);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    Widget wrap(bool isNight) =>
        MaterialApp(home: MafiaTabletBackground(isNight: isNight));

    await tester.pumpWidget(wrap(false));
    expect(find.byType(Image), findsOneWidget);

    // 밤으로 전환 — 와이프(900ms) 동안 옛 낮 + 새 밤이 함께 있습니다.
    await tester.pumpWidget(wrap(true));
    await tester.pump(); // 와이프 시작 프레임
    await tester.pump(const Duration(milliseconds: 450));
    expect(find.byType(Image), findsNWidgets(2));
    expect(find.byType(ClipPath), findsOneWidget);

    // 끝나면 옛 배경이 내려가 한 겹만 남습니다.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('같은 시간대로 다시 그려지면 전환이 없다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: MafiaTabletBackground(isNight: true)),
    );
    await tester.pumpWidget(
      const MaterialApp(home: MafiaTabletBackground(isNight: true)),
    );
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(ClipPath), findsNothing);
  });
}
