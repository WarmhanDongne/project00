import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/platform/theme/platform_theme.dart';
import 'package:project00/platform/widgets/platform_components.dart';

Widget _wrap(Widget child) {
  return MaterialApp(theme: PlatformTheme.light(), home: child);
}

void main() {
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
