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
    testWidgets('내보내기는 해당 참가자만 로딩하고 초기화를 실행하지 않는다', (tester) async {
      final removeCompleter = Completer<void>();
      final service = _FakeRoomService(removeCompleter: removeCompleter);
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

      await tester.tap(find.byTooltip('내보내기'));
      await tester.pump();

      expect(service.removeCalls, 1);
      expect(service.closeCalls, 0);
      expect(provider.isLoading, isFalse);
      expect(provider.isRemovingPlayer('player-1'), isTrue);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.tap(find.text('초기화'));
      await tester.pump();
      expect(service.closeCalls, 0);

      removeCompleter.complete();
      await tester.pumpAndSettle();
      expect(provider.isRemovingPlayer('player-1'), isFalse);
      provider.dispose();
    });

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

    testWidgets('구성원 참여 후 작은 QR을 누르면 중앙에 확대한다', (tester) async {
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

      await tester.tap(find.byKey(const Key('active-room-qr-expand')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('expanded-room-qr-dialog')), findsOneWidget);
      expect(find.text('참여 QR'), findsNothing);
      expect(find.text('ABCDE'), findsNWidgets(2));
      expect(
        tester.getSize(find.byKey(const Key('expanded-room-qr'))).width,
        greaterThan(92),
      );
      expect(service.createCalls, 0);
      expect(service.closeCalls, 0);

      await tester.tap(find.byTooltip('QR 확대 닫기'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('expanded-room-qr-dialog')), findsNothing);
      provider.dispose();
    });

    testWidgets('구성원이 없을 때 큰 초대 QR은 확대 버튼이 아니다', (tester) async {
      final provider = _provider(_FakeRoomService())..roomCode = 'ABCDE';
      await _pumpPanel(tester, provider);

      expect(find.byKey(const Key('active-room-qr-expand')), findsNothing);
      expect(find.byTooltip('QR 코드 확대'), findsNothing);
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
  _FakeRoomService({
    this.closeCompleter,
    this.removeCompleter,
    this.failFirstCreate = false,
  });

  final Completer<void>? closeCompleter;
  final Completer<void>? removeCompleter;
  final bool failFirstCreate;
  int closeCalls = 0;
  int removeCalls = 0;
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
  Future<void> removePlayer(String roomCode, String userUid) {
    removeCalls += 1;
    return removeCompleter?.future ?? Future<void>.value();
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
