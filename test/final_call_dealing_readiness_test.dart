import 'dart:async';
// ignore: depend_on_referenced_packages
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_final_call/shared/models/game_state.dart';
import 'package:game_final_call/shared/providers/game_controller.dart';
import 'package:game_final_call/shared/providers/session_provider.dart';
import 'package:game_final_call/shared/services/game_service.dart';
import 'package:game_final_call/tablet/tablet_board.dart';
import 'package:game_kit/models/game_room_context.dart';
import 'package:game_kit/recovery/models/game_recovery_context.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestFirebaseCoreHostApi.setUp(MockFirebaseApp());
  setUpAll(() async => Firebase.initializeApp());
  setUp(() {
    FirebaseAuthPlatform.instanceFor(
      app: Firebase.app(),
      pluginConstants: {
        'APP_CURRENT_USER': [
          InternalUserInfo(
            uid: 'tablet',
            isAnonymous: false,
            isEmailVerified: true,
          ).encode(),
          <Map<Object?, Object?>>[],
        ],
      },
    );
  });
  for (final stale in [false, true]) {
    testWidgets('dealing completion waits for readiness, stale=$stale', (
      tester,
    ) async {
      final service = _Service();
      final game = _Controller(service);
      final args = FinalCallSessionArgs(
        roomCode: 'DEALREADY',
        uid: 'tablet',
        service: service,
        watchPrivateHand: false,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [finalCallSessionProvider(args).overrideWith(() => game)],
          child: MaterialApp(
            home: FinalCallTabletGame(
              roomCode: 'DEALREADY',
              provider: _Room(),
              gameService: service,
            ),
          ),
        ),
      );
      final completed = tester
          .widget<FinalCallTabletGameLayer>(
            find.byType(FinalCallTabletGameLayer),
          )
          .onDealingCompleted;
      completed();
      await tester.pump(const Duration(seconds: 20));
      expect(game.calls, 0);
      if (stale) game.advanceRound();
      game.recoverySession.paused = false;
      game.recoverySession.changed();
      await tester.pump();
      expect(game.calls, stale ? 0 : 1);
      if (!stale) {
        completed();
        game.recoverySession.changed();
        await tester.pump();
        expect(game.calls, 1, reason: 'same completed animation sends once');
      }
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });
  }
}

class _Controller extends FinalCallController {
  _Controller(FinalCallService service)
    : super(roomCode: 'DEALREADY', uid: 'tablet', service: service);
  @override
  final recoverySession = GameRecoverySession()
    ..localUsable = true
    ..serverConfirmed = true
    ..paused = true;
  int calls = 0;
  @override
  int? get gameStartedAt => 100;
  @override
  FinalCallGameState build() =>
      FinalCallGameState.initial().copyWith(loading: false, phase: 'dealing');
  @override
  Future<bool> completeDealing() async {
    calls++;
    return true;
  }

  void advanceRound() => state = state.copyWith(round: 2);
}

class _Service extends Fake implements FinalCallService {}

class _Room extends Fake implements GameRoomContext {
  @override
  Stream<bool> watchServerConnection() => const Stream.empty();
}
