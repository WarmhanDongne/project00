import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:game_kit/widgets/game_exit_route.dart';
import 'package:project00/platform/home/gamelist/service/game_list_service.dart';
import 'package:project00/platform/home/room/models/room_player.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';
import 'package:project00/platform/home/room/services/controller_presence.dart';
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

    // [room create test]
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

    //[delete wrong room]
    test('이전 방의 늦은 정리 요청은 현재 방을 지우지 않는다', () {
      final provider = _provider(_FakeRoomService())..roomCode = 'NEW12';

      provider.clearRoom(expectedRoomCode: 'OLD12');

      expect(provider.roomCode, 'NEW12');
      provider.dispose();
    });
  });

  group('TabletRoomPanel Figma state flow', () {
    testWidgets('room primary action follows the selected game theme', (
      tester,
    ) async {
      final provider = _provider(_FakeRoomService());
      const firstBackground = Color(0xFFE9C44A);
      const firstForeground = Color(0xFF0E0A3D);
      const secondBackground = Color(0xFFE85D68);
      const secondForeground = Color(0xFFFFFFFF);

      await _pumpPanel(
        tester,
        provider,
        startBackground: firstBackground,
        startForeground: firstForeground,
      );
      MosiButton invite() => tester.widget<MosiButton>(
        find.byKey(const Key('room-invite-button')),
      );
      expect(invite().background, firstBackground);
      expect(invite().foreground, firstForeground);

      await _pumpPanel(
        tester,
        provider,
        startBackground: secondBackground,
        startForeground: secondForeground,
      );
      expect(invite().background, secondBackground);
      expect(invite().foreground, secondForeground);
      provider.dispose();
    });

    testWidgets('초대하기는 누르는 즉시 방 목록 전체를 덮고 서버가 응답하면 걷는다', (tester) async {
      final create = Completer<String>();
      final provider = _provider(_FakeRoomService(createCompleter: create));
      await _pumpPanel(
        tester,
        provider,
        coverGemColor: const Color(0xFF1F6E4A),
      );
      expect(find.byKey(const Key('room-panel-reveal')), findsNothing);

      await tester.tap(find.text('초대하기'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      // 응답이 없는 동안은 몇 초가 지나도 덮인 채로 있습니다.
      await tester.pump(const Duration(seconds: 3));
      final cover = find.byKey(const Key('room-panel-reveal'));
      expect(cover, findsOneWidget);
      // 덮개는 안쪽 여백까지 포함해 블록 전체 크기입니다.
      expect(tester.getSize(cover), tester.getSize(find.byType(MosiBox)));

      // 덮개는 흰 바탕이고, 마름모 색은 선택한 게임의 색을 따릅니다.
      final layer = tester.widget<GameExitPatternLayer>(
        find.byType(GameExitPatternLayer),
      );
      expect(layer.color, Colors.white);
      expect(layer.diamondColor, const Color(0xFF1F6E4A));

      create.complete('NEW12');
      await tester.pumpAndSettle();
      expect(provider.roomCode, 'NEW12');
      expect(cover, findsNothing);
      provider.dispose();
    });

    testWidgets('초기화도 응답이 올 때까지 덮여 있다가 응답이 오면 걷힌다', (tester) async {
      final close = Completer<void>();
      final provider = _provider(_FakeRoomService(closeCompleter: close))
        ..roomCode = 'ABCDE';
      await _pumpPanel(tester, provider);
      expect(find.byKey(const Key('room-panel-reveal')), findsNothing);

      await tester.tap(find.text('초기화'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(seconds: 3));
      expect(find.byKey(const Key('room-panel-reveal')), findsOneWidget);

      close.complete();
      await tester.pumpAndSettle();
      expect(provider.roomCode, isNull);
      expect(find.byKey(const Key('room-panel-reveal')), findsNothing);
      provider.dispose();
    });

    testWidgets('방 생성 실패는 빈 로비에 표시하고 재시도 성공 시 지운다', (tester) async {
      final service = _FakeRoomService(failFirstCreate: true);
      final provider = _provider(service);
      await _pumpPanel(tester, provider);
      await tester.tap(find.text('초대하기'));
      await tester.pumpAndSettle();
      expect(provider.roomCode, isNull);
      expect(find.byKey(const Key('room-create-error')), findsOneWidget);
      expect(find.text(provider.errorMessage!), findsOneWidget);
      await tester.tap(find.text('초대하기'));
      await tester.pumpAndSettle();
      expect(provider.roomCode, 'NEW12');
      expect(find.byKey(const Key('room-create-error')), findsNothing);
      expect(service.createOperationIds[1], service.createOperationIds[0]);
      provider.dispose();
    });

    testWidgets('연결이 끊긴 참가자만 명단에 상태를 표시한다', (tester) async {
      final service = _FakeRoomService();
      final provider = _provider(service)
        ..roomCode = 'ABCDE'
        ..players = const [
          RoomPlayer(
            uid: 'online-player',
            nickname: '대학원생',
            characterId: 'cat',
            isConnected: true,
            seatIndex: 1,
            role: 'player',
            status: 'active',
            penaltyAttemptCount: 0,
          ),
          RoomPlayer(
            uid: 'offline-player',
            nickname: '학부생',
            characterId: 'shark',
            isConnected: false,
            seatIndex: 0,
            role: 'player',
            status: 'active',
            penaltyAttemptCount: 0,
          ),
        ];

      await _pumpPanel(tester, provider);

      expect(find.text('학부생'), findsOneWidget);
      expect(find.text('연결 끊김'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('disconnected-player-offline-player')),
        findsOneWidget,
      );
      // 정상 연결 참가자에게는 준비 완료 같은 상태 알약을 붙이지 않습니다.
      expect(find.text('대학원생'), findsOneWidget);
      expect(find.text('준비 완료'), findsNothing);
      expect(
        find.byKey(const ValueKey('disconnected-player-online-player')),
        findsNothing,
      );
      provider.dispose();
    });

    testWidgets('연결 상태가 바뀌어도 내보내기 단추와 이름 자리는 그대로다', (tester) async {
      RoomPlayer player(bool connected) => RoomPlayer(
        uid: 'toggle-player',
        nickname: '긴닉네임플레이어',
        characterId: 'frog',
        isConnected: connected,
        seatIndex: 0,
        role: 'player',
        status: 'active',
        penaltyAttemptCount: 0,
      );
      final provider = _provider(_FakeRoomService())
        ..roomCode = 'ABCDE'
        ..players = [player(true)];
      await _pumpPanel(tester, provider);
      await tester.pumpAndSettle();
      final close = find.byTooltip('내보내기');
      final name = find.text('긴닉네임플레이어');
      final closeRect = tester.getRect(close);
      final nameLeft = tester.getRect(name).left;

      provider
        ..players = [player(false)]
        ..notifyListeners();
      await tester.pump();
      expect(find.text('연결 끊김'), findsOneWidget);
      expect(tester.getRect(close), closeRect);
      expect(tester.getRect(name).left, nameLeft);

      provider
        ..players = [player(true)]
        ..notifyListeners();
      await tester.pump();
      expect(find.text('연결 끊김'), findsNothing);
      expect(tester.getRect(close), closeRect);
      provider.dispose();
    });

    testWidgets('참가자는 오른쪽에서 들어오고 퇴장할 때 오른쪽으로 사라진다', (tester) async {
      final provider = _provider(_FakeRoomService())..roomCode = 'ABCDE';
      await _pumpPanel(tester, provider);

      provider.players = const [
        RoomPlayer(
          uid: 'animated-player',
          nickname: '애니메이션 플레이어',
          characterId: 'frog',
          isConnected: true,
          seatIndex: 0,
          role: 'player',
          status: 'active',
          penaltyAttemptCount: 0,
        ),
      ];
      provider.notifyListeners();
      await tester.pump();

      final motionFinder = find.byKey(
        const ValueKey('room-player-motion-animated-player'),
      );
      expect(find.text('애니메이션 플레이어'), findsOneWidget);
      expect(
        tester.widget<Transform>(motionFinder).transform.getTranslation().x,
        greaterThan(0),
      );

      // 들어오는 도중에는 오른쪽에서 왼쪽으로 계속 다가옵니다.
      await tester.pump(const Duration(milliseconds: 120));
      final midway = tester
          .widget<Transform>(motionFinder)
          .transform
          .getTranslation()
          .x;
      expect(midway, greaterThan(0));

      await tester.pump(_playerEntranceTestDuration);
      expect(
        tester.widget<Transform>(motionFinder).transform.getTranslation().x,
        0,
      );

      provider.players = const [];
      provider.notifyListeners();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 130));

      expect(find.text('애니메이션 플레이어'), findsOneWidget);
      expect(
        tester.widget<Transform>(motionFinder).transform.getTranslation().x,
        greaterThan(0),
      );
      expect(find.byKey(const Key('room-waiting-for-players')), findsNothing);

      await tester.pump(const Duration(milliseconds: 130));
      await tester.pump();
      expect(find.text('애니메이션 플레이어'), findsNothing);
      // 마지막 참가자가 나가면 QR 카드는 그대로 두고 '기다리는 중' 안내로 돌아갑니다.
      expect(find.byKey(const Key('room-waiting-for-players')), findsOneWidget);
      provider.dispose();
    });

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

      expect(find.byKey(const Key('room-waiting-for-players')), findsOneWidget);
      expect(find.text('초기화'), findsOneWidget);

      await tester.tap(find.text('초기화'));
      await tester.pump();

      expect(service.closeCalls, 1);
      expect(service.createCalls, 0);
      expect(find.text('구성원 목록'), findsOneWidget);
      expect(find.text('아직 아무도 없습니다'), findsOneWidget);
      expect(find.text('초대하기'), findsOneWidget);
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

      expect(find.text('1 / 12'), findsOneWidget);

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

    // 시안은 참가자 유무와 관계없이 같은 크기의 QR 하나를 둡니다. 그래서
    // 초대 상태에서도 QR을 눌러 크게 볼 수 있습니다.
    testWidgets('구성원이 없을 때도 초대 QR을 눌러 확대할 수 있다', (tester) async {
      final service = _FakeRoomService();
      final provider = _provider(service)..roomCode = 'ABCDE';
      await _pumpPanel(tester, provider);

      expect(find.byKey(const Key('active-room-qr-expand')), findsNothing);
      await tester.tap(find.byKey(const Key('invite-room-qr-expand')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('expanded-room-qr-dialog')), findsOneWidget);
      expect(service.createCalls, 0);
      expect(service.closeCalls, 0);
      provider.dispose();
    });
  });
}

const _playerEntranceTestDuration = Duration(milliseconds: 560);

RoomProvider _provider(_FakeRoomService service) =>
    RoomProvider(service: service, gameService: _FakeGameService());

Future<void> _pumpPanel(
  WidgetTester tester,
  RoomProvider provider, {
  Color coverGemColor = MosiColors.navy,
  Color startBackground = MosiColors.lime,
  Color startForeground = MosiColors.navy,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 310,
          height: 800,
          child: TabletRoomPanel(
            provider: provider,
            coverGemColor: coverGemColor,
            startBackground: startBackground,
            startForeground: startForeground,
          ),
        ),
      ),
    ),
  );
}

class _FakeRoomService implements RoomService {
  _FakeRoomService({
    this.closeCompleter,
    this.removeCompleter,
    this.createCompleter,
    this.failFirstCreate = false,
  });

  final Completer<void>? closeCompleter;
  final Completer<void>? removeCompleter;
  final Completer<String>? createCompleter;
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
    return createCompleter?.future ?? 'NEW12';
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
  Stream<ControllerPresence> watchControllerPresence(String roomCode) =>
      const Stream.empty();

  @override
  Stream<bool> watchRoomExists(String roomCode) => const Stream.empty();

  @override
  Stream<bool> watchServerConnection() => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeGameService implements GameService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
