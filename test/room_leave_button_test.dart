import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/platform/home/gamelist/service/game_list_service.dart';
import 'package:project00/platform/home/phone/widgets/phone_room_leave_button.dart';
import 'package:project00/platform/home/room/models/room_player.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';
import 'package:project00/platform/home/room/services/player_room_session_store.dart';
import 'package:project00/platform/home/room/services/room_leave_intent.dart';
import 'package:project00/platform/home/room/services/room_service.dart';
import 'package:project00/platform/theme/platform_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    RoomLeaveIntent.resetForTesting();
    await PlayerRoomSessionStore.instance.clear();
  });

  testWidgets('퇴장이 진행되는 동안 그룹 나가기 버튼이 잠긴다', (tester) async {
    final service = _GatedLeaveService();
    final provider = _provider(service);
    addTearDown(() async {
      provider.dispose();
      await service.dispose();
    });

    await _pump(tester, provider);
    expect(_button(tester).onPressed, isNotNull);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.byType(PhoneRoomLeaveButton));
    await tester.pump();

    expect(service.leaveCalls, 1);
    expect(_button(tester).onPressed, isNull, reason: '진행 중에는 다시 누를 수 없어야 합니다');
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    service.gate.complete();
    await tester.pumpAndSettle();
    expect(service.leaveCalls, 1);
  });

  testWidgets('빠른 두 번 탭이 퇴장 요청을 두 번 보내지 않는다', (tester) async {
    final service = _GatedLeaveService();
    final provider = _provider(service);
    addTearDown(() async {
      provider.dispose();
      await service.dispose();
    });

    await _pump(tester, provider);
    // 프레임 사이에 두 번 눌러 버튼 잠금이 반영되기 전 상황을 만듭니다.
    await tester.tap(find.byType(PhoneRoomLeaveButton));
    await tester.tap(find.byType(PhoneRoomLeaveButton));
    await tester.pump();

    expect(service.leaveCalls, 1);

    service.gate.complete();
    await tester.pumpAndSettle();
    expect(service.leaveCalls, 1);
    expect(provider.roomCode, isNull);
    expect(provider.errorMessage, isNull);
  });

  testWidgets('퇴장이 실패하면 버튼이 다시 활성화된다', (tester) async {
    final service = _GatedLeaveService()..failure = StateError('네트워크 오류');
    final provider = _provider(service);
    addTearDown(() async {
      provider.dispose();
      await service.dispose();
    });

    await _pump(tester, provider);
    await tester.tap(find.byType(PhoneRoomLeaveButton));
    service.gate.complete();
    await tester.pumpAndSettle();

    expect(_button(tester).onPressed, isNotNull);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(provider.errorMessage, isNotNull);

    // 같은 버튼으로 바로 다시 시도할 수 있어야 합니다.
    service
      ..failure = null
      ..gate = Completer<void>()
      ..gate.complete();
    await tester.tap(find.byType(PhoneRoomLeaveButton));
    await tester.pumpAndSettle();
    expect(service.leaveCalls, 2);
    expect(provider.roomCode, isNull);
  });
}

RoomProvider _provider(_GatedLeaveService service) => RoomProvider(
  service: service,
  gameService: _NoopGameService(),
  currentUidReader: () => 'me',
)..roomCode = 'ABCDE';

FilledButton _button(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byType(FilledButton));

Future<void> _pump(WidgetTester tester, RoomProvider provider) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: PlatformTheme.light(),
      home: Scaffold(
        body: PhoneRoomLeaveButton(
          provider: provider,
          onPressed: () => provider.leaveRoom(),
        ),
      ),
    ),
  );
}

class _GatedLeaveService implements RoomService {
  Completer<void> gate = Completer<void>();
  Object? failure;
  int leaveCalls = 0;

  @override
  Future<void> leaveRoom(String roomCode) async {
    leaveCalls += 1;
    await gate.future;
    final error = failure;
    if (error != null) throw error;
  }

  @override
  Future<bool> roomExists(String roomCode) async => true;

  @override
  Future<bool> hasActivePlayerNode(String roomCode) async => true;

  @override
  Future<void> heartbeatPlayer(String roomCode) async {}

  @override
  Stream<bool> watchServerConnection() => const Stream.empty();

  @override
  Stream<bool?> watchControllerConnected(String roomCode) =>
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

  Future<void> dispose() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoopGameService implements GameService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
