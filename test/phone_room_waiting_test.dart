import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/platform/home/gamelist/models/game_info.dart';
import 'package:project00/platform/home/gamelist/service/game_list_service.dart';
import 'package:project00/platform/home/phone/screens/phone_room_waiting.dart';
import 'package:project00/platform/home/room/models/room_player.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';
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
  });

  group('PhoneRoomWaiting Figma states', () {
    testWidgets('739 shows all owned games and the read-only badge', (
      tester,
    ) async {
      final provider = _provider()
        ..roomCode = 'ABCDE'
        ..players = const [_player]
        ..groupGamesLoadStatus = RoomDataLoadStatus.loaded
        ..groupGames = [_game('mafia', '마피아'), _game('liars_poker', '라이어스 포커')];

      await _pumpWaiting(tester, provider);

      expect(find.text('태블릿에서 게임을 선택하는 중입니다'), findsOneWidget);
      expect(find.text('보기 전용'), findsOneWidget);
      expect(find.text('마피아'), findsOneWidget);
      expect(find.text('라이어스 포커'), findsOneWidget);
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

Future<void> _pumpWaiting(WidgetTester tester, RoomProvider provider) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      theme: PlatformTheme.light(),
      home: PhoneRoomWaiting(
        provider: provider,
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
  @override
  Stream<String?> watchGameStatus(String roomCode) => const Stream.empty();

  @override
  Stream<bool> watchServerConnection() => const Stream.empty();

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
