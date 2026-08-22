import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/core/time/server_clock.dart';
import 'package:project00/games/final_call/widgets/phone/turn_timer.dart';

/// 파이널 콜 턴 타이머입니다. 시간을 세는 일은 공용 `GameTurnCountdown`에
/// 맡기고, 이 위젯은 생김새만 담당합니다. 라이어스 포커와 **같은 규칙**을
/// 지켜야 합니다 — 서버 시각 보정 전의 0으로 자동 행동을 확정하지 않고,
/// 보정이 도착하면 한 번만 알립니다.
void main() {
  setUp(() async {
    // 이전 테스트가 남긴 보정 상태를 초기화해 '보정 전' 상황에서 시작합니다.
    await ServerClock.stop();
  });
  tearDown(() async {
    await ServerClock.stop();
  });

  Widget buildTimer({required int deadline, VoidCallback? onTimeout}) {
    return MaterialApp(
      home: Scaffold(
        body: FinalCallTimer(deadline: deadline, onTimeout: onTimeout),
      ),
    );
  }

  testWidgets('보정 전에는 만료를 확정하지 않고, 보정 후 한 번만 알린다', (tester) async {
    var timeouts = 0;
    final expired = DateTime.now().millisecondsSinceEpoch - 5000;

    await tester.pumpWidget(
      buildTimer(deadline: expired, onTimeout: () => timeouts += 1),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(timeouts, 0, reason: '기기 시계 오차로 턴을 잘라먹으면 안 됩니다');
    expect(find.text('00:00'), findsOneWidget);

    // 보정이 도착하면 다음 tick에서 확정합니다.
    ServerClock.debugSetOffset(0);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(timeouts, 1);

    // 계속 돌려도 두 번 알리지 않습니다.
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(timeouts, 1);
  });

  testWidgets('남은 시간을 30초까지 보여 준다', (tester) async {
    ServerClock.debugSetOffset(0);
    final deadline =
        DateTime.now().millisecondsSinceEpoch +
        const Duration(seconds: 12).inMilliseconds;

    await tester.pumpWidget(buildTimer(deadline: deadline));
    expect(find.text('00:12'), findsOneWidget);

    // 턴 제한시간(30초)보다 큰 값이 와도 표시는 30을 넘지 않습니다.
    final farAway =
        DateTime.now().millisecondsSinceEpoch +
        const Duration(minutes: 5).inMilliseconds;
    await tester.pumpWidget(buildTimer(deadline: farAway));
    expect(find.text('00:30'), findsOneWidget);
  });

  testWidgets('새 마감이 오면 다시 무장한다', (tester) async {
    ServerClock.debugSetOffset(0);
    var timeouts = 0;
    final expired = DateTime.now().millisecondsSinceEpoch - 1000;

    await tester.pumpWidget(
      buildTimer(deadline: expired, onTimeout: () => timeouts += 1),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(timeouts, 1);

    // 다음 사람 차례가 시작된 경우입니다.
    final next =
        DateTime.now().millisecondsSinceEpoch +
        const Duration(seconds: 20).inMilliseconds;
    await tester.pumpWidget(
      buildTimer(deadline: next, onTimeout: () => timeouts += 1),
    );
    await tester.pump();
    expect(timeouts, 1);
    expect(find.text('00:00'), findsNothing);
  });
}
