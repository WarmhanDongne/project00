import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/game_flow/game_progress_command.dart';

void main() {
  testWidgets('실패·명령 잠금은 재시도하고 성공 뒤에는 다시 보내지 않는다', (tester) async {
    final command = GameProgressCommand();
    addTearDown(command.dispose);
    var calls = 0;
    Future<bool> send() async => ++calls >= 3;
    void start() =>
        command.run(key: (100, 1), isCurrent: () => true, send: send);
    start();
    start();
    await tester.pump();
    expect(calls, 1);
    await tester.pump(const Duration(seconds: 3));
    expect(calls, 2);
    await tester.pump(const Duration(seconds: 3));
    expect(calls, 3);
    start();
    await tester.pump(const Duration(seconds: 30));
    expect(calls, 3);
  });

  testWidgets('같은 밤의 다음 세부 단계는 독립된 완료 명령이다', (tester) async {
    final command = GameProgressCommand();
    addTearDown(command.dispose);
    var calls = 0;
    for (final stage in ['priority', 'attack', 'support', 'wrapUp']) {
      command.run(
        key: (100, 1, 'night', stage),
        isCurrent: () => true,
        send: () async {
          calls++;
          return true;
        },
      );
      await tester.pump();
    }
    expect(calls, 4);
  });

  testWidgets('새 게임의 같은 라운드는 이전 성공과 구분한다', (tester) async {
    final command = GameProgressCommand();
    addTearDown(command.dispose);
    var calls = 0;
    for (final startedAt in [100, 200]) {
      command.run(
        key: (startedAt, 1),
        isCurrent: () => true,
        send: () async {
          calls++;
          return true;
        },
      );
      await tester.pump();
    }
    expect(calls, 2);
  });

  testWidgets('단계가 바뀌면 실패한 옛 완료 명령을 재전송하지 않는다', (tester) async {
    final command = GameProgressCommand();
    addTearDown(command.dispose);
    var current = true;
    var calls = 0;
    command.run(
      key: 'dealing',
      isCurrent: () => current,
      send: () async {
        calls++;
        return false;
      },
    );
    await tester.pump();
    current = false;
    await tester.pump(const Duration(seconds: 10));
    expect(calls, 1);
  });

  testWidgets('재시작 전 요청의 늦은 실패는 새 재시도에 영향을 주지 않는다', (tester) async {
    final command = GameProgressCommand();
    addTearDown(command.dispose);
    final oldRequest = Completer<bool>();
    command.run(
      key: 'old',
      isCurrent: () => true,
      send: () => oldRequest.future,
    );
    command.cancel();
    var calls = 0;
    command.run(
      key: 'new',
      isCurrent: () => true,
      send: () async => ++calls >= 2,
    );
    await tester.pump();
    oldRequest.complete(false);
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(calls, 2);
  });

  testWidgets('화면 종료 뒤에는 예외 응답도 재시도하지 않는다', (tester) async {
    final command = GameProgressCommand();
    final response = Completer<bool>();
    var calls = 0;
    command.run(
      key: 1,
      isCurrent: () => true,
      send: () {
        calls++;
        return response.future;
      },
    );
    command.dispose();
    response.completeError(StateError('late failure'));
    await tester.pump(const Duration(seconds: 10));
    expect(calls, 1);
  });
}
