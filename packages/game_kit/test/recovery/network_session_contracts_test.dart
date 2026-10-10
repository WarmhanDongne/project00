import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_kit/recovery/services/durable_room_operation_store.dart';
import 'package:game_kit/core/diagnostics/recovery_metrics.dart';
import 'package:game_kit/recovery/models/game_recovery_context.dart';
import 'package:game_kit/recovery/services/callable_retry_policy.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('callable timeout is classified as a retryable transport failure', () {
    expect(
      CallableRetryPolicy.isRetryable(TimeoutException('timeout')),
      isTrue,
    );
    expect(CallableRetryPolicy.isRetryable(StateError('state')), isFalse);
  });
  test(
    'unknown intent survives restart, elapsed time and another account without changing its payload',
    () async {
      final first = DurableRoomOperationStore();
      final request = await first.begin(
        uid: 'a',
        kind: 'leave',
        scope: 'room/member',
        payload: {'roomInstanceId': 'room', 'membershipId': 'member'},
      );
      await first.mark(request, 'awaitingResult');
      final restarted = DurableRoomOperationStore();
      await restarted.load();
      expect(restarted.pendingFor('b'), isEmpty);
      final retry = await restarted.begin(
        uid: 'a',
        kind: 'leave',
        scope: 'room/member',
        payload: {'membershipId': 'new-member'},
      );
      expect(retry['payload'], request['payload']);
      expect(retry['state'], 'awaitingResult');
      await restarted.mark(retry, 'confirmed');
      expect(restarted.pendingFor('a'), isEmpty);
      expect(restarted.recordsFor('a').single['payload'], request['payload']);
    },
  );
  test(
    'old acknowledgment cannot confirm a new operation in the same logical slot',
    () async {
      final store = DurableRoomOperationStore();
      final old = await store.begin(
        uid: 'a',
        kind: 'create',
        scope: 'active',
        payload: {},
      );
      await store.mark(old, 'confirmed');
      final next = await store.begin(
        uid: 'a',
        kind: 'create',
        scope: 'active',
        payload: {},
      );
      await store.mark(old, 'confirmed');
      expect(store.pendingFor('a').single['payload'], next['payload']);
    },
  );
  test(
    'metrics preserve a monotonic episode across manual batches and bounded independent summaries',
    () {
      var now = Duration.zero;
      final metrics = RecoveryMetrics(clock: () => now, enabled: true);
      metrics.begin();
      now = const Duration(milliseconds: 100);
      metrics.mark(RecoveryStage.connection);
      metrics.finish(success: false);
      now = const Duration(seconds: 3);
      metrics.begin(newEpisode: false);
      now = const Duration(seconds: 4);
      metrics.mark(RecoveryStage.input);
      metrics.notApplicable(RecoveryStage.privateData);
      metrics.finish(success: true);
      final summary = metrics.summaries.last;
      expect(summary.episode, 1);
      expect(summary.batch, 2);
      expect(summary.elapsed, now);
      expect(
        summary.stages[RecoveryStage.connection],
        const Duration(milliseconds: 100),
      );
      expect(summary.stageText(RecoveryStage.privateData), 'N/A');
      expect(summary.stageText(RecoveryStage.assets), '미완료');
      for (var i = 0; i < 60; i++) {
        metrics.begin();
        metrics.finish(success: true);
      }
      expect(metrics.summaries.length, 50);
      final release = RecoveryMetrics(enabled: false);
      release.begin();
      release.mark(RecoveryStage.input);
      release.finish(success: true);
      expect(release.summaries, isEmpty);
    },
  );
  test(
    'private context matches game phase turn data without barrier epoch and leaving blocks commands',
    () {
      const context = GameRecoveryContext(
        gameInstanceId: 'game',
        phaseSeq: 1,
        turnSeq: 2,
        dataSeq: 3,
        resumeEpoch: 4,
      );
      final privateContext = {...context.envelope}..remove('resumeEpoch');
      expect(context.matchesPrivate({'_context': privateContext}), true);
      expect(
        context.matchesPrivate({
          '_context': {...privateContext, 'resumeEpoch': 99},
        }),
        true,
      );
      for (final field in [
        'gameInstanceId',
        'phaseSeq',
        'turnSeq',
        'dataSeq',
      ]) {
        expect(
          context.matchesPrivate({
            '_context': {...context.envelope, field: 'old'},
          }),
          false,
        );
      }
      final session = GameRecoverySession()
        ..context = context
        ..localUsable = true
        ..paused = false;
      expect(session.canSend, false);
      session.serverConfirmed = true;
      expect(session.canSend, true);
      session.controllerAvailable = false;
      expect(session.canSend, false);
      session.controllerAvailable = true;
      expect(session.canSend, true);
      session.leaving = true;
      expect(session.canSend, false);
    },
  );
  test(
    'durable request payload cannot be changed through caller references',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = DurableRoomOperationStore(storageKey: 'immutable-request');
      final request = {
        'cards': <String>['one', 'two'],
      };
      final record = await store.begin(
        uid: 'u',
        kind: 'submit',
        scope: 'game',
        payload: request,
      );
      (request['cards'] as List).clear();
      ((record['payload'] as Map)['cards'] as List).add('other');
      final retained = store.pendingFor('u').single;
      expect((retained['payload'] as Map)['cards'], ['one', 'two']);
      ((retained['payload'] as Map)['cards'] as List).clear();
      expect((store.pendingFor('u').single['payload'] as Map)['cards'], [
        'one',
        'two',
      ]);
    },
  );
  test(
    'failed durable storage blocks transmission and rolls back a failed confirmation',
    () async {
      final prefs = await SharedPreferences.getInstance();
      var fail = false;
      final store = DurableRoomOperationStore(
        storageKey: 'disk-failure',
        persist: (key, value) async =>
            fail ? false : prefs.setString(key, value),
      );
      fail = true;
      var sent = false;
      await expectLater(() async {
        await store.begin(
          uid: 'u',
          kind: 'leave',
          scope: 'member',
          payload: {},
        );
        sent = true;
      }(), throwsStateError);
      expect(sent, false);
      expect(store.pendingFor('u'), isEmpty);
      fail = false;
      final record = await store.begin(
        uid: 'u',
        kind: 'leave',
        scope: 'member',
        payload: {},
      );
      fail = true;
      await expectLater(store.mark(record, 'confirmed'), throwsStateError);
      expect(store.pendingFor('u').single['state'], 'requested');
      final restarted = DurableRoomOperationStore(storageKey: 'disk-failure');
      await restarted.load();
      expect(restarted.pendingFor('u').single['payload'], record['payload']);
    },
  );
}
