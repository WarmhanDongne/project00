import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/platform/home/gamelist/service/game_list_service.dart';
import 'package:project00/platform/home/phone/screens/phone_room_waiting.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';
import 'package:project00/platform/home/room/services/player_room_session_store.dart';
import 'package:project00/platform/home/room/services/room_common.dart';
import 'package:project00/platform/home/room/services/room_leave_intent.dart';
import 'package:project00/platform/home/room/services/room_service.dart';
import 'package:project00/platform/theme/platform_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// C-04의 재현 시험입니다. 정상 퇴장 중에는 영문 원문이 화면에 나오지 않고,
/// 실제 실패일 때만 한국어 안내가 나와야 합니다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    RoomLeaveIntent.resetForTesting();
    await PlayerRoomSessionStore.instance.clear();
  });

  test('구독 권한이 사라진 오류는 배너에 남지 않는다', () async {
    final service = _CopyRoomService();
    final provider = _provider(service)..listenRoom();
    addTearDown(() async {
      provider.dispose();
      await service.dispose();
    });

    service.players.addError(
      FirebaseException(
        plugin: 'firebase_database',
        code: 'permission-denied',
        message: 'Client does not have permission to access the desired data.',
      ),
    );
    await _flushEvents();

    expect(provider.errorMessage, isNull);
  });

  test('퇴장 실패 문구에는 영어 원문이 들어가지 않는다', () async {
    final service = _CopyRoomService()
      ..leaveError = FirebaseFunctionsException(
        code: 'unavailable',
        message: 'The service is currently unavailable.',
      );
    final provider = _provider(service);
    addTearDown(() async {
      provider.dispose();
      await service.dispose();
    });

    expect(await provider.leaveRoom(), isFalse);
    final message = provider.errorMessage;
    expect(message, isNotNull);
    expect(message, isNot(matches(RegExp(r'[A-Za-z]{3,}'))));
    expect(message, contains('다시 시도'));
  });

  test('서버가 준 한국어 안내는 그대로 보여준다', () async {
    final service = _CopyRoomService()
      ..leaveError = FirebaseFunctionsException(
        code: 'failed-precondition',
        message: '게임 중에는 게임별 퇴장 기능을 사용해주세요.',
      );
    final provider = _provider(service);
    addTearDown(() async {
      provider.dispose();
      await service.dispose();
    });

    expect(await provider.leaveRoom(), isFalse);
    expect(provider.errorMessage, '게임 중에는 게임별 퇴장 기능을 사용해주세요.');
  });

  testWidgets('정상 퇴장으로 끝난 게임 상태 구독은 SnackBar를 띄우지 않는다', (tester) async {
    final service = _CopyRoomService();
    final provider = _provider(service);
    addTearDown(() async {
      provider.dispose();
      await service.dispose();
    });

    await _pumpWaiting(tester, provider);

    // 퇴장하면 game/public/status 읽기 권한이 사라져 이 구독이 끝납니다.
    service.gameStatus.addError(
      FirebaseException(
        plugin: 'firebase_database',
        code: 'permission-denied',
        message: 'Client does not have permission to access the desired data.',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(SnackBar), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('진짜 실패는 영어 없는 한국어 SnackBar로 알린다', (tester) async {
    final service = _CopyRoomService();
    final provider = _provider(service);
    addTearDown(() async {
      provider.dispose();
      await service.dispose();
    });

    await _pumpWaiting(tester, provider);

    service.gameStatus.addError(TimeoutException('no response'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(SnackBar), findsOneWidget);
    final text = tester.widget<Text>(
      find.descendant(of: find.byType(SnackBar), matching: find.byType(Text)),
    );
    expect(text.data, isNotNull);
    expect(text.data, isNot(matches(RegExp(r'[A-Za-z]{3,}'))));

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

RoomProvider _provider(_CopyRoomService service) => RoomProvider(
  service: service,
  gameService: _NoopGameService(),
  currentUidReader: () => 'me',
)..roomCode = 'ABCDE';

Future<void> _pumpWaiting(WidgetTester tester, RoomProvider provider) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: PlatformTheme.light(),
      home: PhoneRoomWaiting(
        provider: provider,
        // 실제 머리말은 Firebase 사용자를 읽으므로 시험에서는 자리만 둡니다.
        headerForTesting: const SizedBox(height: 72),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _flushEvents() async {
  for (var i = 0; i < 6; i += 1) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _CopyRoomService implements RoomService {
  final players = StreamController<List<RoomPlayer>>.broadcast();
  final gameStatus = StreamController<String?>.broadcast();

  Object? leaveError;

  @override
  Future<void> leaveRoom(String roomCode) async {
    final error = leaveError;
    if (error != null) throw error;
  }

  @override
  Future<bool> roomExists(String roomCode) async => true;

  @override
  Future<bool> hasActivePlayerNode(String roomCode) async => true;

  @override
  Future<void> heartbeatPlayer(String roomCode) async {}

  @override
  Stream<String?> watchGameStatus(String roomCode) => gameStatus.stream;

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
  Stream<List<RoomPlayer>> watchRoomPlayers(String roomCode) => players.stream;

  Future<void> dispose() async {
    await Future.wait([players.close(), gameStatus.close()]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoopGameService implements GameService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
