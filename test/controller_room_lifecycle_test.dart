import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/platform/home/gamelist/service/game_list_service.dart';
import 'package:project00/platform/home/room/models/room_player.dart';
import 'package:project00/core/time/server_clock.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';
import 'package:project00/platform/home/room/services/controller_presence.dart';
import 'package:project00/platform/home/room/services/room_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  for (final change in ['marker-recovered', 'reconnected']) {
    test('late missing-room reply is ignored after $change', () async {
      final gate = Completer<bool>();
      final service = _LifecycleRoomService()..roomExistsGate = gate;
      final provider = _provider(service)
        ..roomCode = 'ABCDE'
        ..listenRoom();
      addTearDown(() async {
        provider.dispose();
        await service.dispose();
      });
      service.serverConnection.add(true);
      service.roomExistsChanges.add(false);
      await _flushEvents();
      expect(service.roomExistenceReads, 1);
      if (change == 'marker-recovered') {
        service.roomExistsChanges.add(true);
      } else {
        service.serverConnection.add(false);
        service.serverConnection.add(true);
      }
      await _flushEvents();
      gate.complete(false);
      await _flushEvents();
      expect(provider.roomCode, 'ABCDE');
      expect(provider.roomTerminationReason, isNull);
      if (change == 'reconnected') expect(service.roomExistenceReads, 2);
    });
  }

  test(
    'controller false only enters reconnecting and keeps the room',
    () async {
      final service = _LifecycleRoomService();
      final provider = _provider(service)
        ..roomCode = 'ABCDE'
        ..listenRoom();
      addTearDown(() async {
        provider.dispose();
        await service.dispose();
      });

      service.serverConnection.add(true);
      service.roomExistsChanges.add(true);
      // 태블릿이 스스로 내려간다고 알린 경우입니다. 유예 없이 즉시 표시합니다.
      service.controllerPresence.add(
        ControllerPresence(connected: false, lastSeen: ServerClock.nowMillis()),
      );
      service.roomStatus.add(null);
      await _flushEvents();

      expect(
        provider.controllerPresenceState,
        ControllerPresenceState.reconnecting,
      );
      expect(provider.roomCode, 'ABCDE');
      expect(provider.roomTerminationReason, isNull);
      expect(provider.wasRoomClosed, isFalse);

      service.roomStatus.add('finished');
      await _flushEvents();
      expect(provider.roomCode, 'ABCDE');

      service.controllerPresence.add(
        ControllerPresence(connected: true, lastSeen: ServerClock.nowMillis()),
      );
      await _flushEvents();
      expect(
        provider.controllerPresenceState,
        ControllerPresenceState.connected,
      );
    },
  );

  test('closed is an immediate terminal room state', () async {
    final service = _LifecycleRoomService();
    final provider = _provider(service)
      ..roomCode = 'ABCDE'
      ..listenRoom();
    addTearDown(() async {
      provider.dispose();
      await service.dispose();
    });

    service.serverConnection.add(true);
    service.roomStatus.add('closed');
    await _flushEvents();

    expect(provider.roomCode, isNull);
    expect(provider.wasRoomClosed, isTrue);
    expect(provider.roomTerminationReason, RoomTerminationReason.closed);
  });

  test(
    'missing room marker is confirmed before treating the room as deleted',
    () async {
      final service = _LifecycleRoomService()..confirmedRoomExists = false;
      final provider = _provider(service)
        ..roomCode = 'ABCDE'
        ..listenRoom();
      addTearDown(() async {
        provider.dispose();
        await service.dispose();
      });

      // 오프라인에서 받은 빈 캐시는 종료 조건이 아닙니다.
      service.serverConnection.add(false);
      service.roomExistsChanges.add(false);
      await _flushEvents();
      expect(provider.roomCode, 'ABCDE');
      expect(service.roomExistenceReads, 0);

      // 서버 연결이 돌아온 뒤 같은 후보를 재조회해 삭제를 확정합니다.
      service.serverConnection.add(true);
      await _flushEvents();
      expect(service.roomExistenceReads, 1);
      expect(provider.roomCode, isNull);
      expect(provider.roomTerminationReason, RoomTerminationReason.deleted);
    },
  );
}

Future<void> _flushEvents() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

RoomProvider _provider(_LifecycleRoomService service) =>
    RoomProvider(service: service, gameService: _NoopGameService());

class _LifecycleRoomService implements RoomService {
  final serverConnection = StreamController<bool>.broadcast();
  final controllerPresence = StreamController<ControllerPresence>.broadcast();
  final roomExistsChanges = StreamController<bool>.broadcast();
  final roomStatus = StreamController<String?>.broadcast();
  bool confirmedRoomExists = true;
  Completer<bool>? roomExistsGate;
  int roomExistenceReads = 0;

  @override
  Stream<bool> watchServerConnection() => serverConnection.stream;

  @override
  Stream<ControllerPresence> watchControllerPresence(String roomCode) =>
      controllerPresence.stream;

  @override
  Stream<bool> watchRoomExists(String roomCode) => roomExistsChanges.stream;

  @override
  Future<bool> roomExists(String roomCode) async {
    roomExistenceReads += 1;
    final gate = roomExistsGate;
    roomExistsGate = null;
    if (gate != null) return gate.future;
    return confirmedRoomExists;
  }

  @override
  Stream<String?> watchRoomStatus(String roomCode) => roomStatus.stream;

  @override
  Stream<DatabaseEvent> watchRoom(String roomCode) => const Stream.empty();

  @override
  Stream<List<RoomPlayer>> watchRoomPlayers(String roomCode) =>
      const Stream.empty();

  Future<void> dispose() async {
    await Future.wait([
      serverConnection.close(),
      controllerPresence.close(),
      roomExistsChanges.close(),
      roomStatus.close(),
    ]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoopGameService implements GameService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
