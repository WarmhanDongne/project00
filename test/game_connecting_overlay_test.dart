import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/games/shared/game_flow/game_flow_copy.dart';
import 'package:project00/games/shared/widgets/game_connecting_overlay.dart';

void main() {
  Widget buildOverlay({
    required bool isWaiting,
    VoidCallback? onExit,
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

  testWidgets('로딩 문구·스피너는 어떤 시점에도 보이지 않는다', (tester) async {
    // 사용자 요청으로 대기 안내(문구 + 스피너)를 없앴습니다. 정상 진입에서도
    // 잠깐 비치며 연출을 해쳤기 때문입니다.
    await tester.pumpWidget(buildOverlay(isWaiting: true, onExit: () {}));

    await tester.pump(const Duration(seconds: 7));
    expect(find.text(GameFlowCopy.waitingForGameData), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.pump(const Duration(seconds: 30));
    expect(find.text(GameFlowCopy.waitingForGameData), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('병적으로 오래 멈춘 경우에만 나가기 버튼이 나타난다', (tester) async {
    var exited = false;
    await tester.pumpWidget(
      buildOverlay(isWaiting: true, onExit: () => exited = true),
    );

    // 20초 전에는 아무것도 없습니다.
    await tester.pump(const Duration(seconds: 19));
    expect(find.text(GameFlowCopy.leaveGame), findsNothing);

    await tester.pump(const Duration(seconds: 2));
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
