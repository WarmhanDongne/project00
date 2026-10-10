import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/recovery/models/game_recovery_context.dart';
import 'package:game_kit/recovery/widgets/connection_notice_host.dart';
import 'package:game_kit/recovery/widgets/game_connection_led.dart';
import 'package:game_kit/recovery/widgets/game_recovery_layer.dart';

void main() {
  testWidgets('LED 복구 표시는 세션 준비 판정과 실제 재시도 동작을 바꾸지 않는다', (tester) async {
    final connection = StreamController<bool>.broadcast();
    final session = GameRecoverySession();
    addTearDown(connection.close);
    addTearDown(session.dispose);
    var recoveryRetries = 0;
    var commandRetries = 0;
    session.retry = () => recoveryRetries++;

    await tester.pumpWidget(
      MaterialApp(
        home: GameConnectionLedHost(
          connectionChanges: connection.stream,
          child: GameRecoveryLayer(
            session: session,
            request: GameRequestRecovery(
              message: '요청 실패',
              onRetry: () => commandRetries++,
            ),
            child: const Scaffold(body: Text('보존된 게임 화면')),
          ),
        ),
      ),
    );
    connection.add(false);
    await tester.pump(const Duration(milliseconds: 1600));
    connection.add(true);
    await tester.pump();

    expect(find.text('on'), findsOneWidget);
    expect(find.text('보존된 게임 화면'), findsOneWidget);
    expect(session.canSend, isFalse);
    await tester.tap(find.text('재시도'));
    expect(recoveryRetries, 1);
    expect(commandRetries, 0);

    session
      ..localUsable = true
      ..serverConfirmed = true
      ..paused = false;
    session.changed();
    await tester.pump();
    await tester.tap(find.text('재시도'));
    expect(session.canSend, isTrue);
    expect(commandRetries, 1);
    expect(recoveryRetries, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('다시 연결 중 단계는 1·2·4·8초 간격으로 올라 5에서 멈춘다', () {
    int step(int ms) =>
        ConnectionNoticeHost.stepFor(Duration(milliseconds: ms), 5);
    expect(step(0), 1);
    expect(step(1000), 2);
    expect(step(3000), 3);
    expect(step(7000), 4);
    expect(step(15000), 5);
    expect(step(60000), 5);
  });

  testWidgets('게임 LED 띠는 oFF → 2-5 → on 순서로 바뀐다', (tester) async {
    final connection = StreamController<bool>.broadcast();
    addTearDown(connection.close);
    await tester.pumpWidget(
      MaterialApp(
        home: GameConnectionLedHost(
          connectionChanges: connection.stream,
          child: const Scaffold(body: Text('게임')),
        ),
      ),
    );
    connection.add(false);
    await tester.pump(const Duration(milliseconds: 1600));
    expect(find.text('oFF'), findsOneWidget);
    expect(find.text('연결이 끊겼어요'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    expect(find.text('1-5'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1100));
    expect(find.text('2-5'), findsOneWidget);
    expect(find.text('다시 연결하는 중…'), findsOneWidget);

    connection.add(true);
    await tester.pump();
    expect(find.text('on'), findsOneWidget);
    expect(find.text('다시 연결됐어요'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });
}
