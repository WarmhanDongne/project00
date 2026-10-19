import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/core/diagnostics/startup_measurements.dart';
import 'package:game_kit/phone/animations/card_receive_animation.dart';
import 'package:game_kit/tablet/animations/card_deal_animation.dart';
import 'package:cloud_functions/cloud_functions.dart';

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
  test('disabled span preserves Future and does not record', () async {
    final m = StartupMeasurements();
    final future = Future.value(42);
    expect(
      identical(m.measureSpan('close_request', () => future), future),
      isTrue,
    );
    expect(await future, 42);
    expect(m.control(arm()), {'error': 'disabled'});
  });
  test('late span survives action completion but never a new capture', () {
    var now = 0;
    final m = StartupMeasurements(enabled: true, clock: () => now++);
    m.control({...arm(), 'scenario': 'room_reset'});
    m.beginAction('room_reset');
    final root = m.beginSpan('room_reset', room: 'private-room');
    final late = m.beginSpan(
      'disconnect_cancel',
      room: 'private-room',
      subject: 'private-connection',
    );
    root.end(1);
    late.end(3);
    expect(events(m).last['event'], 'disconnect_cancel_end');
    expect(events(m).last['value'], 3);
    expect(jsonEncode(events(m)), isNot(contains('private-')));
    final old = m.beginSpan('disconnect_registration');
    m.control({'op': 'stop'});
    expect(events(m).where((e) => e['event'] == 'span_pending'), hasLength(1));
    m.control(arm(trial: 'two'));
    old.end(1);
    expect(
      events(m).where((e) => e['event'] == 'disconnect_registration_end'),
      isEmpty,
    );
  });
  test(
    'span errors rethrow original object and retain numeric outcome',
    () async {
      final m = StartupMeasurements(enabled: true);
      m.control(arm());
      final error = StateError('private-error');
      await expectLater(
        m.measureSpan<void>('close_request', () => Future.error(error)),
        throwsA(same(error)),
      );
      expect(events(m).last['value'], 3);
      expect(jsonEncode(events(m)), isNot(contains('private-error')));
    },
  );

  testWidgets('two real deck taps are retained for ambiguous-trial rejection', (
    tester,
  ) async {
    final m = StartupMeasurements(enabled: true);
    StartupMeasurements.testInstance = m;
    addTearDown(() => StartupMeasurements.testInstance = null);
    m.control(arm());
    m.bindGame('new-game');
    await tester.pumpWidget(
      MaterialApp(
        home: CardDealAnimation(
          playerCount: 2,
          cardsPerPlayer: 1,
          cardBuilder: (_, _, _) => const ColoredBox(color: Colors.red),
        ),
      ),
    );
    await tester.tap(find.byType(GestureDetector));
    await tester.tap(find.byType(GestureDetector));
    expect(
      events(m).where((e) => e['event'] == 'tablet_deck_tap_accepted'),
      hasLength(2),
    );
    await tester.pumpAndSettle();
    expect(
      events(m).where((e) => e['event'] == 'tablet_deal_started'),
      isNotEmpty,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
  test(
    'actual source and request action survive mismatched label and retry',
    () async {
      final m = StartupMeasurements(enabled: true);
      m.control(arm());
      expect(m.control({'op': 'clock'})['protocol'], 4);
      m.beginAction('result_restart');
      final response = Completer<Map<String, dynamic>>();
      final pending = m.measureCommand(
        'game_liars_poker_start_game',
        warmup: false,
        send: () => response.future,
      );
      m.beginAction('menu_restart');
      response.complete({'success': true});
      await pending;
      final actions = events(
        m,
      ).where((e) => e['event'] == 'action_accepted').toList();
      expect(actions.map((e) => e['action']), [1, 2]);
      expect(actions.map((e) => e['source']), [
        'result_restart',
        'menu_restart',
      ]);
      expect(
        events(m).singleWhere((e) => e['event'] == 'command_end')['action'],
        1,
      );
    },
  );

  test(
    'only allowlisted error codes and composite gate reasons leave recorder',
    () {
      final m = StartupMeasurements(enabled: true)..control(arm());
      m.recordError(
        FirebaseFunctionsException(
          code: 'deadline-exceeded',
          message: 'secret',
          details: {'private': 'secret'},
        ),
        request: 1,
      );
      m.recordError(
        FirebaseFunctionsException(code: 'secret', message: 'secret'),
        request: 2,
      );
      m.sessionState(
        localUsable: false,
        transportConnected: true,
        transportRecovering: false,
        controllerAvailable: true,
        serverConfirmed: true,
        paused: false,
        leaving: false,
      );
      expect(
        events(
          m,
        ).where((e) => e['event'] == 'command_error').map((e) => e['value']),
        [3, 0],
      );
      expect(
        events(m).lastWhere((e) => e['event'] == 'session_blockers')['value'],
        1,
      );
      expect(jsonEncode(events(m)), isNot(contains('secret')));
    },
  );

  for (final earlyTap in [false, true]) {
    testWidgets(
      'tablet deck measures entry, real tap and actual deal (early=$earlyTap)',
      (tester) async {
        final m = StartupMeasurements(enabled: true);
        StartupMeasurements.testInstance = m;
        addTearDown(() => StartupMeasurements.testInstance = null);
        m.control(arm());
        m.bindGame('new-game');
        await tester.pumpWidget(
          MaterialApp(
            home: CardDealAnimation(
              playerCount: 2,
              cardsPerPlayer: 1,
              cardBuilder: (_, _, _) => const ColoredBox(color: Colors.red),
            ),
          ),
        );
        List<String> names() =>
            events(m).map((e) => e['event']! as String).toList();
        expect(names(), contains('tablet_deck_tappable_frame'));
        if (earlyTap) {
          await tester.tap(find.byType(GestureDetector));
          expect(names(), contains('tablet_deck_tap_accepted'));
          expect(names(), isNot(contains('tablet_deal_started')));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 700));
        } else {
          await tester.pumpAndSettle();
          await tester.pump(const Duration(seconds: 5));
          expect(names(), contains('tablet_deck_entry_completed'));
          expect(names(), isNot(contains('tablet_deal_started')));
          await tester.tap(find.byType(GestureDetector));
        }
        await tester.pumpAndSettle();
        expect(
          names().where((n) => n == 'tablet_deck_tap_accepted'),
          hasLength(1),
        );
        expect(names().where((n) => n == 'tablet_deal_started'), hasLength(1));
        expect(
          names().where((n) => n == 'tablet_deal_animation_completed'),
          hasLength(1),
        );
        expect(
          names().indexOf('tablet_deck_entry_completed'),
          lessThan(names().indexOf('tablet_deal_started')),
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
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
        hasLength(2),
      );
      expect(events(a).where((e) => e['event'] == 'action_rejected'), isEmpty);
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
      m.state('session_can_send', 1);
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
      m.state('session_can_send', 1);
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
