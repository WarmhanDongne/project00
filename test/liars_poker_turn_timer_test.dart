import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/core/time/server_clock.dart';
import 'package:project00/games/liars_poker/widgets/phone/turn_timer.dart';

/// 마운트 시점에 이미 마감이 지난 것으로 계산돼도 타이머가 죽지 않고,
/// 서버 시각 보정 이후 정확히 한 번 타임아웃을 발화해야 합니다.
/// (보정 전 00.00 고착 + onTimeout 미발화 회귀 방지)
void main() {
  setUp(() async {
    // 이전 테스트가 남긴 보정 상태를 초기화해 '보정 전' 상황에서 시작합니다.
    await ServerClock.stop();
  });
  tearDown(() async {
    await ServerClock.stop();
  });

  Widget buildTimer({required int expiresAt, VoidCallback? onTimeout}) {
    return MaterialApp(
      home: Scaffold(
        body: PhoneTimer(expiresAt: expiresAt, onTimeout: onTimeout),
      ),
    );
  }

  testWidgets('보정 전에는 만료를 확정하지 않고, 보정 후 한 번만 발화한다', (tester) async {
    var timeoutCount = 0;
    final expiredAt = DateTime.now().millisecondsSinceEpoch - 5000;

    await tester.pumpWidget(
      buildTimer(expiresAt: expiredAt, onTimeout: () => timeoutCount += 1),
    );

    // 서버 시각 보정 전: 기기 시계 오차일 수 있으므로 발화하지 않습니다.
    await tester.pump(const Duration(seconds: 2));
    expect(timeoutCount, 0);
    expect(find.text('00.00'), findsOneWidget);

    // 보정 도착 후 다음 tick에서 만료를 확정합니다.
    ServerClock.debugSetOffset(0);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(timeoutCount, 1);

    // 같은 마감에 대해 반복 발화하지 않습니다.
    await tester.pump(const Duration(seconds: 3));
    expect(timeoutCount, 1);
  });

  testWidgets('보정으로 남은 시간이 되살아나면 카운트다운을 계속한다', (tester) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    await tester.pumpWidget(buildTimer(expiresAt: now));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('00.00'), findsOneWidget);

    // 서버가 기기보다 40초 느린 것으로 보정되면 실제로는 시간이 남아 있습니다.
    ServerClock.debugSetOffset(-40000);
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('00.00'), findsNothing);
  });

  testWidgets('새 마감이 오면 타이머를 다시 무장한다', (tester) async {
    ServerClock.debugSetOffset(0);
    var timeoutCount = 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    await tester.pumpWidget(
      buildTimer(expiresAt: now - 1000, onTimeout: () => timeoutCount += 1),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(timeoutCount, 1);

    await tester.pumpWidget(
      buildTimer(expiresAt: now + 3600000, onTimeout: () => timeoutCount += 1),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(timeoutCount, 1);
    expect(find.text('00.00'), findsNothing);
  });
}
