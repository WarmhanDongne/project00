import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/core/diagnostics/startup_measurements.dart';
import 'package:game_liars_poker/phone/phone_board.dart';
import 'package:game_liars_poker/phone/widgets/hand_card_stack.dart';

void main() {
  for (final landscape in [false, true]) {
    for (final dragOnly in [false, true]) {
      testWidgets(
        'linked actual input landscape=$landscape dragOnly=$dragOnly',
        (tester) async {
          final metrics = StartupMeasurements(enabled: true);
          StartupMeasurements.testInstance = metrics;
          addTearDown(() => StartupMeasurements.testInstance = null);
          metrics.control({
            'op': 'arm',
            'capture': 'test',
            'trial': 'one',
            'scenario': 'initial_start',
            'role': 'phone_A',
            'key': List.filled(64, 'a').join(),
          });
          metrics.bindGame('new-game');
          metrics.state('session_can_send', 1);
          metrics.phoneGate(
            game: metrics.game,
            selectable: true,
            submittable: true,
            firstTurn: true,
            uncovered: true,
          );
          final controller = PhoneHandCardStackController();
          addTearDown(controller.dispose);
          var enabled = false;
          List<int>? submitted;
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
                        isLandscape: landscape,
                        enabled: enabled,
                        submissionEnabled: enabled,
                        initiallyRevealed: true,
                        flowConfig: buildLiarsPokerPhoneFlowConfig(
                          roundNumber: 1,
                          tableCardValue: 'K',
                        ),
                        onCardsSubmitRequested: (indexes) async {
                          submitted = indexes;
                          return true;
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
          );
          List<Map<String, Object?>> rows() =>
              (metrics.control({'op': 'drain'})['events']! as List).cast();
          expect(
            rows().where(
              (e) => e['event'] == 'phone_first_turn_playable_frame',
            ),
            isEmpty,
          );
          final card = find.byType(GestureDetector).last;
          await tester.tap(card);
          expect(controller.hasSelection, isFalse);
          update(() => enabled = true);
          await tester.pump();
          expect(
            rows().where(
              (e) => e['event'] == 'phone_first_turn_playable_frame',
            ),
            hasLength(1),
          );
          if (!dragOnly) {
            await tester.tap(card);
            await tester.pump();
            expect(controller.hasSelection, isTrue);
            await tester.pump(const Duration(milliseconds: 350));
          }
          await tester.drag(card, const Offset(0, -140));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          expect(submitted, hasLength(1));
          expect(
            rows().where(
              (e) => e['event'] == 'card_selection_changed' && e['value'] == 1,
            ),
            isNotEmpty,
          );
          expect(
            rows().where((e) => e['event'] == 'submit_handler'),
            hasLength(1),
          );
          expect(
            rows().where(
              (e) => e['event'] == 'submit_result' && e['value'] == 1,
            ),
            hasLength(1),
          );
          final selected = rows().firstWhere(
            (e) => e['event'] == 'card_selection_changed' && e['value'] == 1,
          );
          final started = rows().singleWhere(
            (e) => e['event'] == 'submit_handler',
          );
          final result = rows().singleWhere(
            (e) => e['event'] == 'submit_result',
          );
          expect(selected['input'], dragOnly ? 'drag' : 'tap');
          expect(started['selection'], selected['selection']);
          expect(result['selection'], selected['selection']);
          expect(result['submission'], started['submission']);
          expect(started['seq'] as int, greaterThan(selected['seq'] as int));
          expect(result['seq'] as int, greaterThan(started['seq'] as int));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
