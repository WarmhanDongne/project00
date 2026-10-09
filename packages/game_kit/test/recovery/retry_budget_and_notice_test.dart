import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/recovery/services/game_command_batch.dart';
import 'package:game_kit/recovery/services/game_progress_command.dart';
import 'package:game_kit/recovery/services/room_recovery_batch.dart';
import 'package:game_kit/recovery/widgets/game_connecting_overlay.dart';

void main() {
  test(
    'completed room owner is not inherited by long-lived subscriptions and expired requests cannot start',
    () async {
      var elapsed = Duration.zero;
      final owner = RoomRecoveryBatch(elapsed: () => elapsed);
      late Zone subscriptionZone;
      await owner.run(
        () async {
          subscriptionZone = Zone.current;
        },
        isCurrent: () => true,
        retryable: (_) => false,
      );
      expect(subscriptionZone.run(() => RoomRecoveryBatch.current), isNull);
      elapsed = const Duration(seconds: 31);
      var calls = 0;
      await expectLater(
        owner.request(() async {
          calls++;
          return true;
        }),
        throwsA(isA<TimeoutException>()),
      );
      expect(calls, 0);
    },
  );
  testWidgets(
    'manual retry of an obsolete game phase cancels its exhausted state',
    (tester) async {
      var current = true;
      final command = GameProgressCommand();
      addTearDown(command.dispose);
      command.run(
        key: 'obsolete-phase',
        isCurrent: () => current,
        send: () async => false,
      );
      await tester.pump();
      for (final delay in [250, 500, 1000]) {
        await tester.pump(Duration(milliseconds: delay));
      }
      expect(command.needsRetry, true);
      current = false;
      command.retry();
      expect(command.needsRetry, false);
    },
  );
  test(
    'room retry has one owner, six attempts and one thirty-second budget',
    () async {
      var elapsed = Duration.zero;
      final starts = <int>[];
      final batch = RoomRecoveryBatch(
        elapsed: () => elapsed,
        wait: (delay) async {
          elapsed += delay;
        },
      );
      await expectLater(
        batch.run(
          () async {
            expect(RoomRecoveryBatch.current, same(batch));
            starts.add(elapsed.inSeconds);
            throw StateError('transient');
          },
          isCurrent: () => true,
          retryable: (_) => true,
        ),
        throwsStateError,
      );
      expect(starts, [0, 1, 3, 7, 15, 23]);
      expect(batch.remaining, const Duration(seconds: 7));
    },
  );
  test(
    'request processing time consumes the room budget and definitive failures stop immediately',
    () async {
      var elapsed = Duration.zero;
      var calls = 0;
      final batch = RoomRecoveryBatch(
        elapsed: () => elapsed,
        wait: (delay) async {
          elapsed += delay;
        },
      );
      await expectLater(
        batch.run(
          () async {
            calls++;
            elapsed += const Duration(seconds: 8);
            throw StateError('timeout');
          },
          isCurrent: () => true,
          retryable: (_) => true,
        ),
        throwsStateError,
      );
      expect(calls, 3);
      expect(elapsed, const Duration(seconds: 27));
      calls = 0;
      await expectLater(
        RoomRecoveryBatch().run(
          () async {
            calls++;
            throw ArgumentError('permission');
          },
          isCurrent: () => true,
          retryable: (_) => false,
        ),
        throwsArgumentError,
      );
      expect(calls, 1);
    },
  );
  testWidgets(
    'game progress stops at four attempts and manual retry retains the original payload',
    (tester) async {
      var elapsed = Duration.zero;
      var calls = 0;
      final seen = <Map<String, dynamic>>[];
      final command = GameProgressCommand(elapsed: () => elapsed);
      addTearDown(command.dispose);
      command.run(
        key: 'phase-one',
        isCurrent: () => true,
        send: () async {
          calls++;
          final captured = GameCommandBatch.current!.commands.putIfAbsent(
            'submit',
            () => {'commandId': calls, 'phaseSeq': 1},
          );
          seen.add(captured);
          return calls > 4;
        },
      );
      await tester.pump();
      for (final delay in [250, 500, 1000]) {
        elapsed += Duration(milliseconds: delay);
        await tester.pump(Duration(milliseconds: delay));
      }
      expect(calls, 4);
      expect(command.needsRetry, true);
      elapsed += const Duration(seconds: 60);
      await tester.pump(const Duration(seconds: 60));
      expect(calls, 4);
      command.retry();
      await tester.pump();
      expect(calls, 5);
      expect(seen.every((payload) => identical(payload, seen.first)), true);
      expect(seen.last, {'commandId': 1, 'phaseSeq': 1});
    },
  );
  testWidgets(
    'own leave is immediately available and ten-second notice survives retry rebuilds',
    (tester) async {
      var exits = 0, retries = 0;
      Widget screen() => MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              GameConnectingOverlay(
                isWaiting: true,
                onExit: () => exits++,
                onRetry: () => retries++,
              ),
            ],
          ),
        ),
      );
      await tester.pumpWidget(screen());
      expect(find.text('내가 나가기'), findsNothing);
      expect(find.text('게임과 그룹 나가기'), findsOneWidget);
      await tester.tap(find.text('게임과 그룹 나가기'));
      expect(exits, 1);
      expect(find.text('다시 연결하기'), findsNothing);
      await tester.pump(const Duration(seconds: 10));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('다시 연결하기'), findsOneWidget);
      await tester.tap(find.text('다시 연결하기'));
      await tester.pumpWidget(screen());
      expect(retries, 1);
      expect(find.text('다시 연결하기'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
