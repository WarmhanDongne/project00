import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/games/shared/widgets/tablet_game_modal_frame.dart';

void main() {
  testWidgets('작은 태블릿에서도 기준 비율을 유지하며 화면 안에 들어온다', (tester) async {
    tester.view.physicalSize = const Size(1024, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: TabletGameModalFrame(child: ColoredBox(color: Colors.white)),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final size = tester.getSize(find.byType(TabletGameModalFrame));
    expect(size.width, lessThanOrEqualTo(1024 * 0.9 + 0.1));
    expect(size.height, lessThanOrEqualTo(600 * 0.88 + 0.1));
    expect(size.width / size.height, closeTo(1300 / 900, 0.01));
  });
}
