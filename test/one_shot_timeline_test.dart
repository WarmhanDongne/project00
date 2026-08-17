import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/games/shared/animations/one_shot_timeline.dart';

void main() {
  testWidgets('0에서 1까지 한 번 재생하고 완료 콜백을 호출한다', (tester) async {
    var completedCount = 0;
    var latestProgress = -1.0;

    await tester.pumpWidget(
      MaterialApp(
        home: OneShotTimeline(
          duration: const Duration(milliseconds: 100),
          onCompleted: () => completedCount += 1,
          builder: (context, progress) {
            latestProgress = progress;
            return Text(progress.toStringAsFixed(2));
          },
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(latestProgress, closeTo(0.5, 0.05));

    await tester.pump(const Duration(milliseconds: 60));
    expect(latestProgress, 1);
    expect(completedCount, 1);

    await tester.pump(const Duration(milliseconds: 100));
    expect(completedCount, 1);
  });
}
