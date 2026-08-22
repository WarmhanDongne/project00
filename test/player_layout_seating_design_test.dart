import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/games/shared/player_layouts/player_layout_editor.dart';
import 'package:project00/games/shared/player_layouts/player_layout_model.dart';
import 'package:project00/platform/theme/platform_theme.dart';

//=======================자리 배치 화면 디자인==============================
// Figma tablet-screen-8-seating-4 / -6 / -9 / -12 를 구현한 화면입니다.
// 인원이 늘면 카드가 단계적으로 작아지고, 카드는 서로 겹치지 않아야 합니다.
void main() {
  Future<void> pumpEditor(
    WidgetTester tester,
    int playerCount, {
    Size screen = const Size(1280, 800),
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = screen;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: PlatformTheme.light(),
        home: PlayerLayoutEditor(
          initialLayout: _layoutOf(playerCount),
          tableColor: Colors.brown,
          onPrepare: (_) async => true,
          onComplete: (_) {},
          onCancel: () async => true,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  List<Rect> cardRects(WidgetTester tester) {
    return tester
        .widgetList<GestureDetector>(find.byType(GestureDetector))
        .where((detector) => detector.onPanStart != null)
        .map((detector) => tester.getRect(find.byWidget(detector)))
        .toList(growable: false);
  }

  testWidgets('4인·6인은 대형 카드(220x92)를 쓴다', (tester) async {
    for (final count in [4, 6]) {
      await pumpEditor(tester, count);

      final rects = cardRects(tester);
      expect(rects.length, count);
      expect(rects.first.width, moreOrLessEquals(220, epsilon: 0.5));
      expect(rects.first.height, moreOrLessEquals(92, epsilon: 0.5));
    }
  });

  testWidgets('9인은 중형(176x76), 12인은 소형(128x64) 카드를 쓴다', (tester) async {
    await pumpEditor(tester, 9);
    var rects = cardRects(tester);
    expect(rects.length, 9);
    expect(rects.first.width, moreOrLessEquals(176, epsilon: 0.5));
    expect(rects.first.height, moreOrLessEquals(76, epsilon: 0.5));

    await pumpEditor(tester, 12);
    rects = cardRects(tester);
    expect(rects.length, 12);
    expect(rects.first.width, moreOrLessEquals(128, epsilon: 0.5));
    expect(rects.first.height, moreOrLessEquals(64, epsilon: 0.5));
  });

  testWidgets('카드는 화면 안에 있고 서로 겹치지 않는다', (tester) async {
    for (final count in [2, 4, 6, 9, 12]) {
      await pumpEditor(tester, count);

      final rects = cardRects(tester);
      final screen = tester.getRect(find.byType(PlayerLayoutEditor));
      for (final rect in rects) {
        expect(screen.contains(rect.topLeft), isTrue, reason: '$count인');
        expect(screen.contains(rect.bottomRight), isTrue, reason: '$count인');
      }
      for (var i = 0; i < rects.length; i += 1) {
        for (var j = i + 1; j < rects.length; j += 1) {
          expect(
            rects[i].overlaps(rects[j]),
            isFalse,
            reason: '$count인: $i번과 $j번 카드가 겹칩니다.',
          );
        }
      }
    }
  });

  testWidgets('좁은 태블릿에서는 카드가 같은 비율로 줄어든다', (tester) async {
    await pumpEditor(tester, 6, screen: const Size(1024, 768));

    final rects = cardRects(tester);
    // 1024 / 1280 = 0.8배
    expect(rects.first.width, moreOrLessEquals(176, epsilon: 1));
    expect(rects.first.height, moreOrLessEquals(73.6, epsilon: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('안내 문구·설정 완료 버튼·뒤로가기 버튼이 함께 있다', (tester) async {
    await pumpEditor(tester, 6);

    expect(find.text('드래그를 사용하여 플레이어들의 실제 위치와 맞도록 조정해 주세요.'), findsOneWidget);
    expect(find.text('설정 완료'), findsOneWidget);
    // 디자인에는 없지만 유지하기로 한 버튼입니다.
    expect(find.byTooltip('뒤로가기'), findsOneWidget);
    // 태블릿이 놓이는 자리 안내입니다.
    expect(find.text('태블릿'), findsOneWidget);
    expect(find.text('테이블 중앙'), findsOneWidget);

    final button = tester.getRect(
      find.ancestor(
        of: find.text('설정 완료'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(button.width, moreOrLessEquals(208, epsilon: 0.5));
    expect(button.height, moreOrLessEquals(64, epsilon: 0.5));
  });
}

PlayerLayoutModel _layoutOf(int count) => PlayerLayoutModel(
  players: List.generate(
    count,
    (index) => PlayerLayoutPlayer(
      uid: 'player-$index',
      nickname: '플레이어$index',
      characterId: 'frog',
      seatIndex: index,
    ),
  ),
);
