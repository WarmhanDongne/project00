import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/games/liars_poker/screens/phone/phone_game_screen.dart';
import 'package:project00/games/liars_poker/widgets/phone/spectator.dart';
import 'package:project00/games/liars_poker/widgets/phone/top_bar.dart';
import 'package:project00/gen/assets.gen.dart';

void main() {
  testWidgets('관전자가 판정·벌칙 화면을 볼 때도 상단바를 유지한다', (tester) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, _) => const MaterialApp(
          home: LiarsPokerPhoneGameScreen(showSpectatorTopBar: true),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(PhoneGameTopBar), findsOneWidget);
  });

  testWidgets('세로 관전 화면은 진행 화면과 같은 세로 배경을 유지한다', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, _) => MaterialApp(
          home: PhoneSpectator(
            players: const [],
            table: 'K',
            onExitRoom: () async => true,
          ),
        ),
      ),
    );

    expect(
      find.image(
        AssetImage(
          Assets.games.liarsPoker.images.background.backgroundPhone.path,
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.image(
        AssetImage(Assets.games.liarsPoker.images.background.background.path),
      ),
      findsNothing,
    );
  });
}
