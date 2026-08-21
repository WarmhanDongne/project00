import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/platform/home/phone/widgets/controller_reconnect_guard.dart';
import 'package:project00/platform/home/gamelist/service/game_list_service.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';
import 'package:project00/platform/home/room/services/room_service.dart';

void main() {
  testWidgets('controller reconnect screen blocks game input until recovery', (
    tester,
  ) async {
    final provider = RoomProvider(
      service: _NoopRoomService(),
      gameService: _NoopGameService(),
    )..controllerPresenceState = ControllerPresenceState.reconnecting;
    addTearDown(provider.dispose);
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
    await tester.tap(find.text('게임 입력'), warnIfMissed: false);
    expect(gameTaps, 0);

    provider.controllerPresenceState = ControllerPresenceState.connected;
    provider.notifyListeners();
    await tester.pump();

    expect(find.text('태블릿에 다시 연결하는 중'), findsNothing);
    await tester.tap(find.text('게임 입력'));
    expect(gameTaps, 1);
  });
}

class _NoopRoomService implements RoomService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoopGameService implements GameService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
