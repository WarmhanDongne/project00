import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_final_call/phone/phone_board.dart';
import 'package:game_final_call/phone/providers/game_stage.dart';
import 'package:game_final_call/phone/screens/game_screen.dart';
import 'package:game_final_call/shared/models/game_state.dart';
import 'package:game_final_call/shared/providers/game_controller.dart';
import 'package:game_final_call/shared/providers/session_provider.dart';
import 'package:game_final_call/shared/services/game_service.dart';
import 'package:game_kit/game_flow/phone_game_shell.dart';
import 'package:game_kit/models/game_room_context.dart';

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
            uid: 'phone',
            isAnonymous: false,
            isEmailVerified: true,
          ).encode(),
          <Map<Object?, Object?>>[],
        ],
      },
    );
    expect(FirebaseAuth.instance.currentUser?.uid, 'phone');
  });

  for (final accepted in [true, false]) {
    testWidgets(
      'replacement sends before animation, locks duplicates, accepted=$accepted',
      (tester) async {
        final service = _Service();
        final game = _Controller(service);
        final args = FinalCallSessionArgs(
          roomCode: 'LATENCY',
          uid: 'phone',
          service: service,
          watchPrivateHand: true,
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              finalCallSessionProvider(args).overrideWith(() => game),
            ],
            child: MaterialApp(
              home: FinalCallPhoneGame(
                roomCode: 'LATENCY',
                provider: _Room(),
                gameService: service,
                onExitRoom: () async => true,
              ),
            ),
          ),
        );
        // Use the board's real action binding without waiting for unrelated intro assets.
        FinalCallPhoneGameScreen screen() {
          final shell = tester.widget<PhoneGameShell<FinalCallPhoneStage>>(
            find.byType(PhoneGameShell<FinalCallPhoneStage>),
          );
          return (shell.content as RepaintBoundary).child!
              as FinalCallPhoneGameScreen;
        }

        final action = screen().onCompleteTurn('card');
        expect(game.calls, 1);
        await screen().onCompleteTurn('card');
        expect(game.calls, 1);
        game.reply.complete(accepted);
        await tester.pump();
        expect(screen().replacementInProgress, isTrue);
        await tester.pump(const Duration(milliseconds: 459));
        expect(screen().replacementInProgress, isTrue);
        await tester.pump(const Duration(milliseconds: 1));
        await action;
        await tester.pump();
        expect(screen().replacementInProgress, isFalse);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}

class _Controller extends FinalCallController {
  _Controller(FinalCallService service)
    : super(roomCode: 'LATENCY', uid: 'phone', service: service);
  final reply = Completer<bool>();
  int calls = 0;
  @override
  FinalCallGameState build() => FinalCallGameState.initial();
  @override
  bool get canCompleteTurn => true;
  @override
  Future<bool> completeTurn(String? replaceCardId) {
    calls++;
    expect(replaceCardId, 'card');
    return reply.future;
  }
}

class _Service extends Fake implements FinalCallService {}

class _Room extends Fake implements GameRoomContext {
  @override
  Stream<bool> watchServerConnection() => const Stream.empty();
}
