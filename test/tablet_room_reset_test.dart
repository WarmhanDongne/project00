import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/platform/home/gamelist/service/game_list_service.dart';
import 'package:project00/platform/home/room/models/room_player.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';
import 'package:project00/platform/home/room/services/room_service.dart';
import 'package:project00/platform/home/tablet/widgets/tablet_room_panel.dart';

void main() {
  group('RoomProvider room command guard', () {
    test('초기화 연타는 현재 방을 한 번만 닫는다', () async {
      final closeCompleter = Completer<void>();
      final service = _FakeRoomService(closeCompleter: closeCompleter);
      final provider = _provider(service)..roomCode = 'ABCDE';

      final first = provider.closeRoom();
      final second = provider.closeRoom();

      expect(service.closeCalls, 1);
      expect(provider.isLoading, isTrue);

      closeCompleter.complete();
      await Future.wait([first, second]);

      expect(service.closeCalls, 1);
      expect(provider.roomCode, isNull);
      expect(provider.isLoading, isFalse);
      provider.dispose();
    });

    test('방이 있는 동안에는 새 초대 코드를 만들지 않는다', () async {
      final service = _FakeRoomService();
      final provider = _provider(service)..roomCode = 'ABCDE';

      await provider.createRoom();

      expect(service.createCalls, 0);
      expect(service.closeCalls, 0);
      expect(provider.roomCode, 'ABCDE');
      provider.dispose();
    });

    test('방 생성 재시도는 같은 작업 ID를 재사용한다', () async {
      final service = _FakeRoomService(failFirstCreate: true);
      final provider = _provider(service);

      await provider.createRoom();
      expect(provider.roomCode, isNull);
      await provider.createRoom();

      expect(service.createOperationIds, hasLength(2));
      expect(service.createOperationIds[0], isNotNull);
      expect(service.createOperationIds[1], service.createOperationIds[0]);
      expect(provider.roomCode, 'NEW12');
      provider.dispose();
    });

    test('이전 방의 늦은 정리 요청은 현재 방을 지우지 않는다', () {
      final provider = _provider(_FakeRoomService())..roomCode = 'NEW12';

      provider.clearRoom(expectedRoomCode: 'OLD12');

      expect(provider.roomCode, 'NEW12');
      provider.dispose();
    });
  });

  group('TabletRoomPanel Figma state flow', () {
    testWidgets('초대 모드 초기화는 구성원 없음으로 돌아간다', (tester) async {
      final service = _FakeRoomService();
      final provider = _provider(service)..roomCode = 'ABCDE';
      await _pumpPanel(tester, provider);

      expect(find.text('초대하기'), findsOneWidget);
      expect(find.text('초기화'), findsOneWidget);

      await tester.tap(find.text('초기화'));
      await tester.pump();

      expect(service.closeCalls, 1);
      expect(service.createCalls, 0);
      expect(find.text('구성원 목록'), findsOneWidget);
      expect(find.text('아직 아무도 없습니다'), findsOneWidget);
      provider.dispose();
    });

    testWidgets('구성원 참여 후 초기화도 새 방 없이 구성원 없음으로 돌아간다', (tester) async {
      final service = _FakeRoomService();
      final provider = _provider(service)
        ..roomCode = 'ABCDE'
        ..players = const [
          RoomPlayer(
            uid: 'player-1',
            nickname: '플레이어1',
            characterId: 'frog',
            isConnected: true,
            seatIndex: 0,
            role: 'player',
            status: 'active',
            penaltyAttemptCount: 0,
          ),
        ];
      await _pumpPanel(tester, provider);

      expect(find.text('현 인원  1명'), findsOneWidget);

      await tester.tap(find.text('초기화'));
      await tester.pump();

      expect(service.closeCalls, 1);
      expect(service.createCalls, 0);
      expect(provider.roomCode, isNull);
      expect(find.text('구성원 목록'), findsOneWidget);
      expect(find.text('아직 아무도 없습니다'), findsOneWidget);
      provider.dispose();
    });
  });
}

RoomProvider _provider(_FakeRoomService service) =>
    RoomProvider(service: service, gameService: _FakeGameService());

Future<void> _pumpPanel(WidgetTester tester, RoomProvider provider) {
  return tester.pumpWidget(
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
}

class _FakeRoomService implements RoomService {
  _FakeRoomService({this.closeCompleter, this.failFirstCreate = false});

  final Completer<void>? closeCompleter;
  final bool failFirstCreate;
  int closeCalls = 0;
  int createCalls = 0;
  final List<String?> createOperationIds = [];

  @override
  Future<void> closeControllerRoom(String roomCode) {
    closeCalls += 1;
    return closeCompleter?.future ?? Future<void>.value();
  }

  @override
  Future<String> createRoom({String? operationId}) async {
    createCalls += 1;
    createOperationIds.add(operationId);
    if (failFirstCreate && createCalls == 1) {
      throw StateError('response lost');
    }
    return 'NEW12';
  }

  @override
  Stream<DatabaseEvent> watchRoom(String roomCode) => const Stream.empty();

  @override
  Stream<List<RoomPlayer>> watchRoomPlayers(String roomCode) =>
      const Stream.empty();

  @override
  Stream<String?> watchRoomStatus(String roomCode) => const Stream.empty();

  @override
  Stream<bool> watchServerConnection() => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeGameService implements GameService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
