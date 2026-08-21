import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/games/shared/player_layouts/player_layout_editor.dart';
import 'package:project00/platform/home/gamelist/models/game_info.dart';
import 'package:project00/platform/home/gamelist/provider/game_list_provider.dart';
import 'package:project00/platform/home/gamelist/service/game_list_service.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';
import 'package:project00/platform/home/room/services/room_common.dart';
import 'package:project00/platform/home/room/services/room_service.dart';
import 'package:project00/platform/home/tablet/widgets/tablet_game_list.dart';
import 'package:project00/platform/home/tablet/widgets/tablet_game_preview_modal.dart';
import 'package:project00/platform/theme/platform_theme.dart';
import 'package:project00/platform/widgets/platform_components.dart';

void main() {
  test('태블릿 설명을 역직렬화하고 값이 없으면 휴대폰 설명으로 대체한다', () {
    final withTabletDescription = GameInfo.fromJson({
      'id': 'game',
      'name': '게임',
      'description': '휴대폰 설명',
      'tabletDescription': '태블릿 상세 설명',
    });
    final fallback = GameInfo.fromJson({
      'id': 'game',
      'name': '게임',
      'description': '휴대폰 설명',
    });

    expect(withTabletDescription.description, '휴대폰 설명');
    expect(withTabletDescription.effectiveTabletDescription, '태블릿 상세 설명');
    expect(fallback.effectiveTabletDescription, '휴대폰 설명');
  });

  test('기본 최대 인원은 12명이다', () {
    expect(RoomLimits.defaultMaxPlayers, 12);
  });

  testWidgets('카드 탭은 선택을 저장한 뒤 모달을 열고 닫을 때 해제한다', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 768);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final roomService = _SelectionRoomService();
    final gameService = _CatalogGameService();
    final roomProvider =
        RoomProvider(service: roomService, gameService: gameService)
          ..roomCode = 'ABCDE'
          ..groupGamesLoadStatus = RoomDataLoadStatus.loaded
          ..groupGames = const [_game];
    final gameProvider = GameProvider(service: gameService);

    await tester.pumpWidget(
      MaterialApp(
        theme: PlatformTheme.light(),
        home: Scaffold(
          body: GameList(
            gameProvider: gameProvider,
            roomProvider: roomProvider,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('그룹이 보유 중인 게임'), findsOneWidget);
    await tester.tap(find.text('Final Call'));
    await tester.pumpAndSettle();

    expect(roomService.selectedGameIds, ['final_call']);
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('시작하기'), findsOneWidget);

    await tester.tap(find.byTooltip('닫기'));
    await tester.pumpAndSettle();

    expect(roomService.selectedGameIds, ['final_call', null]);
    expect(find.byType(Dialog), findsNothing);

    roomProvider.groupGames = const [_game, _paidGame];
    roomProvider.notifyListeners();
    await tester.pump();
    expect(find.text('유료 게임'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    roomProvider.dispose();
    gameProvider.dispose();
  });

  testWidgets('선택 해제에 실패하면 모달을 유지하고 오류를 표시한다', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 768);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final roomService = _SelectionRoomService(failOnClear: true);
    final gameService = _CatalogGameService();
    final roomProvider =
        RoomProvider(service: roomService, gameService: gameService)
          ..roomCode = 'ABCDE'
          ..groupGamesLoadStatus = RoomDataLoadStatus.loaded
          ..groupGames = const [_game];
    final gameProvider = GameProvider(service: gameService);
    addTearDown(roomProvider.dispose);
    addTearDown(gameProvider.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: PlatformTheme.light(),
        home: Scaffold(
          body: GameList(
            gameProvider: gameProvider,
            roomProvider: roomProvider,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Final Call'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('닫기'));
    await tester.pumpAndSettle();

    expect(roomService.selectedGameIds, ['final_call', null]);
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('게임 선택을 해제하지 못했습니다.'), findsOneWidget);
  });

  testWidgets('iPad 크기와 큰 글자에서도 게임 카드가 넘치지 않는다', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final gameService = _CatalogGameService();
    final roomProvider =
        RoomProvider(service: _SelectionRoomService(), gameService: gameService)
          ..roomCode = 'ABCDE'
          ..groupGamesLoadStatus = RoomDataLoadStatus.loaded
          ..groupGames = const [_longGame];
    final gameProvider = GameProvider(service: gameService);
    addTearDown(roomProvider.dispose);
    addTearDown(gameProvider.dispose);

    for (final textScale in const [1.0, 1.3, 2.0]) {
      for (final size in const [
        Size(1024, 768),
        Size(1133, 744),
        Size(1180, 820),
        Size(1194, 834),
      ]) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          MaterialApp(
            theme: PlatformTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
            home: Scaffold(
              body: GameList(
                gameProvider: gameProvider,
                roomProvider: roomProvider,
              ),
            ),
          ),
        );
        await tester.pump();

        expect(
          tester.takeException(),
          isNull,
          reason: 'iPad size: $size, text scale: $textScale',
        );
        expect(find.text(_longGame.name), findsOneWidget);
      }
    }
  });

  testWidgets('고정 인원 게임은 불일치 안내만 부드러운 문구로 표시한다', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 768);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final matchingProvider = RoomProvider(
      service: _SelectionRoomService(),
      gameService: _CatalogGameService(),
    )..players = List.generate(4, _player);
    addTearDown(matchingProvider.dispose);
    await _pumpPreview(tester, matchingProvider);
    expect(find.byType(PlatformNotice), findsNothing);
    expect(tester.takeException(), isNull);

    final warningProvider = RoomProvider(
      service: _SelectionRoomService(),
      gameService: _CatalogGameService(),
    )..players = List.generate(3, _player);
    addTearDown(warningProvider.dispose);
    await _pumpPreview(tester, warningProvider);
    expect(
      find.text('이 게임은 4명이 모이면 시작할 수 있어요. 현재 3명이 참여 중입니다.'),
      findsOneWidget,
    );
    await tester.tap(find.text('시작하기'));
    await tester.pump();
    expect(find.byType(PlayerLayoutEditor), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('일반 게임은 최소 인원 미달 안내를 표시한다', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 768);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final provider = RoomProvider(
      service: _SelectionRoomService(),
      gameService: _CatalogGameService(),
    )..players = List.generate(1, _player);
    addTearDown(provider.dispose);

    await _pumpPreviewGame(tester, provider, _liarsPokerGame);
    expect(
      find.text('이 게임은 최소 2명부터 시작할 수 있어요. 현재 1명이 참여 중입니다.'),
      findsOneWidget,
    );
    await tester.tap(find.text('시작하기'));
    await tester.pump();
    expect(find.byType(PlayerLayoutEditor), findsNothing);
  });

  testWidgets('서버의 자리 배치 잠금이 실패하면 편집 화면을 열지 않는다', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 768);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final service = _SelectionRoomService(failOnBeginSeating: true);
    final provider = RoomProvider(
      service: service,
      gameService: _CatalogGameService(),
    )
      ..roomCode = 'ABCDE'
      ..players = List.generate(2, _player);
    addTearDown(provider.dispose);

    await _pumpPreviewGame(tester, provider, _liarsPokerGame);
    await tester.tap(find.text('시작하기'));
    await tester.pumpAndSettle();

    expect(service.beginSeatingCalls, 1);
    expect(find.byType(PlayerLayoutEditor), findsNothing);
    expect(find.text('자리 배치를 시작하지 못했습니다.'), findsOneWidget);
  });

  testWidgets('등록 게임은 구성 요소 미리보기를, 미등록 게임은 대체 패널을 표시한다', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 768);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final provider = RoomProvider(
      service: _SelectionRoomService(),
      gameService: _CatalogGameService(),
    );
    addTearDown(provider.dispose);

    for (final entry in const [
      (_liarsPokerGame, 'liars-poker-preview-artwork'),
      (_game, 'final-call-preview-artwork'),
      (_mafiaGame, 'mafia-preview-artwork'),
    ]) {
      await _pumpPreviewGame(tester, provider, entry.$1);
      expect(find.byKey(Key(entry.$2)), findsOneWidget);
      expect(tester.takeException(), isNull);
    }

    await _pumpPreviewGame(tester, provider, _longGame);
    expect(
      find.byKey(const Key('unknown-game-preview-artwork')),
      findsOneWidget,
    );
    expect(find.text('게임 구성 요소를 준비 중입니다.'), findsOneWidget);
  });

  testWidgets('maxPlayers가 0이면 12명까지 허용하고 13명부터 시작을 차단한다', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 768);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final provider =
        RoomProvider(
            service: _SelectionRoomService(),
            gameService: _CatalogGameService(),
          )
          ..roomCode = 'ABCDE'
          ..players = List.generate(12, _player);
    addTearDown(provider.dispose);
    await _pumpPreviewGame(tester, provider, _mafiaWithoutMaxPlayers);
    expect(find.byType(PlatformNotice), findsNothing);

    provider.players = List.generate(13, _player);
    provider.notifyListeners();
    await tester.pump();
    await tester.tap(find.text('시작하기'));
    await tester.pump();
    expect(
      find.text('이 게임은 최대 12명까지 함께할 수 있어요. 현재 13명이 참여 중입니다.'),
      findsOneWidget,
    );
    expect(find.byType(PlayerLayoutEditor), findsNothing);
  });

  testWidgets('X 연타와 뒤로 가기가 겹쳐도 선택 해제와 pop은 한 번만 실행된다', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 768);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final clearCompleter = Completer<void>();
    final service = _SelectionRoomService(clearCompleter: clearCompleter);
    final provider = RoomProvider(
      service: service,
      gameService: _CatalogGameService(),
    )..roomCode = 'ABCDE';
    addTearDown(provider.dispose);

    await _pumpDialogRoute(tester, provider, selectionActive: true);
    await tester.tap(find.byTooltip('닫기'));
    await tester.tap(find.byTooltip('닫기'), warnIfMissed: false);
    unawaited(tester.binding.handlePopRoute());
    await tester.pump();
    expect(service.selectedGameIds, [null]);

    clearCompleter.complete();
    await tester.pumpAndSettle();
    expect(service.selectedGameIds, [null]);
    expect(find.byType(Dialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('방이 없는 모달도 X로 한 번만 닫힌다', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 768);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final service = _SelectionRoomService();
    final provider = RoomProvider(
      service: service,
      gameService: _CatalogGameService(),
    );
    addTearDown(provider.dispose);

    await _pumpDialogRoute(tester, provider);
    await tester.tap(find.byTooltip('닫기'));
    await tester.pumpAndSettle();
    expect(service.selectedGameIds, isEmpty);
    expect(find.byType(Dialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('선택 해제 대기 중 부모가 제거돼도 비동기 응답이 상태를 다시 쓰지 않는다', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 768);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final clearCompleter = Completer<void>();
    final provider = RoomProvider(
      service: _SelectionRoomService(clearCompleter: clearCompleter),
      gameService: _CatalogGameService(),
    )..roomCode = 'ABCDE';
    addTearDown(provider.dispose);

    await _pumpDialogRoute(tester, provider, selectionActive: true);
    await tester.tap(find.byTooltip('닫기'));
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    clearCompleter.complete();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpPreview(WidgetTester tester, RoomProvider provider) {
  return _pumpPreviewGame(tester, provider, _game);
}

Future<void> _pumpPreviewGame(
  WidgetTester tester,
  RoomProvider provider,
  GameInfo game,
) {
  return tester.pumpWidget(
    MaterialApp(
      theme: PlatformTheme.light(),
      home: Scaffold(
        body: GamePreviewDialog(game: game, roomProvider: provider),
      ),
    ),
  );
}

Future<void> _pumpDialogRoute(
  WidgetTester tester,
  RoomProvider provider, {
  bool selectionActive = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: PlatformTheme.light(),
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (_) => GamePreviewDialog(
              game: _game,
              roomProvider: provider,
              selectionActive: selectionActive,
            ),
          ),
          child: const Text('열기'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('열기'));
  await tester.pumpAndSettle();
}

RoomPlayer _player(int index) => RoomPlayer(
  uid: 'player-$index',
  nickname: '플레이어$index',
  characterId: 'frog',
  isConnected: true,
  seatIndex: index,
  role: 'player',
  status: 'active',
  penaltyAttemptCount: 0,
);

const _game = GameInfo(
  id: 'final_call',
  name: 'Final Call',
  description: '팀을 이뤄 점수를 겨루는 카드 게임입니다.',
  rules: '규칙',
  imageUrl: '',
  enabled: true,
  genres: ['전략'],
  minPlayers: 4,
  maxPlayers: 4,
  playTime: 30,
  order: 1,
  ruleVideoUrl: '',
  isOwned: true,
);

const _liarsPokerGame = GameInfo(
  id: 'liars_poker',
  name: "Liar's Poker",
  description: '거짓말을 간파하는 카드 게임입니다.',
  imageUrl: '',
  enabled: true,
  genres: ['심리'],
  minPlayers: 2,
  maxPlayers: 6,
  playTime: 25,
  order: 1,
  ruleVideoUrl: '',
  isOwned: true,
);

const _mafiaGame = GameInfo(
  id: 'mafia',
  name: '마피아',
  description: '정체를 숨기고 토론하는 추리 게임입니다.',
  imageUrl: '',
  enabled: true,
  genres: ['추리'],
  minPlayers: 4,
  maxPlayers: 12,
  playTime: 30,
  order: 1,
  ruleVideoUrl: '',
  isOwned: true,
);

const _mafiaWithoutMaxPlayers = GameInfo(
  id: 'mafia',
  name: '마피아',
  description: '정체를 숨기고 토론하는 추리 게임입니다.',
  imageUrl: '',
  enabled: true,
  genres: ['추리'],
  minPlayers: 4,
  maxPlayers: 0,
  playTime: 30,
  order: 1,
  ruleVideoUrl: '',
  isOwned: true,
);

const _paidGame = GameInfo(
  id: 'paid_game',
  name: '유료 게임',
  description: '그룹원이 보유한 게임입니다.',
  imageUrl: '',
  enabled: true,
  genres: ['전략'],
  minPlayers: 2,
  maxPlayers: 6,
  playTime: 20,
  order: 2,
  ruleVideoUrl: '',
  isOwned: true,
  accessType: GameAccessType.paid,
);

const _longGame = GameInfo(
  id: 'long_game',
  name: '아주 긴 이름을 가진 태블릿 게임 카드',
  description: '태블릿 카드 오버플로를 검증하는 게임입니다.',
  imageUrl: '',
  enabled: true,
  genres: ['psychology', 'cooperative'],
  minPlayers: 10,
  maxPlayers: 12,
  playTime: 120,
  order: 3,
  ruleVideoUrl: '',
  isOwned: true,
);

class _SelectionRoomService implements RoomService {
  _SelectionRoomService({
    this.failOnClear = false,
    this.failOnBeginSeating = false,
    this.clearCompleter,
  });

  final bool failOnClear;
  final bool failOnBeginSeating;
  final Completer<void>? clearCompleter;
  final List<String?> selectedGameIds = [];
  int beginSeatingCalls = 0;

  @override
  Future<void> selectGame({
    required String roomCode,
    required String? gameId,
  }) async {
    selectedGameIds.add(gameId);
    if (gameId == null && clearCompleter != null) {
      await clearCompleter!.future;
    }
    if (failOnClear && gameId == null) {
      throw const RoomCommandException('게임 선택을 해제하지 못했습니다.');
    }
  }

  @override
  Future<List<RoomPlayer>> beginPlayerSeating(String roomCode) async {
    beginSeatingCalls += 1;
    if (failOnBeginSeating) {
      throw const RoomCommandException('자리 배치를 시작하지 못했습니다.');
    }
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CatalogGameService implements GameService {
  @override
  Future<List<GameInfo>> fetchGames() async => const [_game];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
