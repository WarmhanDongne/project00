import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/core/diagnostics/startup_measurements.dart';
import 'package:game_kit/phone/animations/card_receive_animation.dart';

Map<String, String> arm({String trial = 'one', String role = 'tablet'}) => {
  'op': 'arm',
  'capture': 'test',
  'trial': trial,
  'scenario': 'initial_start',
  'role': role,
  'key': List.filled(64, 'a').join(),
};
List<Map<String, Object?>> events(StartupMeasurements m) =>
    (m.control({'op': 'drain'})['events']! as List)
        .cast<Map<String, Object?>>();

void main() {
  test(
    'disabled recorder does not collect, alter results, or swallow errors',
    () async {
      final m = StartupMeasurements();
      expect(m.control(arm())['error'], 'disabled');
      final result = {'success': true};
      expect(
        await m.measureCommand(
          'game_liars_poker_start_game',
          warmup: false,
          send: () async => result,
        ),
        same(result),
      );
      final error = StateError('private message');
      await expectLater(
        m.measureCommand(
          'game_liars_poker_start_game',
          warmup: false,
          send: () async => throw error,
        ),
        throwsA(same(error)),
      );
    },
  );

  test(
    'old games are not new trials; aliases join devices without exposing IDs',
    () {
      final a = StartupMeasurements(enabled: true);
      final b = StartupMeasurements(enabled: true);
      for (final m in [a, b]) {
        m.bindGame('old-private-identity');
        m.control(arm());
        m.bindGame('old-private-identity');
        expect(m.game, isNull);
        m.bindGame('new-private-identity');
      }
      expect(a.game, b.game);
      expect(jsonEncode(events(a)), isNot(contains('private-identity')));
      expect(events(a).where((e) => e['event'] == 'game_bound'), hasLength(1));
      a.beginAction('initial_start');
      a.beginAction('initial_start');
      expect(
        events(a).where((e) => e['event'] == 'action_accepted'),
        hasLength(1),
      );
      expect(
        events(a).where((e) => e['event'] == 'action_rejected'),
        hasLength(1),
      );
    },
  );

  test(
    'clock deltas are monotonic; errors complete requests; warmups excluded',
    () async {
      var now = 100;
      final m = StartupMeasurements(enabled: true, clock: () => now);
      m.control(arm());
      await m.measureCommand(
        'game_liars_poker_start_game',
        warmup: false,
        send: () async {
          m.linkRequest('private-command-id');
          now += 2300;
          return {'success': true};
        },
      );
      final rows = events(m);
      final start = rows.singleWhere((e) => e['event'] == 'command_start');
      final end = rows.singleWhere((e) => e['event'] == 'command_end');
      expect((end['mono_us']! as int) - (start['mono_us']! as int), 2300);
      await m.measureCommand(
        'game_liars_poker_submit_cards',
        warmup: true,
        send: () async => {},
      );
      expect(
        events(m).where((e) => e['event'] == 'command_start'),
        hasLength(1),
      );
      await expectLater(
        m.measureCommand(
          'game_liars_poker_start_game',
          warmup: false,
          send: () async => throw StateError('secret'),
        ),
        throwsStateError,
      );
      expect(
        events(m).lastWhere((e) => e['event'] == 'command_end')['value'],
        3,
      );
      expect(jsonEncode(events(m)), isNot(contains('private-command-id')));
      expect(jsonEncode(events(m)), isNot(contains('secret')));
    },
  );

  test(
    'late response from stopped trial cannot contaminate a newly armed trial',
    () async {
      final m = StartupMeasurements(enabled: true);
      m.control(arm());
      final response = Completer<Map<String, dynamic>>();
      final pending = m.measureCommand(
        'game_liars_poker_start_game',
        warmup: false,
        send: () => response.future,
      );
      m.control({'op': 'stop'});
      m.control(arm(trial: 'two'));
      response.complete({'success': true});
      await pending;
      expect(events(m).where((e) => e['event'] == 'command_end'), isEmpty);
    },
  );

  test(
    'missing gates, another player turn, background and old game cannot finish',
    () {
      final m = StartupMeasurements(enabled: true);
      m.control(arm(role: 'phone_A'));
      m.bindGame('game-one');
      final old = m.game!;
      m.phoneGate(
        game: old,
        selectable: true,
        submittable: false,
        firstTurn: false,
        uncovered: true,
      );
      m.handGate(old, selectable: true, submittable: true);
      expect(
        events(m).where((e) => e['event'] == 'phone_first_turn_playable_frame'),
        isEmpty,
      );
      m.didChangeAppLifecycleState(AppLifecycleState.paused);
      m.phoneGate(
        game: old,
        selectable: true,
        submittable: true,
        firstTurn: true,
        uncovered: true,
      );
      expect(
        events(m).where((e) => e['event'] == 'phone_first_turn_playable_frame'),
        isEmpty,
      );
      m.bindGame('game-two');
      m.handGate(old, selectable: true, submittable: true);
      m.didChangeAppLifecycleState(AppLifecycleState.resumed);
      m.phoneGate(
        game: m.game,
        selectable: true,
        submittable: true,
        firstTurn: true,
        uncovered: true,
      );
      expect(
        events(m).where((e) => e['event'] == 'phone_first_turn_playable_frame'),
        isEmpty,
      );
      m.handGate(m.game, selectable: true, submittable: true);
      m.handGate(m.game, selectable: true, submittable: true);
      expect(
        events(m).where((e) => e['event'] == 'phone_first_turn_playable_frame'),
        hasLength(1),
      );
    },
  );

  test('journal overflow is explicit instead of silent success', () {
    final m = StartupMeasurements(enabled: true, capacity: 3);
    m.control(arm());
    for (var i = 0; i < 10; i++) {
      m.record('public_received');
    }
    final drained = m.control({'op': 'drain'});
    expect(drained['dropped'], greaterThan(0));
    expect(drained['events']! as List, hasLength(3));
  });

  test(
    'acknowledged journal events do not create false overflow in a long capture',
    () {
      final m = StartupMeasurements(enabled: true, capacity: 3);
      m.control(arm());
      var after = 0;
      for (var i = 0; i < 20; i++) {
        final reply = m.control({'op': 'drain', 'after': '$after'});
        expect(reply['dropped'], 0);
        after = reply['last_seq']! as int;
        m.control({'op': 'drain', 'after': '$after'});
        m.record('public_received');
      }
    },
  );

  testWidgets(
    'card pack measures actual entry, user tap, and reveal completion',
    (tester) async {
      final m = StartupMeasurements(enabled: true);
      StartupMeasurements.testInstance = m;
      addTearDown(() => StartupMeasurements.testInstance = null);
      m.control(arm(role: 'phone_A'));
      m.bindGame('test-game');
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 350,
              height: 500,
              child: CardReceiveAnimation(
                cardCount: 1,
                cardBuilder: (_, _, _) => const ColoredBox(color: Colors.red),
              ),
            ),
          ),
        ),
      );
      await tester.tapAt(tester.getCenter(find.byType(CardReceiveAnimation)));
      expect(
        events(m).where((e) => e['event'] == 'pack_tap_accepted'),
        isEmpty,
      );
      await tester.pump(const Duration(milliseconds: 800));
      expect(
        events(m).where((e) => e['event'] == 'pack_tappable_frame'),
        hasLength(1),
      );
      await tester.pump(const Duration(seconds: 5));
      expect(events(m).where((e) => e['event'] == 'reveal_completed'), isEmpty);
      await tester.tap(find.byType(GestureDetector).first);
      expect(
        events(m).where((e) => e['event'] == 'pack_tap_accepted'),
        hasLength(1),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1500));
      expect(
        events(m).where((e) => e['event'] == 'reveal_completed'),
        hasLength(1),
      );
    },
  );
}
