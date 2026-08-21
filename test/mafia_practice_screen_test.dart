import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/games/mafia/dev/mafia_practice_screen.dart';
import 'package:project00/games/mafia/screens/tablet/tablet_game_layout.dart';
import 'package:project00/games/mafia/widgets/phone/night_action_view.dart';
import 'package:project00/games/mafia/widgets/phone/role_card_layer.dart';

//=======================마피아 연습장 연기 테스트==============================
// 연습장이 실제 화면·컨트롤러·엔진을 묶어 한 판을 굴릴 수 있는지 봅니다.
// 흐름: P1 카드 확인 → 봇 전원 확인 → 10초 → 안내 2.5초 → 밤 → 태블릿 보기.
void main() {
  testWidgets('연습장에서 역할 확인부터 밤까지 흘러간다', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: MafiaPracticeScreen())),
    );
    // 첫 발행(마이크로태스크)을 받아 역할 확인 화면이 뜹니다.
    await tester.pump();
    await tester.pump();
    expect(find.byType(MafiaPhoneRoleCardLayer), findsOneWidget);

    // 신분을 처음 받을 때는 카드가 화면 위에서 내려와 가운데에 섭니다.
    // 다 내려온 뒤에 눌러야 확인이 됩니다(확정 흐름).
    await tester.pump(MafiaPhoneRoleCardLayer.travelDuration);
    await tester.pump(const Duration(milliseconds: 16));
    final phone = tester.getRect(find.byType(MafiaPhoneRoleCardLayer));
    await tester.tapAt(
      Offset(phone.center.dx, phone.top + phone.height * 0.45),
    );
    // 뒤집기(620ms) → 문구(0.3초 뒤) 까지 돌립니다.
    for (var i = 0; i < 3; i += 1) {
      await tester.pump(const Duration(seconds: 1));
    }

    // 봇 5명이 순서대로 확인합니다(봇 지연 2초 간격).
    await tester.pump(const Duration(seconds: 11));
    // 전원 확인 → 10초 → '밤이 됐습니다' 2.5초 → 밤.
    await tester.pump(const Duration(seconds: 10));
    await tester.pump(const Duration(milliseconds: 2600));
    await tester.pump();
    expect(find.byType(MafiaNightActionView), findsOneWidget);

    // 태블릿 보기로 바꾸면 밤 화면(달)이 보입니다.
    await tester.tap(find.text('태블릿'));
    await tester.pump();
    expect(find.byType(MafiaTabletMoon), findsOneWidget);

    // 화면을 내려 엔진·타이머가 모두 정리되는지 확인합니다.
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
