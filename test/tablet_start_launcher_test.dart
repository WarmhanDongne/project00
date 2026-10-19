import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/models/game_room_context.dart';
import 'package:game_kit/player_layouts/player_layout_model.dart';
import 'package:game_kit/recovery/models/game_recovery_context.dart';
import 'package:game_kit/recovery/models/room_session_identity.dart';
import 'package:game_kit/recovery/services/room_session_identity_store.dart';
import 'package:game_kit/template_game.dart';
import 'package:project00/platform/home/gamelist/models/game_info.dart';
import 'package:project00/platform/home/gamelist/service/game_list_service.dart';
import 'package:project00/platform/home/room/models/room_player.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';
import 'package:project00/platform/home/room/services/room_service.dart';
import 'package:project00/platform/home/tablet/tablet_game_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _identity = RoomSessionIdentity(
  uid: 'launcher-controller',
  role: 'controller',
  roomCode: 'ABCDE',
  roomInstanceId: 'room-one',
  connectionId: 'connection-one',
  connectionSeq: 1,
  controllerSessionId: 'session-one',
);
void _user(String uid) {
  FirebaseAuthPlatform.instanceFor(
    app: Firebase.app(),
    pluginConstants: {
      'APP_CURRENT_USER': [
        InternalUserInfo(
          uid: uid,
          isAnonymous: false,
          isEmailVerified: true,
        ).encode(),
        <Map<Object?, Object?>>[],
      ],
    },
  );
  expect(FirebaseAuth.instance.currentUser?.uid, uid);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestFirebaseCoreHostApi.setUp(MockFirebaseApp());
  setUpAll(() async => Firebase.initializeApp());
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _user(_identity.uid);
    await RoomSessionIdentityStore.instance.save(_identity);
    GameRecoverySession.forRoom(
      'ABCDE',
      _identity.uid,
    ).context = const GameRecoveryContext(
      gameInstanceId: 'older-game',
      phaseSeq: 1,
      turnSeq: 1,
      dataSeq: 1,
      resumeEpoch: 0,
    );
  });

  for (final id in ['liars_poker', 'final_call', 'holdem', 'mafia']) {
    testWidgets(
      '$id uses successful start lookup during remaining setup and survives rebuild',
      (tester) async {
        final game = _Game(id);
        final room = _Room(game);
        addTearDown(room.dispose);
        late StateSetter rebuild;
        var theme = false;
        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return MaterialApp(
                theme: theme ? ThemeData.dark() : ThemeData.light(),
                home: Builder(
                  builder: (context) => Scaffold(
                    body: TextButton(
                      onPressed: () => unawaited(
                        launchTabletGame(
                          context: context,
                          game: GameInfo.fromJson({
                            'id': id,
                            'name': id,
                            'minPlayers': 2,
                          }),
                          provider: room,
                          ensureSelection: () async => true,
                          isCurrent: () => context.mounted,
                          onLaunched: () {},
                        ),
                      ),
                      child: const Text('launch'),
                    ),
                  ),
                ),
              );
            },
          ),
        );
        await tester.tap(find.text('launch'));
        await tester.pumpAndSettle();
        expect(find.text('setup'), findsOneWidget);
        await tester.runAsync(() async {
          final prepared = game.prepare!(game.layout!);
          await Future<void>.delayed(Duration.zero);
          expect(game.starts, 1);
          expect(room.reads, 0);
          game.startGate.complete();
          expect(await prepared, true);
        });
        expect(room.reads, 1);
        expect(
          find.text('playing'),
          findsNothing,
        ); // animation has not completed
        rebuild(() => theme = true);
        await tester.pumpAndSettle();
        expect(
          await game.prepare!(game.layout!),
          false,
        ); // duplicate tap after rebuild
        expect(game.starts, 1);
        await tester.runAsync(() async {
          room.readGate.complete({
            ..._identity.envelope,
            'gameInstanceId': 'started-game',
          });
          await Future<void>.delayed(Duration.zero);
          game.complete!(game.layout!);
          game.complete!(game.layout!);
          await Future<void>.delayed(Duration.zero);
        });
        await tester.pumpAndSettle();
        expect(find.text('playing'), findsOneWidget);
        expect(room.reads, 1);
        expect(game.starts, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }
  for (final reason in [
    'failed seats',
    'failed start',
    'new connection',
    'new account',
    'dispose',
    'new game',
    'new game before lookup',
  ]) {
    testWidgets('$reason cannot use stale lookup to transition', (
      tester,
    ) async {
      final game = _Game('liars_poker');
      final room = _Room(game)..seatsSaved = reason != 'failed seats';
      addTearDown(room.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => unawaited(
                  launchTabletGame(
                    context: context,
                    game: GameInfo.fromJson({
                      'id': game.id,
                      'name': game.id,
                      'minPlayers': 2,
                    }),
                    provider: room,
                    ensureSelection: () async => true,
                    isCurrent: () => context.mounted,
                    onLaunched: () {},
                  ),
                ),
                child: const Text('launch'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('launch'));
      await tester.pumpAndSettle();
      if (reason == 'failed seats' || reason == 'failed start') {
        await tester.runAsync(() async {
          final prepared = game.prepare!(game.layout!);
          if (reason == 'failed start') {
            await Future<void>.delayed(Duration.zero);
            game.startGate.completeError(StateError('start failure'));
          }
          expect(await prepared, false);
          expect(game.starts, reason == 'failed seats' ? 0 : 1);
          expect(room.reads, 0);
        });
      } else {
        await tester.runAsync(() async {
          final prepared = game.prepare!(game.layout!);
          await Future<void>.delayed(Duration.zero);
          expect(game.starts, 1);
          game.startGate.complete();
          expect(await prepared, true);
        });
        expect(room.reads, 1);
        if (reason == 'new connection') {
          await tester.runAsync(
            () => RoomSessionIdentityStore.instance.save(
              RoomSessionIdentity(
                uid: _identity.uid,
                role: 'controller',
                roomCode: 'ABCDE',
                roomInstanceId: 'room-two',
                connectionId: 'connection-two',
                connectionSeq: 2,
                controllerSessionId: 'session-two',
              ),
            ),
          );
        } else if (reason == 'new account') {
          _user('other-controller');
        } else if (reason == 'dispose') {
          Navigator.of(tester.element(find.text('setup'))).pop();
          await tester.pumpAndSettle();
        }
        if (reason == 'new game before lookup') {
          GameRecoverySession.forRoom(
            'ABCDE',
            _identity.uid,
          ).context = const GameRecoveryContext(
            gameInstanceId: 'replacement-game',
            phaseSeq: 1,
            turnSeq: 1,
            dataSeq: 1,
            resumeEpoch: 0,
          );
        }
        await tester.runAsync(() async {
          room.readGate.complete({
            ..._identity.envelope,
            'gameInstanceId': 'started-game',
          });
          await Future<void>.delayed(Duration.zero);
        });
        if (reason == 'new game') {
          GameRecoverySession.forRoom(
            'ABCDE',
            _identity.uid,
          ).context = const GameRecoveryContext(
            gameInstanceId: 'replacement-game',
            phaseSeq: 1,
            turnSeq: 1,
            dataSeq: 1,
            resumeEpoch: 0,
          );
        }
        await tester.runAsync(() async {
          game.complete!(game.layout!);
          await Future<void>.delayed(Duration.zero);
        });
        await tester.pumpAndSettle();
        expect(find.text('playing'), findsNothing);
        expect(room.reads, 1);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }, timeout: const Timeout(Duration(seconds: 15)));
  }
}

class _Room extends RoomProvider {
  _Room(_Game game)
    : super(
        service: _Service(),
        gameService: _GameService(),
        gameCatalog: _Catalog(game),
        currentUidReader: () => _identity.uid,
      ) {
    roomCode = 'ABCDE';
    players = [
      for (var i = 0; i < 2; i++)
        RoomPlayer(
          uid: 'phone-$i',
          nickname: 'phone',
          characterId: 'burger',
          seatIndex: i,
          isConnected: true,
          role: 'player',
          status: 'active',
          penaltyAttemptCount: 0,
        ),
    ];
  }
  int reads = 0;
  bool seatsSaved = true;
  final readGate = Completer<Map<String, dynamic>?>.sync();
  @override
  Future<bool> beginPlayerSeating() async => true;
  @override
  Future<bool> savePlayerSeatIndexes(Map<String, int> seats) async =>
      seatsSaved;
  @override
  Future<Map<String, dynamic>?> captureGameTarget() {
    reads++;
    return readGate.future;
  }
}

class _Catalog implements GameCatalog {
  _Catalog(this.game);
  final _Game game;
  @override
  Iterable<TemplateGame> get games => [game];
  @override
  TemplateGame? find(String id) => game.id == id ? game : null;
}

class _Game extends TemplateGame {
  _Game(this.id);
  @override
  final String id;
  int starts = 0;
  final startGate = Completer<void>.sync();
  PlayerLayoutModel? layout;
  Future<bool> Function(PlayerLayoutModel, {Map<String, Object?>? options})?
  prepare;
  void Function(PlayerLayoutModel)? complete;
  @override
  Future<void> startGame(String code, {Map<String, Object?>? options}) {
    starts++;
    return startGate.future;
  }

  @override
  Widget? buildStartSetupScreen({
    required PlayerLayoutModel layout,
    required Future<bool> Function(
      PlayerLayoutModel, {
      Map<String, Object?>? options,
    })
    onPrepare,
    required void Function(PlayerLayoutModel) onComplete,
    required Future<bool> Function() onCancel,
  }) {
    this.layout = layout;
    prepare = onPrepare;
    complete = onComplete;
    return const Scaffold(body: Text('setup'));
  }

  @override
  Widget buildTabletScreen({
    required PlayerLayoutModel playerLayout,
    required GameRoomContext provider,
    required String roomCode,
  }) => const Scaffold(body: Text('playing'));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Service extends Fake implements RoomService {}

class _GameService extends Fake implements GameService {}
