import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/platform/home/room/models/room_player.dart';
import 'package:project00/platform/home/room/services/controller_presence.dart';
import 'package:project00/platform/home/room/services/player_presence.dart';
import 'package:project00/platform/home/room/services/room_service.dart';

Future<void> settle() async {
  for (var i = 0; i < 4; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test(
    'controller binds current tuple, resets cached time and cancels old leaf listeners',
    () async {
      final db = _Database();
      final service = RoomService(
        database: db,
        auth: _Auth(),
        functions: _Functions(),
      );
      final values = <ControllerPresence>[];
      final subscription = service
          .watchControllerPresence('ABCDE')
          .listen(values.add);
      for (final entry in {
        'roomInstanceId': 'room-one',
        'controllerUid': 'tablet',
        'controllerCurrentConnectionId': 'old',
        'controllerConnectionSeq': 1,
      }.entries) {
        db.send('rooms/ABCDE/${entry.key}', entry.value);
      }
      await settle();
      db.send('rooms/ABCDE/connections/tablet/old/connected', true);
      await settle();
      expect(
        values.last.isEmpty,
        true,
        reason: 'no stale judgment before canonical time arrives',
      );
      db.send('rooms/ABCDE/connections/tablet/old/lastSeen', 1000);
      await settle();
      expect(values.last.lastSeen, 1000);
      db.send('rooms/ABCDE/controllerCurrentConnectionId', 'new');
      db.send('rooms/ABCDE/controllerConnectionSeq', 2);
      await settle();
      expect(values.last.isEmpty, true);
      expect(db.listeners['rooms/ABCDE/connections/tablet/old/lastSeen'], 0);
      db.send('rooms/ABCDE/connections/tablet/old/lastSeen', 1);
      db.send('rooms/ABCDE/connections/tablet/new/connected', true);
      db.send('rooms/ABCDE/connections/tablet/new/lastSeen', 30000);
      await settle();
      expect(values.last.connectionId, 'new');
      expect(values.last.connectionSeq, 2);
      expect(values.last.lastSeen, 30000);
      expect(
        judgeControllerPresence(values.last, nowMillis: 50000),
        ControllerPresenceVerdict.connected,
      );
      expect(
        judgeControllerPresence(values.last, nowMillis: 50001),
        ControllerPresenceVerdict.reconnecting,
      );
      db
          .stream('rooms/ABCDE/connections/tablet/new/connected')
          .addError(StateError('peer permission changed'));
      await settle();
      expect(values.last.isEmpty, true);
      db.send('rooms/ABCDE/connections/tablet/new/lastSeen', 60000);
      await settle();
      expect(
        values.last.isEmpty,
        true,
        reason: 'a late sibling leaf cannot revive a failed scope',
      );
      await subscription.cancel();
      expect(db.listeners.values.every((v) => v == 0), true);
      await db.close();
    },
  );

  test(
    'tablet observes N peers only while playing; phone observes its own connection only',
    () async {
      final db = _Database();
      final service = RoomService(
        database: db,
        auth: _Auth(),
        functions: _Functions(),
      );
      final lists = <List<RoomPlayer>>[];
      final tablet = service
          .watchRoomPlayers('ABCDE', observeCurrent: true)
          .listen(lists.add);
      db.send('rooms/ABCDE/roomInstanceId', 'room-one');
      db.send('rooms/ABCDE/players', {
        'a': {
          'membershipId': 'ma',
          'currentConnectionId': 'ca',
          'connectionSeq': 1,
          'lastSeen': 1,
        },
        'b': {
          'membershipId': 'mb',
          'currentConnectionId': 'cb',
          'connectionSeq': 2,
          'lastSeen': 2,
        },
      });
      db.send('rooms/ABCDE/status', 'waiting');
      await settle();
      expect(db.activeConnections, isEmpty);
      db.send('rooms/ABCDE/status', 'playing');
      await settle();
      expect(db.activeConnections.length, 4);
      expect(lists.last.every((p) => p.lastSeen == null), true);
      db.send('rooms/ABCDE/connections/a/ca/connected', true);
      db.send('rooms/ABCDE/connections/a/ca/lastSeen', 30000);
      await settle();
      expect(lists.last.first.lastSeen, 30000);
      db.send('rooms/ABCDE/status', 'waiting');
      await settle();
      expect(db.activeConnections, isEmpty);
      await tablet.cancel();
      final phone = service
          .watchRoomPlayers('ABCDE', ownUid: 'a')
          .listen((_) {});
      db.send('rooms/ABCDE/roomInstanceId', 'room-one');
      db.send('rooms/ABCDE/players', {
        'a': {
          'membershipId': 'ma',
          'currentConnectionId': 'ca',
          'connectionSeq': 1,
        },
        'b': {
          'membershipId': 'mb',
          'currentConnectionId': 'cb',
          'connectionSeq': 2,
        },
      });
      await settle();
      expect(db.activeConnections.length, 2);
      expect(db.activeConnections.every((p) => p.contains('/a/ca/')), true);
      expect(db.listeners.containsKey('rooms/ABCDE/connections'), false);
      await phone.cancel();
      expect(db.listeners.values.every((v) => v == 0), true);
      await db.close();
    },
  );

  test(
    'old stale response cannot exhaust a new membership with identical timestamp',
    () {
      final tracker = PlayerStaleReportTracker();
      expect(tracker.tryStartAttempt('a', 1000, binding: 'old'), true);
      expect(tracker.tryStartAttempt('a', 1000, binding: 'new'), true);
      tracker.markSucceeded('a', 1000, binding: 'old');
      expect(tracker.tryStartAttempt('a', 1000, binding: 'new'), true);
      expect(tracker.tryStartAttempt('a', 1000, binding: 'new'), false);
    },
  );
}

class _Database extends Fake implements FirebaseDatabase {
  final streams = <String, StreamController<DatabaseEvent>>{};
  final listeners = <String, int>{};
  StreamController<DatabaseEvent> stream(String path) => streams.putIfAbsent(
    path,
    () => StreamController.broadcast(
      sync: true,
      onListen: () => listeners[path] = (listeners[path] ?? 0) + 1,
      onCancel: () => listeners[path] = (listeners[path] ?? 0) - 1,
    ),
  );
  void send(String path, Object? value) => stream(path).add(_Event(value));
  List<String> get activeConnections => listeners.entries
      .where((e) => e.value > 0 && e.key.contains('/connections/'))
      .map((e) => e.key)
      .toList();
  Future<void> close() async {
    for (final stream in streams.values) {
      await stream.close();
    }
  }

  @override
  DatabaseReference ref([String? path]) => _Reference(this, path!);
}

class _Reference extends Fake implements DatabaseReference {
  _Reference(this.db, this.path);
  final _Database db;
  @override
  final String path;
  @override
  Stream<DatabaseEvent> get onValue => db.stream(path).stream;
  @override
  DatabaseReference child(String childPath) =>
      _Reference(db, '$path/$childPath');
}

class _Event extends Fake implements DatabaseEvent {
  _Event(Object? value) : snapshot = _Snapshot(value);
  @override
  final DataSnapshot snapshot;
}

class _Snapshot extends Fake implements DataSnapshot {
  _Snapshot(this.value);
  @override
  final Object? value;
  @override
  bool get exists => value != null;
}

class _Auth extends Fake implements FirebaseAuth {}

class _Functions extends Fake implements FirebaseFunctions {}
