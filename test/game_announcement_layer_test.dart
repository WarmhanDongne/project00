import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/games/shared/game_flow/game_announcement.dart';
import 'package:project00/games/shared/widgets/game_announcement_layer.dart';

void main() {
  Widget buildLayer(
    GameAnnouncement? announcement, {
    ValueChanged<GameAnnouncement>? onCompleted,
    VoidCallback? onGameContentPressed,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            TextButton(
              onPressed: onGameContentPressed,
              child: const Text('game-content'),
            ),
            Positioned.fill(
              child: GameAnnouncementLayer(
                announcement: announcement,
                onCompleted: onCompleted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  testWidgets('announcement가 없을 때 게임 콘텐츠만 유지한다', (tester) async {
    await tester.pumpWidget(buildLayer(null));

    expect(find.text('game-content'), findsOneWidget);
    expect(find.byType(GameAnnouncementLayer), findsOneWidget);
    expect(find.text('GAME START'), findsNothing);
  });

  testWidgets('문구 표시 여부와 관계없이 포인터 이벤트를 게임 UI로 통과시킨다', (tester) async {
    var pressCount = 0;

    await tester.pumpWidget(
      buildLayer(null, onGameContentPressed: () => pressCount += 1),
    );
    await tester.tap(find.text('game-content'));
    expect(pressCount, 1);

    await tester.pumpWidget(
      buildLayer(
        GameAnnouncement.persistent(
          id: 'dimmed-message',
          text: '어두운 안내',
          showScrim: true,
        ),
        onGameContentPressed: () => pressCount += 1,
      ),
    );
    await tester.tap(find.text('game-content'));
    expect(pressCount, 2);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is ColoredBox && widget.color == const Color(0x66000000),
      ),
      findsOneWidget,
    );
  });

  testWidgets('GAME START와 ROUND 문구를 같은 고정 레이어에서 표시한다', (tester) async {
    await tester.pumpWidget(buildLayer(const GameAnnouncement.gameStart()));
    expect(find.text('GAME START'), findsOneWidget);

    await tester.pumpWidget(buildLayer(GameAnnouncement.round(3)));
    await tester.pump();
    expect(find.text('ROUND 3'), findsOneWidget);
    expect(find.byType(GameAnnouncementLayer), findsOneWidget);
  });

  testWidgets('tone을 실제 텍스트 색상으로 변환한다', (tester) async {
    await tester.pumpWidget(
      buildLayer(
        GameAnnouncement.persistent(
          id: 'positive',
          text: '간파 성공!',
          tone: GameAnnouncementTone.positive,
        ),
      ),
    );

    final text = tester.widget<Text>(find.text('간파 성공!'));
    expect(text.style?.color, const Color(0xFF34C759));
  });

  testWidgets('일회성 문구는 애니메이션 완료 identity를 돌려준다', (tester) async {
    GameAnnouncement? completed;
    final announcement = GameAnnouncement.transient(
      id: 'event-1',
      text: '이벤트',
      duration: const Duration(milliseconds: 100),
    );

    await tester.pumpWidget(
      buildLayer(announcement, onCompleted: (value) => completed = value),
    );
    await tester.pump(const Duration(milliseconds: 120));

    expect(completed?.id, 'event-1');
  });

  testWidgets('위젯 displayDuration이 모델의 기본 표시 시간을 덮어쓴다', (tester) async {
    GameAnnouncement? completed;
    final announcement = GameAnnouncement.transient(
      id: 'duration-override',
      text: '표시 시간',
      duration: const Duration(seconds: 5),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GameAnnouncementLayer(
            announcement: announcement,
            displayDuration: const Duration(milliseconds: 120),
            onCompleted: (value) => completed = value,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 150));

    expect(completed?.id, 'duration-override');
  });

  testWidgets('애니메이션을 꺼도 유지시간 뒤 완료 콜백을 호출한다', (tester) async {
    GameAnnouncement? completed;
    const announcement = GameAnnouncement(
      id: 'static-round',
      kind: GameAnnouncementKind.round,
      text: 'ROUND 2',
      duration: Duration(milliseconds: 100),
      animate: false,
    );

    await tester.pumpWidget(
      buildLayer(announcement, onCompleted: (value) => completed = value),
    );
    expect(find.text('ROUND 2'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 120));
    expect(completed?.id, 'static-round');
  });
}
