import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/games/shared/game_flow/game_flow_copy.dart';
import 'package:project00/games/shared/widgets/game_connecting_overlay.dart';

void main() {
  Widget buildOverlay({
    required bool isWaiting,
    VoidCallback? onExit,
    Duration indicatorDelay = const Duration(seconds: 6),
    Duration exitDelay = const Duration(seconds: 20),
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            const Text('game'),
            GameConnectingOverlay(
              isWaiting: isWaiting,
              onExit: onExit,
              indicatorDelay: indicatorDelay,
              exitDelay: exitDelay,
            ),
          ],
        ),
      ),
    );
  }

  testWidgets('대기 초반에는 아무것도 표시하지 않는다', (tester) async {
    await tester.pumpWidget(buildOverlay(isWaiting: true));
    await tester.pump(const Duration(seconds: 3));

    final opacity = tester.widget<AnimatedOpacity>(
      find.byType(AnimatedOpacity),
    );
    expect(opacity.opacity, 0);
  });

  testWidgets('대기가 길어지면 안내를, 더 길어지면 나가기 버튼을 표시한다', (tester) async {
    var exited = false;
    await tester.pumpWidget(
      buildOverlay(isWaiting: true, onExit: () => exited = true),
    );

    await tester.pump(const Duration(seconds: 7));
    expect(find.text(GameFlowCopy.waitingForGameData), findsOneWidget);
    expect(find.text(GameFlowCopy.leaveGame), findsNothing);

    await tester.pump(const Duration(seconds: 14));
    expect(find.text(GameFlowCopy.leaveGame), findsOneWidget);

    await tester.tap(find.text(GameFlowCopy.leaveGame));
    expect(exited, isTrue);
  });

  testWidgets('대기가 끝나면 즉시 사라지고 다시 나타나지 않는다', (tester) async {
    Widget build(bool isWaiting) => buildOverlay(isWaiting: isWaiting);

    await tester.pumpWidget(build(true));
    await tester.pump(const Duration(seconds: 7));

    await tester.pumpWidget(build(false));
    await tester.pump(const Duration(seconds: 30));

    final opacity = tester.widget<AnimatedOpacity>(
      find.byType(AnimatedOpacity),
    );
    expect(opacity.opacity, 0);
  });

  testWidgets('빈 상태에서도 Positioned를 반환해 느슨한 Stack을 깨지 않는다', (tester) async {
    await tester.pumpWidget(buildOverlay(isWaiting: false));

    expect(
      find.descendant(
        of: find.byType(Stack).first,
        matching: find.byType(Positioned),
      ),
      findsWidgets,
    );
    expect(find.text('game'), findsOneWidget);
  });
}
