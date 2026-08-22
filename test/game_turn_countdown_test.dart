import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/core/time/server_clock.dart';
import 'package:project00/games/shared/widgets/game_turn_countdown.dart';

//=======================남은 시간 세기==============================
// 마피아 토론·투표 타이머가 굳어 있던 원인은, 서버 상태가 바뀌지 않는 동안
// 화면이 다시 그려지지 않았던 것입니다. 이 위젯이 1초마다 다시 그립니다.
//
// ⚠️ 위젯 테스트의 `pump`는 **가짜 시계**만 돌립니다. [ServerClock]은 실제
// 시계를 보므로, 테스트에서는 '값이 줄어드는지'가 아니라 **1초마다 다시
// 그리는지**와 경계 동작(마감 없음·이미 지난 마감)을 확인합니다.
void main() {
  testWidgets('상태가 안 바뀌어도 1초마다 숫자가 줄어든다', (tester) async {
    // 시험용 시계를 주입해 시간이 가는 모습을 그대로 확인합니다.
    var now = 1000000;
    await tester.pumpWidget(
      MaterialApp(
        home: GameTurnCountdown(
          expiresAt: now + 10000,
          nowMillis: () => now,
          builder: (context, remaining) => Text('${remaining?.inSeconds}'),
        ),
      ),
    );
    expect(find.text('10'), findsOneWidget);

    // 서버 상태를 하나도 바꾸지 않고 시간만 흐릅니다.
    now += 1000;
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('9'), findsOneWidget);

    now += 4000;
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('5'), findsOneWidget);
  });

  testWidgets('마감이 없으면 남은 시간도 없다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GameTurnCountdown(
          expiresAt: null,
          builder: (context, remaining) =>
              Text(remaining == null ? '없음' : '${remaining.inSeconds}'),
        ),
      ),
    );

    expect(find.text('없음'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('없음'), findsOneWidget);
  });

  testWidgets('이미 지난 마감은 0으로 보여 준다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GameTurnCountdown(
          expiresAt: 1000,
          nowMillis: () => 6000,
          builder: (context, remaining) => Text('${remaining?.inSeconds}'),
        ),
      ),
    );

    // 음수를 그대로 보여 주면 안 됩니다.
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('마감이 바뀌면 새 시간으로 다시 센다', (tester) async {
    const now = 1000000;
    Widget host(int expiresAt) => MaterialApp(
      home: GameTurnCountdown(
        expiresAt: expiresAt,
        nowMillis: () => now,
        builder: (context, remaining) => Text('${remaining?.inSeconds}'),
      ),
    );

    await tester.pumpWidget(host(now + 5000));
    expect(find.text('5'), findsOneWidget);

    // 다음 단계로 넘어가 마감이 길어진 경우입니다.
    await tester.pumpWidget(host(now + 30000));
    expect(find.text('30'), findsOneWidget);
  });

  testWidgets('지난 마감은 한 번만 알린다', (tester) async {
    var timeouts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: GameTurnCountdown(
          expiresAt: 1000,
          nowMillis: () => 5000,
          onTimeout: () => timeouts += 1,
          builder: (context, remaining) => Text('${remaining?.inSeconds}'),
        ),
      ),
    );

    // 서버 시계 보정 전에는 알리지 않습니다(기기 시계 오차 방지).
    final expected = ServerClock.hasSynced ? 1 : 0;
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(timeouts, expected);

    // 계속 돌려도 두 번 알리지 않습니다.
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(timeouts, expected);
  });
}
