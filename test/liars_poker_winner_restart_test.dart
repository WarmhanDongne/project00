import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/models/game_room_context.dart';
import 'package:game_kit/phone/widgets/result_dialog.dart';
import 'package:game_kit/recovery/services/game_interruption_command_service.dart';
import 'package:game_liars_poker/phone/phone_board.dart';
import 'package:game_liars_poker/phone/screens/game_screen.dart';
import 'package:game_liars_poker/shared/services/command_service.dart';
import 'package:game_liars_poker/shared/services/game_service.dart';
import 'package:game_liars_poker/shared/services/query_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestFirebaseCoreHostApi.setUp(MockFirebaseApp());
  setUpAll(() async => Firebase.initializeApp());
  setUp(() {
    SharedPreferences.setMockInitialValues({});
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

  var roomNumber = 0;
  Future<_Query> mount(
    WidgetTester tester, {
    NavigatorObserver? observer,
  }) async {
    final query = _Query();
    await tester.pumpWidget(
      ProviderScope(
        child: DefaultAssetBundle(
          bundle: _Assets(),
          child: MaterialApp(
            navigatorObservers: [?observer],
            home: LiarsPokerPhoneGame(
              roomCode: 'WINNER${++roomNumber}',
              provider: _Room(),
              gameService: LiarsPokerService(
                query: query,
                command: _Commands(),
                interruption: _Reports(),
              ),
              onExitRoom: () async => true,
            ),
          ),
        ),
      ),
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await query.pub.close();
      await query.priv.close();
    });
    return query;
  }

  testWidgets(
    'restart before winner dialog builds removes the old winner route',
    (tester) async {
      final observer = _DialogObserver();
      final query = await mount(tester, observer: observer);
      observer.onDialog = () =>
          scheduleMicrotask(() => query.send('next', finished: false));
      query.send('first', finished: true);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(PhoneResultDialog), findsNothing);
      expect(find.byType(LiarsPokerPhoneGameScreen), findsOneWidget);
      expect(
        observer.dialogs,
        1,
        reason: 'The race occurs after route push, before its builder',
      );
    },
  );

  testWidgets(
    'visible winner closes immediately on restart and same winner can win again',
    (tester) async {
      final query = await mount(tester);
      query.send('first', finished: true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(PhoneResultDialog), findsOneWidget);
      query.send('second', finished: false);
      await tester.pump();
      expect(find.byType(PhoneResultDialog), findsNothing);
      expect(find.byType(LiarsPokerPhoneGameScreen), findsOneWidget);
      query.send('second', finished: true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(PhoneResultDialog), findsOneWidget);
    },
  );
  testWidgets('restart removes only the winner while another dialog remains', (
    tester,
  ) async {
    final query = await mount(tester);
    query.send('first', finished: true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    unawaited(
      showDialog<void>(
        context: tester.element(find.byType(LiarsPokerPhoneGame)),
        builder: (_) => const AlertDialog(title: Text('Another notice')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(PhoneResultDialog), findsOneWidget);
    expect(find.text('Another notice'), findsOneWidget);
    query.send('second', finished: false);
    await tester.pump();
    expect(find.byType(PhoneResultDialog), findsNothing);
    expect(find.text('Another notice'), findsOneWidget);
    expect(find.byType(LiarsPokerPhoneGameScreen), findsOneWidget);
  });
}

class _DialogObserver extends NavigatorObserver {
  int dialogs = 0;
  VoidCallback? onDialog;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is DialogRoute<void>) {
      dialogs++;
      onDialog?.call();
    }
  }
}

class _Room extends Fake implements GameRoomContext {
  @override
  String? get roomCode => 'WINNER';
  @override
  List<GameRoomPlayer> get players => [];
  @override
  GameRoomMetadata? get selectedGame => null;
  @override
  bool get isLeaving => false;
}

class _Query extends Fake implements LiarsPokerQueryService {
  final pub = StreamController<DatabaseEvent>.broadcast();
  final priv = StreamController<DatabaseEvent>.broadcast();
  void send(String game, {required bool finished}) {
    pub.add(
      _Event({
        'gameInstanceId': game,
        'phaseSeq': finished ? 2 : 1,
        'turnSeq': 1,
        'dataSeq': finished ? 2 : 1,
        'resumeEpoch': 1,
        'revision': finished ? 2 : 1,
        'status': finished ? 'finished' : 'playing',
        'phase': finished ? 'finished' : 'dealing',
        'winnerUid': finished ? 'phone' : null,
        'gameType': 'liars_poker',
        'players': {
          'phone': {
            'nickname': 'Winner',
            'characterId': 'cat',
            'status': 'alive',
            'remainingCardCount': 5,
          },
          'other': {
            'nickname': 'Other',
            'characterId': 'cat',
            'status': 'alive',
            'remainingCardCount': 5,
          },
        },
        'recovery': {'paused': false},
      }),
    );
    priv.add(
      _Event({
        '_context': {
          'gameInstanceId': game,
          'phaseSeq': finished ? 2 : 1,
          'turnSeq': 1,
          'dataSeq': finished ? 2 : 1,
        },
        'hand': {
          'card': {'rank': 'K'},
        },
      }),
    );
  }

  @override
  Stream<DatabaseEvent> watchPublicGame(String roomCode) => pub.stream;
  @override
  Stream<DatabaseEvent> watchPrivatePlayer({
    required String roomCode,
    required String uid,
  }) => priv.stream;
  @override
  Future<DataSnapshot> readPublicGame(String roomCode) async => _Snapshot(null);
}

class _Snapshot extends Fake implements DataSnapshot {
  _Snapshot(this.value);
  @override
  final Object? value;
  @override
  bool get exists => value != null;
}

class _Event extends Fake implements DatabaseEvent {
  _Event(Object? value) : snapshot = _Snapshot(value);
  @override
  final DataSnapshot snapshot;
}

class _Commands extends Fake implements LiarsPokerCommandService {}

class _Reports extends Fake implements GameInterruptionCommandService {
  @override
  Future<Map<String, dynamic>> report({
    required String roomCode,
    required Map<String, dynamic> context,
    required int reportSeq,
    required bool ready,
  }) async => {'status': 'accepted'};
}

class _Assets extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    if (key.endsWith('.png') || key.endsWith('.webp')) {
      return ByteData.sublistView(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
        ),
      );
    }
    return rootBundle.load(key);
  }
}
