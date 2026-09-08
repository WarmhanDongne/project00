import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/platform/home/howtoplay/models/how_to_play_step.dart';
import 'package:project00/platform/home/howtoplay/screens/how_to_play_screen.dart';
import 'package:project00/platform/home/howtoplay/widgets/how_to_play_button.dart';
import 'package:project00/platform/theme/platform_theme.dart';

//=======================플레이 방식 안내 연출==============================
// 안내는 휴대폰 세로와 태블릿 가로 모두에서 열립니다. 반복 애니메이션이므로
// pumpAndSettle 대신 프레임을 직접 넘기면서 넘침·예외가 없는지 확인합니다.
void main() {
  Future<void> pumpGuide(
    WidgetTester tester, {
    required Size size,
    ThemeData? theme,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? PlatformTheme.light(),
        home: const HowToPlayScreen(),
      ),
    );
  }

  /// 한 장면의 반복 주기를 프레임 단위로 훑습니다.
  Future<void> playScene(WidgetTester tester) async {
    for (var frame = 0; frame < 14; frame++) {
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
    }
  }

  /// 무한 반복 애니메이션과 자동 넘김 타이머를 정리합니다.
  Future<void> disposeGuide(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
  }

  testWidgets('휴대폰 세로에서 네 단계 연출이 예외 없이 재생된다', (tester) async {
    await pumpGuide(tester, size: const Size(390, 844));

    for (var step = 0; step < howToPlaySteps.length; step++) {
      expect(find.text(howToPlaySteps[step].title), findsOneWidget);
      await playScene(tester);
      if (step < howToPlaySteps.length - 1) {
        await tester.tap(find.text('다음'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      }
    }

    expect(find.text('알겠어요'), findsOneWidget);
    await disposeGuide(tester);
  });

  testWidgets('태블릿 가로에서도 같은 단계가 그려진다', (tester) async {
    await pumpGuide(tester, size: const Size(1180, 820));

    for (var step = 0; step < howToPlaySteps.length; step++) {
      expect(find.text(howToPlaySteps[step].title), findsOneWidget);
      await playScene(tester);
      if (step < howToPlaySteps.length - 1) {
        await tester.tap(find.text('다음'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      }
    }

    await disposeGuide(tester);
  });

  testWidgets('어두운 테마에서도 연출이 그려진다', (tester) async {
    await pumpGuide(
      tester,
      size: const Size(390, 844),
      theme: PlatformTheme.dark(),
    );
    await playScene(tester);
    await disposeGuide(tester);
  });

  testWidgets('7.2초가 지나면 다음 단계로 자동으로 넘어간다', (tester) async {
    await pumpGuide(tester, size: const Size(390, 844));

    expect(find.text(howToPlaySteps[0].title), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 7300));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(howToPlaySteps[1].title), findsOneWidget);

    await disposeGuide(tester);
  });

  testWidgets('직접 넘긴 뒤에는 자동 넘김이 멈춘다', (tester) async {
    await pumpGuide(tester, size: const Size(390, 844));

    await tester.tap(find.text('다음'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(howToPlaySteps[1].title), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 9000));
    expect(find.text(howToPlaySteps[1].title), findsOneWidget);

    await disposeGuide(tester);
  });

  testWidgets('홈의 안내 아이콘을 누르면 전체 화면 안내가 열린다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: PlatformTheme.light(),
        home: const Scaffold(
          body: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: HowToPlayButton(),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(HowToPlayButton));
    // 원형으로 펼쳐지는 전환이 끝날 때까지 프레임을 넘깁니다.
    for (var frame = 0; frame < 8; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text(howToPlaySteps.first.title), findsOneWidget);
    expect(tester.takeException(), isNull);

    await disposeGuide(tester);
  });
}
