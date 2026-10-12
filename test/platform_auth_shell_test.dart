import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/platform/theme/platform_theme.dart';
import 'package:project00/platform/widgets/platform_components.dart';

Widget _wrap(Widget child) {
  return MaterialApp(theme: PlatformTheme.light(), home: child);
}

void main() {
  for (final size in [const Size(1194, 834), const Size(834, 1194)]) {
    testWidgets('입력 도구막대가 나타나도 인증 배치가 유지된다 ($size)', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 20);
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 20);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _wrap(
          const PlatformAuthShell(
            child: SizedBox(key: Key('auth-content'), height: 420),
          ),
        ),
      );
      final content = tester.getRect(find.byKey(const Key('auth-content')));
      final hero = find.text('모이면 시작하는 게임');
      final heroRect = hero.evaluate().isEmpty ? null : tester.getRect(hero);

      tester.view.viewInsets = const FakeViewPadding(bottom: 80);
      tester.view.padding = const FakeViewPadding(top: 24);
      await tester.pump();
      expect(tester.getRect(find.byKey(const Key('auth-content'))), content);
      if (heroRect != null) expect(tester.getRect(hero), heroRect);
      expect(tester.takeException(), isNull);

      tester.view.viewInsets = FakeViewPadding.zero;
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 20);
      await tester.pump();
      expect(tester.getRect(find.byKey(const Key('auth-content'))), content);
    });
  }

  testWidgets('큰 키보드가 열리면 입력란과 하단 버튼까지 스크롤할 수 있다', (tester) async {
    tester.view.physicalSize = const Size(1194, 834);
    tester.view.devicePixelRatio = 1;
    tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 20);
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 20);
    addTearDown(tester.view.reset);
    var submitted = false;
    await tester.pumpWidget(
      _wrap(
        PlatformAuthShell(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 350),
              const TextField(key: Key('password'), obscureText: true),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => submitted = true,
                child: const Text('완료'),
              ),
            ],
          ),
        ),
      ),
    );
    final heroRect = tester.getRect(find.text('모이면 시작하는 게임'));
    await tester.tap(find.byKey(const Key('password')));
    await tester.pump();
    tester.view.viewInsets = const FakeViewPadding(bottom: 350);
    tester.view.padding = const FakeViewPadding(top: 24);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.getRect(find.text('모이면 시작하는 게임')), heroRect);
    final viewport = tester.getRect(find.byType(SingleChildScrollView));
    expect(viewport.bottom, lessThanOrEqualTo(834 - 350));
    expect(
      tester.getRect(find.byKey(const Key('password'))).bottom,
      lessThanOrEqualTo(viewport.bottom),
    );
    await tester.enterText(find.byKey(const Key('password')), 'Abcdef1!');
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -400),
    );
    await tester.pump();
    expect(tester.getRect(find.text('완료')).bottom, lessThan(viewport.bottom));
    await tester.tap(find.text('완료'));
    expect(submitted, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('태블릿 인증 카드는 그림자 여백을 포함해 세로 가운데에 놓인다', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _wrap(
        const PlatformAuthShell(
          child: SizedBox(key: Key('auth-content'), height: 200),
        ),
      ),
    );

    final content = tester.getRect(find.byKey(const Key('auth-content')));
    final screen = tester.getRect(find.byType(Scaffold));
    final scrollFrame = tester.getRect(find.byType(SingleChildScrollView));
    expect(
      scrollFrame.center.dy,
      moreOrLessEquals(screen.center.dy, epsilon: 1),
    );
    // The new auth card reserves 12px below it for its shadow.
    expect(
      content.center.dy,
      moreOrLessEquals(scrollFrame.center.dy - 6, epsilon: 1),
    );
  });

  testWidgets('내용이 화면보다 길면 위에서부터 스크롤한다', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _wrap(
        const PlatformAuthShell(
          child: SizedBox(key: Key('auth-content'), height: 1400),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final initialTop = tester
        .getTopLeft(find.byKey(const Key('auth-content')))
        .dy;
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -200),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(
      tester.getTopLeft(find.byKey(const Key('auth-content'))).dy,
      lessThan(initialTop),
    );
  });
}
