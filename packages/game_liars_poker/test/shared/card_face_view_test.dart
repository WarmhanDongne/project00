import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_liars_poker/shared/widgets/card_face_view.dart';

import '../support/overflow_sweep.dart';

/// 카드 안쪽(모서리 글자 제외)에서 글자가 칠해진 위아래·좌우 끝을 잽니다.
Future<({int top, int bottom, int left, int right})> _inkBounds(
  WidgetTester tester,
  GlobalKey key,
) async {
  late ({int top, int bottom, int left, int right}) bounds;
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final width = image.width;
    final height = image.height;
    var top = height, bottom = -1, left = width, right = -1;
    for (var y = 6; y < height - 6; y++) {
      for (var x = 6; x < width - 6; x++) {
        if (x < width * .24 && y < height * .22) continue;
        if (x > width * .76 && y > height * .78) continue;
        final offset = (y * width + x) * 4;
        final luminance =
            data.getUint8(offset) +
            data.getUint8(offset + 1) +
            data.getUint8(offset + 2);
        if (luminance < 600) {
          top = math.min(top, y);
          bottom = math.max(bottom, y);
          left = math.min(left, x);
          right = math.max(right, x);
        }
      }
    }
    bounds = (top: top, bottom: bottom, left: left, right: right);
  });
  return bounds;
}

void main() {
  testWidgets('A·K·Q·조커는 가운데 요소의 높이가 같고 정중앙에 놓인다', (tester) async {
    await loadSweepFonts(tester);
    tester.view.physicalSize = const Size(1000, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final faces = [
      LiarsCardFace.ace,
      LiarsCardFace.king,
      LiarsCardFace.queen,
      LiarsCardFace.joker,
    ];
    final keys = {for (final face in faces) face: GlobalKey()};
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final face in faces)
                RepaintBoundary(
                  key: keys[face],
                  child: LiarsPokerCardView(
                    face: face,
                    rounded: true,
                    width: 200,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    final results = {
      for (final face in faces) face: await _inkBounds(tester, keys[face]!),
    };
    for (final face in faces) {
      final bounds = results[face]!;
      final centerY = (bounds.top + bounds.bottom) / 2;
      final centerX = (bounds.left + bounds.right) / 2;
      expect(centerY, closeTo(140, 3), reason: '$face 세로 중앙');
      expect(centerX, closeTo(100, 3), reason: '$face 가로 중앙');
    }
    // 네 카드의 가운데 요소 높이가 서로 거의 같습니다.
    final heights = [for (final r in results.values) r.bottom - r.top + 1];
    expect(
      heights.reduce(math.max) - heights.reduce(math.min),
      lessThanOrEqualTo(4),
      reason: '높이 $heights',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('카드는 크기를 바꿔도 같은 모양으로 그려지고 뒷면은 이미지를 쓴다', (tester) async {
    await loadSweepFonts(tester);
    await tester.pumpWidget(
      const MaterialApp(
        home: Material(
          child: Row(
            children: [
              LiarsPokerCardView(face: LiarsCardFace.queen, width: 60),
              LiarsPokerCardView(face: LiarsCardFace.queen, width: 240),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    final small = tester.getSize(find.byType(LiarsPokerCardView).first);
    final large = tester.getSize(find.byType(LiarsPokerCardView).last);
    expect(small.height / small.width, closeTo(1.4, .001));
    expect(large.height / large.width, closeTo(1.4, .001));
    expect(find.bySemanticsLabel('퀸 카드'), findsNWidgets(2));
    expect(LiarsCardFace.fromValue('joker'), LiarsCardFace.joker);
    expect(LiarsCardFace.fromValue('?'), LiarsCardFace.back);
    expect(find.bySemanticsLabel('카드 뒷면'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
