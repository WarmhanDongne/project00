import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/core/diagnostics/startup_measurements.dart';
import 'package:game_liars_poker/phone/phone_board.dart';
import 'package:game_liars_poker/phone/widgets/hand_card_stack.dart';

void main() {
  testWidgets(
    'only actual selection changes count; limit and disabled taps do not',
    (tester) async {
      final m = StartupMeasurements(enabled: true);
      StartupMeasurements.testInstance = m;
      addTearDown(() => StartupMeasurements.testInstance = null);
      m.control({
        'op': 'arm',
        'capture': 'test',
        'trial': 'one',
        'scenario': 'initial_start',
        'role': 'phone_A',
        'key': 'a' * 64,
      });
      m.bindGame('game');
      final controller = PhoneHandCardStackController();
      addTearDown(controller.dispose);
      var enabled = true;
      late StateSetter update;
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, _) => MaterialApp(
            home: StatefulBuilder(
              builder: (_, setState) {
                update = setState;
                return Scaffold(
                  body: PhoneHandCardStack(
                    controller: controller,
                    isLandscape: false,
                    initiallyRevealed: true,
                    enabled: enabled,
                    submissionEnabled: enabled,
                    maxSelection: 1,
                    flowConfig: buildLiarsPokerPhoneFlowConfig(
                      roundNumber: 1,
                      tableCardValue: 'K',
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      List<Map<String, Object?>> changes() =>
          (m.control({'op': 'drain'})['events'] as List)
              .cast<Map<String, Object?>>()
              .where((e) => e['event'] == 'card_selection_changed')
              .toList();
      final cards = find.byType(GestureDetector);
      final last = tester.widget<GestureDetector>(cards.last);
      final other = tester.widget<GestureDetector>(
        cards.at(cards.evaluate().length - 2),
      );
      last.onTap!();
      await tester.pump();
      expect(controller.selectedIndexes, hasLength(1));
      expect(changes().map((e) => e['value']), [1]);
      other.onTap!();
      await tester.pump();
      expect(controller.selectedIndexes, hasLength(1));
      expect(changes(), hasLength(1));
      last.onTap!();
      await tester.pump();
      expect(controller.hasSelection, isFalse);
      expect(changes().map((e) => e['value']), [1, 0]);
      last.onTap!();
      await tester.pump();
      update(() => enabled = false);
      await tester.pump();
      expect(changes().map((e) => e['value']), [1, 0, 1, 0]);
      expect(changes().last['input'], 'state');
      final count = changes().length;
      await tester.tap(cards.last);
      await tester.pump();
      expect(changes(), hasLength(count));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final rearm in [false, true]) {
    testWidgets('submission result keeps own selection; rearm=$rearm', (
      tester,
    ) async {
      final m = StartupMeasurements(enabled: true);
      StartupMeasurements.testInstance = m;
      addTearDown(() => StartupMeasurements.testInstance = null);
      Map<String, String> arm(String trial) => {
        'op': 'arm',
        'capture': 'test',
        'trial': trial,
        'scenario': 'initial_start',
        'role': 'phone_A',
        'key': 'a' * 64,
      };
      m.control(arm('one'));
      m.bindGame('game');
      final pending = Completer<bool>();
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, _) => MaterialApp(
            home: Scaffold(
              body: PhoneHandCardStack(
                isLandscape: false,
                initiallyRevealed: true,
                flowConfig: buildLiarsPokerPhoneFlowConfig(
                  roundNumber: 1,
                  tableCardValue: 'K',
                ),
                onCardsSubmitRequested: (_) => pending.future,
              ),
            ),
          ),
        ),
      );
      final card = find.byType(GestureDetector).last;
      await tester.drag(card, const Offset(0, -140));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      List<Map<String, Object?>> rows() =>
          (m.control({'op': 'drain'})['events'] as List).cast();
      final handler = rows().singleWhere((e) => e['event'] == 'submit_handler');
      final chosen = rows().firstWhere(
        (e) => e['event'] == 'card_selection_changed' && e['value'] == 1,
      );
      expect(handler['selection'], chosen['selection']);
      expect(rows().where((e) => e['event'] == 'submit_result'), isEmpty);
      if (rearm) {
        m.control({'op': 'stop'});
        m.control(arm('two'));
        m.bindGame('different-game');
      }
      pending.complete(false);
      await tester.pump();
      await tester.pumpAndSettle();
      final result = rows().where((e) => e['event'] == 'submit_result');
      if (rearm) {
        expect(result, isEmpty);
      } else {
        expect(result, hasLength(1));
        expect(result.single['submission'], handler['submission']);
        expect(result.single['selection'], chosen['selection']);
        expect(result.single['value'], 0);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
