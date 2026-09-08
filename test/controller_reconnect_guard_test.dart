import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/platform/home/phone/widgets/controller_reconnect_guard.dart';
import 'package:project00/platform/home/gamelist/service/game_list_service.dart';
import 'package:project00/platform/home/room/models/room_player.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';
import 'package:project00/platform/home/room/services/controller_presence.dart';
import 'package:project00/platform/home/room/services/room_service.dart';

void main() {
  testWidgets('controller reconnect screen blocks game input until recovery', (
    tester,
  ) async {
    final service = _GuardRoomService();
    final provider =
        RoomProvider(service: service, gameService: _NoopGameService())
          ..roomCode = 'ABCDE'
          ..listenRoom();
    addTearDown(() async {
      provider.dispose();
      await service.dispose();
    });
    service.serverConnection.add(true);
    await tester.pump();
    provider.controllerPresenceState = ControllerPresenceState.reconnecting;
    var gameTaps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: ControllerReconnectGuard(
          provider: provider,
          onExit: () {},
          child: Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => gameTaps += 1,
                child: const Text('게임 입력'),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('태블릿에 다시 연결하는 중'), findsOneWidget);
    expect(find.textContaining('나가지 않고 재연결을 기다릴 수 있어요'), findsOneWidget);
    await tester.tap(find.text('게임 입력'), warnIfMissed: false);
    expect(gameTaps, 0);

    provider.controllerPresenceState = ControllerPresenceState.connected;
    provider.notifyListeners();
    await tester.pump();

    expect(find.text('태블릿에 다시 연결하는 중'), findsNothing);
    await tester.tap(find.text('게임 입력'));
    expect(gameTaps, 1);
  });

  testWidgets(
    'phone offline screen takes precedence over tablet reconnect screen',
    (tester) async {
      final service = _GuardRoomService();
      final provider =
          RoomProvider(service: service, gameService: _NoopGameService())
            ..roomCode = 'ABCDE'
            ..listenRoom()
            ..controllerPresenceState = ControllerPresenceState.reconnecting;
      addTearDown(() async {
        provider.dispose();
        await service.dispose();
      });
      service.serverConnection.add(false);

      await tester.pumpWidget(
        MaterialApp(
          home: ControllerReconnectGuard(
            provider: provider,
            onExit: () {},
            child: const Scaffold(body: SizedBox.expand()),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('태블릿에 다시 연결하는 중'), findsNothing);
    },
  );

  testWidgets(
    'authoritative waiting transition closes winner dialog and game route',
    (tester) async {
      final provider =
          RoomProvider(
              service: _GuardRoomService(),
              gameService: _NoopGameService(),
            )
            ..roomCode = 'ABCDE'
            ..selectedGameId = 'liars_poker'
            ..roomStatus = 'finished';
      addTearDown(provider.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              key: const Key('waiting-route'),
              body: TextButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => ControllerReconnectGuard(
                      provider: provider,
                      onExit: () {},
                      child: Builder(
                        builder: (gameContext) => Scaffold(
                          key: const Key('game-route'),
                          body: TextButton(
                            onPressed: () => showDialog<void>(
                              context: gameContext,
                              builder: (_) => const AlertDialog(
                                content: Text('winner-dialog'),
                              ),
                            ),
                            child: const Text('결과 열기'),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                child: const Text('게임 열기'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('게임 열기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('결과 열기'));
      await tester.pumpAndSettle();
      expect(find.text('winner-dialog'), findsOneWidget);

      provider
        ..roomStatus = 'waiting'
        ..selectedGameId = null
        ..notifyListeners();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('game-route')), findsNothing);
      expect(find.text('winner-dialog'), findsNothing);
      expect(find.byKey(const Key('waiting-route')), findsOneWidget);
    },
  );
}

class _GuardRoomService implements RoomService {
  final serverConnection = StreamController<bool>.broadcast();

  @override
  Stream<bool> watchServerConnection() => serverConnection.stream;

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

  Future<void> dispose() => serverConnection.close();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoopGameService implements GameService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
