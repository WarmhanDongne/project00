import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/recovery/services/controller_room_session_store.dart';
import 'package:project00/platform/home/gamelist/service/game_list_service.dart';
import 'package:project00/platform/home/room/models/room_player.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';
import 'package:project00/platform/home/room/services/controller_presence.dart';
import 'package:project00/platform/home/room/services/room_service.dart';
import 'package:project00/platform/home/tablet/widgets/tablet_room_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Service service;
  late RoomProvider provider;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ControllerRoomSessionStore.instance.clear();
    await ControllerRoomSessionStore.instance.save(
      roomCode: 'ABCDE',
      sessionId: 'controller-session',
    );
    service = _Service();
    provider = RoomProvider(
      service: service,
      gameService: _Games(),
      currentUidReader: () => 'tablet',
    );
  });
  tearDown(() async {
    provider.dispose();
    await ControllerRoomSessionStore.instance.clear();
  });

  test(
    'initial restore blocks allocation; failed restore retries the existing room',
    () async {
      service.gate = Completer<String?>();
      final restore = provider.restoreControllerRoom();
      await provider.createRoom();
      expect(service.creates, 0);
      expect(provider.isLoading, true);
      service.gate!.completeError(
        FirebaseFunctionsException(code: 'internal', message: 'server error'),
      );
      await restore;
      expect(provider.isLoading, false);
      expect(provider.errorMessage, isNotNull);
      expect(ControllerRoomSessionStore.instance.roomCode, 'ABCDE');

      service.gate = null;
      service.failRestore = false;
      await provider.createRoom();
      expect(service.restores, 2);
      expect(service.creates, 0);
      expect(provider.roomCode, 'ABCDE');
      expect(provider.errorMessage, isNull);
    },
  );

  testWidgets(
    'failed restore offers retry and close; confirmed close allows a new invite',
    (tester) async {
      // Shared stores were initialized outside FakeAsync; use their owning zone.
      await tester.runAsync(provider.restoreControllerRoom);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 310,
              height: 800,
              child: TabletRoomPanel(provider: provider),
            ),
          ),
        ),
      );
      expect(find.text('초대하기'), findsNothing);
      expect(find.text('다시 시도'), findsOneWidget);
      expect(find.byKey(const Key('close-unrestored-room')), findsOneWidget);

      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('close-unrestored-room')));
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pumpAndSettle();
      expect(service.closedCodes, ['ABCDE']);
      expect(ControllerRoomSessionStore.instance.roomCode, isNull);
      expect(provider.errorMessage, isNull);
      expect(find.text('초대하기'), findsOneWidget);
      await tester.tap(find.text('초대하기'));
      await tester.pumpAndSettle();
      expect(service.creates, 1);
      expect(provider.roomCode, 'NEW12');
    },
  );

  test(
    'unconfirmed close preserves the stored room and cannot allocate a new room',
    () async {
      await provider.restoreControllerRoom();
      service.failClose = true;
      await provider.closeRoom();
      expect(ControllerRoomSessionStore.instance.roomCode, 'ABCDE');
      await provider.createRoom();
      expect(service.creates, 0);
      expect(provider.roomCode, isNull);
      expect(service.restores, 2);
    },
  );
}

class _Service implements RoomService {
  int restores = 0, creates = 0;
  bool failRestore = true, failClose = false;
  Completer<String?>? gate;
  final closedCodes = <String>[];
  @override
  Future<String?> restoreControllerRoom() async {
    restores++;
    if (gate != null) return gate!.future;
    if (failRestore) {
      throw FirebaseFunctionsException(
        code: 'internal',
        message: 'server error',
      );
    }
    return 'ABCDE';
  }

  @override
  Future<String> createRoom({String? operationId}) async {
    creates++;
    return 'NEW12';
  }

  @override
  Future<void> closeControllerRoom(String code) async {
    closedCodes.add(code);
    if (failClose) {
      throw FirebaseFunctionsException(
        code: 'internal',
        message: 'server error',
      );
    }
    await ControllerRoomSessionStore.instance.clear(onlyRoomCode: code);
  }

  @override
  Stream<bool> watchServerConnection() => const Stream.empty();
  @override
  Stream<DatabaseEvent> watchRoom(String code) => const Stream.empty();
  @override
  Stream<List<RoomPlayer>> watchRoomPlayers(String code) =>
      const Stream.empty();
  @override
  Stream<String?> watchRoomStatus(String code) => const Stream.empty();
  @override
  Stream<ControllerPresence> watchControllerPresence(String code) =>
      const Stream.empty();
  @override
  Stream<bool> watchRoomExists(String code) => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Games implements GameService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
