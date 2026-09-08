import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/platform/home/phone/widgets/phone_owned_games_header.dart';
import 'package:project00/platform/theme/platform_theme.dart';

void main() {
  testWidgets('Galaxy S20+ 폭에서 보유 게임 제목이 넘치지 않는다', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: PlatformTheme.light(),
        home: const Scaffold(
          body: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: PhoneOwnedGamesHeader(),
          ),
        ),
      ),
    );

    expect(find.text('보유 중인 게임'), findsOneWidget);
    expect(find.text('모바일에서는 방에 참여해 플레이합니다.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
