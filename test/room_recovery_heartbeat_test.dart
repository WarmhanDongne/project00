import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/recovery/models/room_session_identity.dart';
import 'package:game_kit/recovery/services/controller_room_session_store.dart';
import 'package:game_kit/recovery/services/room_recovery_batch.dart';
import 'package:game_kit/recovery/services/room_session_identity_store.dart';
import 'package:project00/platform/home/gamelist/service/game_list_service.dart';
import 'package:project00/platform/home/room/models/room_player.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';
import 'package:project00/platform/home/room/services/controller_presence.dart';
import 'package:project00/platform/home/room/services/room_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('invalidated controller restore cannot start player heartbeats', () async {
    SharedPreferences.setMockInitialValues({});
    const identity = RoomSessionIdentity(
      uid: 'stale-controller',
      role: 'controller',
      roomCode: 'STALE',
      roomInstanceId: 'stale-room',
      connectionId: 'controller-connection',
      connectionSeq: 1,
      controllerSessionId: 'old-controller-session',
    );
    await RoomSessionIdentityStore.instance.save(identity);
    // The same tablet account can also be a player; losing its controller token
    // must not silently switch the heartbeat role during controller recovery.
    await RoomSessionIdentityStore.instance.save(
      const RoomSessionIdentity(
        uid: 'stale-controller',
        role: 'player',
        roomCode: 'STALE',
        roomInstanceId: 'stale-room',
        connectionId: 'player-connection',
        connectionSeq: 1,
        membershipId: 'member',
      ),
    );
    await ControllerRoomSessionStore.instance.save(
      roomCode: identity.roomCode,
      sessionId: identity.controllerSessionId!,
    );
    final database = _Database();
    final service = _RecoveryService(identity, database)
      ..afterControllerRestore = ControllerRoomSessionStore.instance.clear;
    final provider = RoomProvider(
      service: service,
      gameService: _UnusedGameService(),
      currentUidReader: () => identity.uid,
    )..roomCode = identity.roomCode;
    addTearDown(() async {
      provider.dispose();
      await service.connected.close();
      await RoomSessionIdentityStore.instance.clear(
        identity.uid,
        'controller',
        identity.roomCode,
      );
      await RoomSessionIdentityStore.instance.clear(
        identity.uid,
        'player',
        identity.roomCode,
      );
      await ControllerRoomSessionStore.instance.clear();
    });
    provider.listenRoom();
    service.connected.add(true);
    await Future<void>.delayed(Duration.zero);
    await provider.retryConnectionRecovery();
    await Future<void>.delayed(const Duration(seconds: 11));
    expect(database.paths, isEmpty);
  });

  test(
    'controller and player keep writing heartbeats after recovery budget expires',
    () async {
      SharedPreferences.setMockInitialValues({});
      await ControllerRoomSessionStore.instance.clear();
      final services = <_RecoveryService>[];
      final providers = <RoomProvider>[];
      addTearDown(() async {
        for (final provider in providers) {
          provider.dispose();
        }
        for (final service in services) {
          await service.connected.close();
          await RoomSessionIdentityStore.instance.clear(
            service.identity.uid,
            service.identity.role,
            service.identity.roomCode,
          );
        }
        await ControllerRoomSessionStore.instance.clear();
      });

      for (final role in ['controller', 'player']) {
        final identity = RoomSessionIdentity(
          uid: 'heartbeat-$role',
          role: role,
          roomCode: role == 'controller' ? 'HEART' : 'BEATS',
          roomInstanceId: 'room-$role',
          membershipId: role == 'player' ? 'member' : null,
          controllerSessionId: role == 'controller'
              ? 'controller-session'
              : null,
          connectionId: 'connection-$role',
          connectionSeq: 1,
        );
        await RoomSessionIdentityStore.instance.save(identity);
        if (role == 'controller') {
          await ControllerRoomSessionStore.instance.save(
            roomCode: identity.roomCode,
            sessionId: identity.controllerSessionId!,
          );
        }
        final database = _Database();
        final service = _RecoveryService(identity, database);
        services.add(service);
        final provider =
            RoomProvider(
                service: service,
                gameService: _UnusedGameService(),
                currentUidReader: () => identity.uid,
              )
              ..roomCode = identity.roomCode
              ..players = [
                RoomPlayer.fromJson({'nickname': 'Tester'}, key: identity.uid),
              ]
              ..listenRoom();
        providers.add(provider);
        service.connected.add(true);
        await Future<void>.delayed(Duration.zero);
        await provider.retryConnectionRecovery();
        database.recoveryOwner = service.recoveryOwner;
        expect(service.recoveryOwner, isNotNull);
      }

      // Use wall-clock time: RoomRecoveryBatch's Stopwatch is not FakeAsync time.
      // Both roles use the real RoomService identity lookup and write/retry path.
      await Future<void>.delayed(const Duration(seconds: 32));
      for (final service in services) {
        expect(
          service.recoveryOwner!.remaining,
          lessThanOrEqualTo(Duration.zero),
        );
        expect(
          service.database.writesAfterDeadline,
          greaterThan(0),
          reason:
              '${service.identity.role} must outlive the recovery operation',
        );
        expect(service.database.ownersAtWrite, everyElement(isNull));
        expect(
          service.database.paths,
          everyElement(
            'rooms/${service.identity.roomCode}/connections/${service.identity.uid}/${service.identity.connectionId}',
          ),
        );
      }
    },
    timeout: const Timeout(Duration(seconds: 55)),
  );
}

class _RecoveryService extends RoomService {
  _RecoveryService(this.identity, this.database)
    : super(
        database: database,
        auth: _Auth(identity.uid),
        functions: _Functions(),
      );

  final RoomSessionIdentity identity;
  final _Database database;
  final connected = StreamController<bool>.broadcast();
  RoomRecoveryBatch? recoveryOwner;
  Future<void> Function()? afterControllerRestore;

  @override
  Future<String?> restoreControllerRoom() async {
    recoveryOwner = RoomRecoveryBatch.current;
    await afterControllerRestore?.call();
    return identity.roomCode;
  }

  @override
  Future<void> restorePlayerConnection({
    required String roomCode,
    required String nickname,
    required String characterId,
  }) async {
    recoveryOwner = RoomRecoveryBatch.current;
  }

  @override
  Stream<bool> watchServerConnection() => connected.stream;
  @override
  Stream<ControllerPresence> watchControllerPresence(String roomCode) =>
      const Stream.empty();
  @override
  Stream<bool> watchRoomExists(String roomCode) => const Stream.empty();
  @override
  Stream<String?> watchRoomStatus(String roomCode) => const Stream.empty();
  @override
  Stream<DatabaseEvent> watchRoom(String roomCode) => const Stream.empty();
  @override
  Stream<List<RoomPlayer>> watchRoomPlayers(String roomCode) =>
      const Stream.empty();
}

class _Database extends Fake implements FirebaseDatabase {
  RoomRecoveryBatch? recoveryOwner;
  int writesAfterDeadline = 0;
  final ownersAtWrite = <RoomRecoveryBatch?>[];
  final paths = <String>[];
  @override
  DatabaseReference ref([String? path]) => _Reference(this, path!);
}

class _Reference extends Fake implements DatabaseReference {
  _Reference(this.database, this.path);
  final _Database database;
  @override
  final String path;
  @override
  Future<void> update(Map<String, Object?> value) async {
    expect(value['connected'], true);
    expect(value['lastSeen'], ServerValue.timestamp);
    database.paths.add(path);
    database.ownersAtWrite.add(RoomRecoveryBatch.inherited);
    if ((database.recoveryOwner?.remaining ?? const Duration(seconds: 30)) <=
        Duration.zero) {
      database.writesAfterDeadline++;
    }
  }
}

class _Auth extends Fake implements FirebaseAuth {
  _Auth(String uid) : currentUser = _User(uid);
  @override
  final User currentUser;
}

class _User extends Fake implements User {
  _User(this.uid);
  @override
  final String uid;
}

class _Functions extends Fake implements FirebaseFunctions {}

class _UnusedGameService extends Fake implements GameService {}
