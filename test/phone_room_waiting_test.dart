import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/platform/home/gamelist/models/game_info.dart';
import 'package:project00/platform/home/gamelist/service/game_list_service.dart';
import 'package:project00/platform/home/phone/screens/phone_room_waiting.dart';
import 'package:project00/platform/home/room/models/room_player.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';
import 'package:project00/platform/home/room/services/controller_presence.dart';
import 'package:project00/platform/home/room/services/room_service.dart';
import 'package:project00/platform/theme/platform_theme.dart';

void main() {
  group('GameInfo rules', () {
    test('parses multiline rules without changing line breaks', () {
      final game = GameInfo.fromJson({
        'id': 'mafia',
        'name': '마피아',
        'rules': '첫 줄\n\n둘째 줄',
      });

      expect(game.rules, '첫 줄\n\n둘째 줄');
    });

    test('uses an empty string when legacy documents have no rules', () {
      expect(GameInfo.fromJson(const {}).rules, isEmpty);
    });

    test('treats legacy games as free and parses paid access', () {
      expect(GameInfo.fromJson(const {}).isFree, isTrue);
      final paid = GameInfo.fromJson(const {
        'accessType': 'paid',
        'isOwned': false,
      });
      expect(paid.accessType, GameAccessType.paid);
      expect(paid.isAccessible, isFalse);
    });
  });

  group('RoomProvider group games', () {
    test('exposes failure and succeeds when the user retries', () async {
      final gameService = _RetryGameService();
      final provider =
          RoomProvider(service: _FakeRoomService(), gameService: gameService)
            ..roomCode = 'ABCDE'
            ..players = const [_player];

      await provider.retryGroupGames();
      expect(provider.groupGamesLoadStatus, RoomDataLoadStatus.failure);
      expect(provider.groupGames, isEmpty);

      await provider.retryGroupGames();
      expect(provider.groupGamesLoadStatus, RoomDataLoadStatus.loaded);
      expect(provider.groupGames.single.id, 'liars_poker');
      expect(gameService.calls, 2);
      provider.dispose();
    });

    test('discards a result that arrives after the room was cleared', () async {
      final gameService = _DelayedGameService();
      final provider =
          RoomProvider(service: _FakeRoomService(), gameService: gameService)
            ..roomCode = 'OLD12'
            ..players = const [_player];

      final refresh = provider.retryGroupGames();
      provider.clearRoom();
      gameService.complete([_game('final_call', 'Final Call')]);
      await refresh;

      expect(provider.groupGames, isEmpty);
      expect(provider.groupGamesLoadStatus, RoomDataLoadStatus.idle);
      provider.dispose();
    });

    test('clears the server selection with a null game id', () async {
      final roomService = _FakeRoomService();
      final provider = RoomProvider(
        service: roomService,
        gameService: _StaticGameService(),
      )..roomCode = 'ABCDE';

      expect(await provider.clearSelectedGame(), isTrue);
      expect(roomService.selectedGameIds, [null]);
      provider.dispose();
    });
  });

  group('PhoneRoomWaiting Figma states', () {
    testWidgets('controller reconnecting shows a non-blocking waiting banner', (
      tester,
    ) async {
      final provider = _provider()
        ..roomCode = 'ABCDE'
        ..listenRoom()
        ..controllerPresenceState = ControllerPresenceState.reconnecting;

      await _pumpWaiting(tester, provider);

      expect(find.text('태블릿 재접속 대기 중'), findsOneWidget);
      provider.dispose();
    });

    testWidgets('closed room exits even when another route covers waiting', (
      tester,
    ) async {
      final provider = _provider()..roomCode = 'ABCDE';

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              key: const Key('phone-home-root'),
              body: TextButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => PhoneRoomWaiting(
                      provider: provider,
                      headerForTesting: const SizedBox(height: 72),
                    ),
                  ),
                ),
                child: const Text('대기실 열기'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('대기실 열기'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      final waitingContext = tester.element(find.byType(PhoneRoomWaiting));
      unawaited(
        Navigator.of(waitingContext).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(
              key: Key('fake-game-route'),
              body: SizedBox.expand(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byKey(const Key('fake-game-route')), findsOneWidget);

      provider.wasRoomClosed = true;
      provider.roomTerminationReason = RoomTerminationReason.closed;
      provider.clearRoom(preserveTerminationReason: true);
      await tester.pump();
      // popUntil은 위의 게임 라우트와 대기실 라우트를 차례로 닫으므로 두 번의
      // 기본 MaterialPageRoute 역전환 시간을 모두 진행시킵니다.
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.byKey(const Key('phone-home-root')), findsOneWidget);
      expect(find.byType(PhoneRoomWaiting), findsNothing);
      expect(provider.wasRoomClosed, isFalse);
      expect(provider.roomTerminationReason, isNull);
      provider.dispose();
    });

    //=======================게임 종료 후 대기실 복귀 (P-02)==============================
    // 게임 종료 경로 어디에도 selectedGame을 지우는 코드가 없다. 방이
    // status = finished + selectedGame 잔류 상태로 남아 룰북과 `곧 시작합니다`가
    // 영원히 표시됐고, 신규 참가(decideRoomJoin)와 재접속
    // (isRestorablePlayerSessionState)이 모두 막혔다.

    testWidgets('게임이 끝나면 룰북 대신 대기실로 돌아온다', (tester) async {
      final provider = _provider()
        ..roomCode = 'ABCDE'
        ..selectedGameId = 'liars_poker'
        ..selectedGame = _game('liars_poker', '라이어스 포커', rules: '규칙')
        ..selectedGameLoadStatus = RoomDataLoadStatus.loaded
        ..roomStatus = 'finished';

      await _pumpWaiting(tester, provider);

      expect(find.text('그룹이 선택한 게임'), findsNothing);
      expect(find.text('곧 시작합니다'), findsNothing);
      expect(find.text('그룹이 보유 중인 게임'), findsOneWidget);
      provider.dispose();
    });

    testWidgets('아직 진행 중이면 선택 게임 화면을 유지한다', (tester) async {
      final provider = _provider()
        ..roomCode = 'ABCDE'
        ..selectedGameId = 'liars_poker'
        ..selectedGame = _game('liars_poker', '라이어스 포커', rules: '규칙')
        ..selectedGameLoadStatus = RoomDataLoadStatus.loaded
        ..roomStatus = 'seating';

      await _pumpWaiting(tester, provider);

      expect(find.text('그룹이 선택한 게임'), findsOneWidget);
      expect(find.text('곧 시작합니다'), findsOneWidget);
      provider.dispose();
    });

    testWidgets('종료된 방에서는 다음 게임을 기다린다고 알린다', (tester) async {
      final provider = _provider()
        ..roomCode = 'ABCDE'
        ..roomStatus = 'finished';

      await _pumpWaiting(tester, provider);

      expect(find.text('게임이 끝났습니다. 태블릿에서 다음 게임을 고르는 중입니다'), findsOneWidget);
      provider.dispose();
    });

    testWidgets('시스템 뒤로가기로는 방을 벗어나지 않는다', (tester) async {
      // 뒤로가기로 화면만 닫히면 사용자는 로비에 있는데 서버에는 참가자로
      // 남는다. 그 뒤 홈의 저장 세션 복원이 대기 화면을 다시 띄운다.
      final provider = _provider()..roomCode = 'ABCDE';

      await tester.pumpWidget(
        MaterialApp(
          theme: PlatformTheme.light(),
          home: Builder(
            builder: (context) => Scaffold(
              key: const Key('lobby-root'),
              body: TextButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => PhoneRoomWaiting(
                      provider: provider,
                      headerForTesting: const SizedBox(height: 72),
                    ),
                  ),
                ),
                child: const Text('대기실 열기'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('대기실 열기'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(PhoneRoomWaiting), findsOneWidget);

      final waitingContext = tester.element(find.byType(PhoneRoomWaiting));
      await Navigator.of(waitingContext).maybePop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(
        find.byType(PhoneRoomWaiting),
        findsOneWidget,
        reason: '방에 남아야 합니다',
      );
      expect(find.textContaining('나가기를 눌러주세요'), findsOneWidget);
      provider.dispose();
    });

    testWidgets('739 shows all owned games without a read-only badge', (
      tester,
    ) async {
      final provider = _provider()
        ..roomCode = 'ABCDE'
        ..players = const [_player]
        ..groupGamesLoadStatus = RoomDataLoadStatus.loaded
        ..groupGames = [
          _game('mafia', '마피아'),
          _game('liars_poker', '라이어스 포커'),
          _game('final_call', 'Final Call'),
        ];

      await _pumpWaiting(tester, provider);

      expect(find.text('태블릿에서 게임을 선택하는 중입니다'), findsOneWidget);
      // 휴대폰에서는 보기 전용 배지를 쓰지 않습니다.
      expect(find.text('보기 전용'), findsNothing);
      expect(find.text('마피아'), findsOneWidget);
      expect(find.text('라이어스 포커'), findsOneWidget);
      expect(find.text('Final Call'), findsOneWidget);
      expect(find.text('참여 코드'), findsNothing);
      expect(
        find.ancestor(of: find.text('마피아'), matching: find.byType(InkWell)),
        findsNothing,
      );
      expect(find.text('곧 시작합니다'), findsNothing);
      provider.dispose();
    });

    testWidgets('740 replaces lobby content with selected game details', (
      tester,
    ) async {
      final provider = _provider()
        ..roomCode = 'ABCDE'
        ..players = const [_player]
        ..selectedGameId = 'final_call'
        ..selectedGameLoadStatus = RoomDataLoadStatus.loaded
        ..selectedGame = _game(
          'final_call',
          'Final Call',
          rules: '[게임 목표]\n- 상대 팀을 이기세요.',
        );

      await _pumpWaiting(tester, provider);

      expect(find.text('Final Call'), findsOneWidget);
      expect(find.text('그룹이 선택한 게임'), findsOneWidget);
      expect(find.text('게임 규칙'), findsOneWidget);
      expect(find.textContaining('[게임 목표]'), findsOneWidget);
      expect(find.text('곧 시작합니다'), findsOneWidget);
      expect(find.text('참여 코드'), findsNothing);
      expect(find.text('참여자'), findsNothing);
      expect(find.text('보기 전용'), findsNothing);
      provider.dispose();
    });

    testWidgets('740 explains when rules are not registered yet', (
      tester,
    ) async {
      final provider = _provider()
        ..roomCode = 'ABCDE'
        ..selectedGameId = 'mafia'
        ..selectedGameLoadStatus = RoomDataLoadStatus.loaded
        ..selectedGame = _game('mafia', '마피아');

      await _pumpWaiting(tester, provider);

      expect(find.text('게임 규칙을 준비 중입니다.'), findsOneWidget);
      provider.dispose();
    });

    testWidgets('740 does not overflow on a narrow phone', (tester) async {
      final provider = _provider()
        ..roomCode = 'ABCDE'
        ..selectedGameId = 'final_call'
        ..selectedGameLoadStatus = RoomDataLoadStatus.loaded
        ..selectedGame = _game('final_call', 'Final Call', rules: '첫 줄\n둘째 줄');

      await _pumpWaiting(tester, provider, size: const Size(320, 700));

      expect(find.text('그룹이 선택한 게임'), findsOneWidget);
      expect(tester.takeException(), isNull);
      provider.dispose();
    });

    testWidgets('작은 화면과 큰 글자에서도 대기 화면이 넘치지 않는다', (tester) async {
      final provider = _provider()
        ..roomCode = 'ABCDE'
        ..players = const [_player]
        ..groupGamesLoadStatus = RoomDataLoadStatus.loaded
        ..groupGames = [
          _game('mafia', '마피아'),
          _game('final_call', 'Final Call'),
        ];

      await _pumpWaiting(
        tester,
        provider,
        size: const Size(320, 640),
        textScale: 3,
      );

      expect(find.text('그룹이 보유 중인 게임'), findsOneWidget);
      expect(tester.takeException(), isNull);
      provider.dispose();
    });

    testWidgets('곧 시작합니다 줄도 큰 글자에서 넘치지 않는다', (tester) async {
      final provider = _provider()
        ..roomCode = 'ABCDE'
        ..selectedGameId = 'final_call'
        ..selectedGameLoadStatus = RoomDataLoadStatus.loaded
        ..selectedGame = _game('final_call', 'Final Call', rules: '첫 줄');

      await _pumpWaiting(
        tester,
        provider,
        size: const Size(320, 640),
        textScale: 3,
      );

      expect(find.text('곧 시작합니다'), findsOneWidget);
      expect(tester.takeException(), isNull);
      provider.dispose();
    });

    testWidgets('waiting indicator advances from left to center to right', (
      tester,
    ) async {
      final provider = _provider()
        ..roomCode = 'ABCDE'
        ..groupGamesLoadStatus = RoomDataLoadStatus.loaded;
      await _pumpWaiting(tester, provider);

      expect(_activeDot(tester), 0);
      await tester.pump(const Duration(milliseconds: 310));
      expect(_activeDot(tester), 1);
      await tester.pump(const Duration(milliseconds: 300));
      expect(_activeDot(tester), 2);

      await tester.pumpWidget(const SizedBox.shrink());
      provider.dispose();
    });
  });
}

const _player = RoomPlayer(
  uid: 'player-1',
  nickname: '플레이어',
  characterId: 'frog',
  isConnected: true,
  seatIndex: 0,
  role: 'player',
  status: 'active',
  penaltyAttemptCount: 0,
);

RoomProvider _provider() => RoomProvider(
  service: _FakeRoomService(),
  gameService: _StaticGameService(),
);

GameInfo _game(String id, String name, {String rules = ''}) => GameInfo(
  id: id,
  name: name,
  description: '$name 설명',
  rules: rules,
  imageUrl: '',
  enabled: true,
  genres: const ['전략', '추리'],
  minPlayers: 4,
  maxPlayers: 8,
  playTime: 20,
  order: 1,
  ruleVideoUrl: '',
  isOwned: true,
);

Future<void> _pumpWaiting(
  WidgetTester tester,
  RoomProvider provider, {
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      theme: PlatformTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: PhoneRoomWaiting(
        provider: provider,
        // 실제 머리말은 Firebase 사용자를 읽으므로 시험에서는 자리만 둡니다.
        headerForTesting: const SizedBox(height: 72),
      ),
    ),
  );
}

int _activeDot(WidgetTester tester) {
  final primary = PlatformColors.light.primary;
  for (var index = 0; index < 3; index += 1) {
    final container = tester.widget<Container>(
      find.byKey(ValueKey('waiting-dot-$index')),
    );
    final decoration = container.decoration! as BoxDecoration;
    if (decoration.color == primary) return index;
  }
  return -1;
}

class _FakeRoomService implements RoomService {
  final List<String?> selectedGameIds = [];

  @override
  Future<void> selectGame({
    required String roomCode,
    required String? gameId,
  }) async {
    selectedGameIds.add(gameId);
  }

  @override
  Stream<String?> watchGameStatus(String roomCode) => const Stream.empty();

  @override
  Stream<bool> watchServerConnection() => Stream.value(true);

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

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StaticGameService implements GameService {
  @override
  Future<List<GameInfo>> fetchGroupGames(List<String> uids) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RetryGameService implements GameService {
  int calls = 0;

  @override
  Future<List<GameInfo>> fetchGroupGames(List<String> uids) async {
    calls += 1;
    if (calls == 1) throw StateError('temporary failure');
    return [_game('liars_poker', '라이어스 포커')];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DelayedGameService implements GameService {
  final _completer = Completer<List<GameInfo>>();

  void complete(List<GameInfo> games) => _completer.complete(games);

  @override
  Future<List<GameInfo>> fetchGroupGames(List<String> uids) =>
      _completer.future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
