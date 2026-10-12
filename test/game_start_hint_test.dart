import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/platform/home/tablet/widgets/tablet_game_shelf.dart';

Widget _host(String? message) => MaterialApp(
  home: Scaffold(
    body: Column(
      children: [
        GameStartHint(message: message),
        const SizedBox(key: Key('below'), height: 40),
      ],
    ),
  ),
);

double _belowTop(WidgetTester tester) =>
    tester.getTopLeft(find.byKey(const Key('below'))).dy;

double _opacity(WidgetTester tester) => tester
    .widget<Opacity>(
      find
          .ancestor(
            of: find.textContaining('시작할 수 있어요'),
            matching: find.byType(Opacity),
          )
          .first,
    )
    .opacity;

void main() {
  testWidgets('시작 안내는 아래 요소를 부드럽게 밀어내고 알약은 늦게 나타난다', (tester) async {
    await tester.pumpWidget(_host(null));
    final start = _belowTop(tester);
    expect(find.textContaining('시작할 수 있어요'), findsNothing);

    await tester.pumpWidget(_host('2명부터 시작할 수 있어요 · 지금 1명'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    final early = _belowTop(tester);
    // 자리가 열리기 시작해 아래 요소가 조금 밀렸지만, 알약은 아직 보이지 않습니다.
    expect(early, greaterThan(start));
    expect(_opacity(tester), lessThan(.2));

    await tester.pump(const Duration(milliseconds: 120));
    final mid = _belowTop(tester);
    expect(mid, greaterThan(early));

    await tester.pumpAndSettle();
    final end = _belowTop(tester);
    expect(end, greaterThan(mid));
    expect(find.textContaining('시작할 수 있어요'), findsOneWidget);

    // 사라질 때도 한 번에 끊기지 않고 천천히 올라옵니다.
    await tester.pumpWidget(_host(null));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 260));
    expect(_belowTop(tester), lessThan(end));
    expect(_belowTop(tester), greaterThan(start));
    await tester.pumpAndSettle();
    expect(_belowTop(tester), start);
  });
}
