import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_kit/session/controller_room_session_store.dart';
import 'package:game_kit/recovery/models/game_interruption.dart';
import 'package:game_kit/recovery/widgets/game_interruption_layer.dart';

GameInterruption pause({bool canContinue = false}) => GameInterruption.fromMap({
  'paused': true,
  'pauseId': 'one-pause',
  'causes': {
    'player:disconnected-user': {
      'incidentId': 'one-incident',
      'deadlineAt': 1,
      'canContinue': canContinue,
      'awaitingDecision': true,
    },
    'controller': {'incidentId': 'controller-incident'},
  },
});
void main() {
  test(
    'late close cannot erase a replacement controller token for the same room code',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = ControllerRoomSessionStore.instance;
      await store.clear();
      await store.save(roomCode: 'ABCDE', sessionId: 'old-token');
      final replacement = store.save(roomCode: 'ABCDE', sessionId: 'new-token');
      final lateClose = store.clear(
        onlyRoomCode: 'ABCDE',
        onlySessionId: 'old-token',
      );
      await Future.wait([replacement, lateClose]);
      expect(store.sessionIdForRoom('ABCDE'), 'new-token');
      await store.clear(onlyRoomCode: 'ABCDE', onlySessionId: 'new-token');
    },
  );
  testWidgets(
    'phone pause reuses the error notice and existing menu without controller decisions or extra exits',
    (tester) async {
      var exits = 0, decisions = 0;
      Future<bool> decide() async {
        decisions++;
        return true;
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: TextButton(
                    onPressed: () => exits++,
                    child: const Text('기존 나가기'),
                  ),
                ),
                GameInterruptionLayer(
                  interruption: pause(canContinue: true),
                  currentUid: 'phone',
                  onExit: () => exits++,
                  onContinue: decide,
                  onFinishNow: decide,
                  onExpired: decide,
                  onWaitMore: decide,
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.text('내가 나가기'), findsNothing);
      expect(find.textContaining('게임을 잠시 멈췄어요'), findsOneWidget);
      expect(find.text('제외하고 계속하기'), findsNothing);
      expect(find.text('게임 종료'), findsNothing);
      expect(find.text('30초 더 기다리기'), findsNothing);
      await tester.pump(const Duration(seconds: 61));
      expect(decisions, 0);
      await tester.tap(find.text('기존 나가기'));
      expect(exits, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'controller expiry marks decision once without automatic exclusion or end and game end requires confirmation',
    (tester) async {
      var expiry = 0, exclusions = 0, ends = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                GameInterruptionLayer(
                  interruption: pause(),
                  currentUid: 'controller',
                  presentation: GameInterruptionPresentation.tabletController,
                  onExpired: () async {
                    expiry++;
                    return true;
                  },
                  onContinue: () async {
                    exclusions++;
                    return true;
                  },
                  onFinishNow: () async {
                    ends++;
                    return true;
                  },
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 61));
      expect(expiry, 1);
      expect(exclusions, 0);
      expect(ends, 0);
      final exclude = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '제외하고 계속하기'),
      );
      expect(exclude.onPressed, isNull);
      await tester.tap(find.text('게임 종료'));
      await tester.pump();
      expect(ends, 0);
      expect(find.text('게임을 종료할까요?'), findsOneWidget);
      await tester.tap(find.text('종료 확인'));
      await tester.pump();
      expect(ends, 1);
      await tester.pump(const Duration(seconds: 10));
      expect(expiry, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
