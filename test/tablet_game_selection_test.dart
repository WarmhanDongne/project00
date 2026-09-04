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
    // 제목 옆 개수 표시는 없앴습니다.
    expect(find.text('2'), findsNothing);
    roomProvider.dispose();
    gameProvider.dispose();
  });

  testWidgets('그룹 게임 갱신 중에 기존 카드를 유지하고 입력을 막는다', (
    tester,
  ) async {
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
    await tester.pumpAndSettle();

    roomProvider
      ..groupGames = const []
      ..groupGamesLoadStatus = RoomDataLoadStatus.loading
      ..notifyListeners();
    await tester.pump();

    expect(find.text('Final Call'), findsOneWidget);
    expect(
      find.byKey(const Key('game-list-refresh-indicator')),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);

    final inputGuard = tester.widget<IgnorePointer>(
      find.byKey(const Key('game-list-input-guard')),
    );
    expect(inputGuard.ignoring, isTrue);

    roomProvider
      ..groupGames = const [_paidGame]
      ..groupGamesLoadStatus = RoomDataLoadStatus.loaded
      ..notifyListeners();
    await tester.pumpAndSettle();

    expect(find.text('Final Call'), findsNothing);
    expect(find.text('유료 게임'), findsOneWidget);
    expect(
      find.byKey(const Key('game-list-refresh-indicator')),
      findsNothing,
    );
  });

  testWidgets('선택 해제에 실패하면 닫힌 뒤 오류를 알린다', (tester) async {
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
    // 닫기는 서버 응답을 기다리지 않으므로 모달은 이미 사라져 있습니다.
    expect(find.byType(Dialog), findsNothing);
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
    final provider =
        RoomProvider(service: service, gameService: _CatalogGameService())
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

  testWidgets('구성품 사진 주소가 있으면 그 사진을, 없으면 코드 그림을 쓴다', (tester) async {
    // 확정(2026-08): 구성품 그림은 Storage에 올리고 Firestore에 주소만 둡니다.
    // 앱 업데이트 없이 바꿀 수 있지만, 주소가 비었거나 내려받기가 실패하면
    // 모달이 비지 않게 코드 그림으로 되돌아갑니다.
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 768);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final provider = RoomProvider(
      service: _SelectionRoomService(),
      gameService: _CatalogGameService(),
    );
    addTearDown(provider.dispose);

    // 주소가 없으면 예전처럼 코드 그림입니다.
    await _pumpPreviewGame(tester, provider, _mafiaGame);
    expect(find.byKey(const Key('mafia-preview-artwork')), findsOneWidget);
    expect(find.byKey(const Key('game-component-artwork')), findsNothing);

    // 주소가 있으면 사진 자리를 잡습니다(내려받는 동안에는 코드 그림).
    await _pumpPreviewGame(tester, provider, _mafiaWithComponentImage);
    expect(find.byKey(const Key('game-component-artwork')), findsOneWidget);
    expect(tester.takeException(), isNull);
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

    final gameService = _CatalogGameService();
    final service = _SelectionRoomService();
    final roomProvider =
        RoomProvider(service: service, gameService: gameService)
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
    await tester.tap(find.byTooltip('닫기'), warnIfMissed: false);
    unawaited(tester.binding.handlePopRoute());
    await tester.pumpAndSettle();

    // 선택 해제는 한 번만, pop도 한 번만 일어납니다.
    expect(service.selectedGameIds, ['final_call', null]);
    expect(find.byType(Dialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('닫기는 선택 해제 응답을 기다리지 않는다', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 768);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final clearCompleter = Completer<void>();
    final gameService = _CatalogGameService();
    final service = _SelectionRoomService(clearCompleter: clearCompleter);
    final roomProvider =
        RoomProvider(service: service, gameService: gameService)
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

    // 해제 요청은 아직 서버에 머물러 있는데도 모달은 이미 닫혔습니다.
    expect(clearCompleter.isCompleted, isFalse);
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('Final Call'), findsOneWidget);

    clearCompleter.complete();
    await tester.pumpAndSettle();
    expect(service.selectedGameIds, ['final_call', null]);
  });

  testWidgets('닫고 바로 다른 게임을 고르면 새 선택을 해제하지 않는다', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 768);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final selectCompleter = Completer<void>();
    final gameService = _CatalogGameService();
    final service = _SelectionRoomService(selectCompleter: selectCompleter);
    final roomProvider =
        RoomProvider(service: service, gameService: gameService)
          ..roomCode = 'ABCDE'
          ..groupGamesLoadStatus = RoomDataLoadStatus.loaded
          ..groupGames = const [_game, _liarsPokerGame];
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

    // 첫 선택이 아직 서버에 머무는 사이에 닫고 다른 게임을 고릅니다.
    await tester.tap(find.text('Final Call'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('닫기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Liar's Poker"));
    await tester.pumpAndSettle();

    selectCompleter.complete();
    await tester.pumpAndSettle();

    // 뒤늦은 해제가 새 선택을 지우면 시작하기가 막힙니다.
    expect(service.selectedGameIds, ['final_call', 'liars_poker']);
    expect(find.byType(Dialog), findsOneWidget);
  });

  testWidgets('카드를 누르면 서버 응답을 기다리지 않고 미리보기가 열린다', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 768);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final selectCompleter = Completer<void>();
    final gameService = _CatalogGameService();
    final service = _SelectionRoomService(
      selectCompleter: selectCompleter,
      failOnBeginSeating: true,
    );
    final roomProvider =
        RoomProvider(service: service, gameService: gameService)
          ..roomCode = 'ABCDE'
          ..players = List.generate(2, _player)
          ..groupGamesLoadStatus = RoomDataLoadStatus.loaded
          ..groupGames = const [_liarsPokerGame];
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

    await tester.tap(find.text("Liar's Poker"));
    // 모달 전환만 진행시킵니다. 선택 요청은 아직 서버에 머물러 있습니다.
    await tester.pump(const Duration(milliseconds: 400));
    expect(selectCompleter.isCompleted, isFalse);
    expect(service.selectedGameIds, ['liars_poker']);
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('시작하기'), findsOneWidget);

    // 응답보다 먼저 시작하기를 눌러도 선택이 끝난 뒤에 자리 배치를 요청합니다.
    await tester.tap(find.text('시작하기'));
    await tester.pump();
    expect(service.beginSeatingCalls, 0);

    selectCompleter.complete();
    await tester.pumpAndSettle();
    expect(service.beginSeatingCalls, 1);
  });

  testWidgets('선택이 실패하면 닫을 때 해제를 호출하지 않는다', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 768);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final gameService = _CatalogGameService();
    final service = _SelectionRoomService(failOnSelect: true);
    final roomProvider =
        RoomProvider(service: service, gameService: gameService)
          ..roomCode = 'ABCDE'
          ..players = List.generate(2, _player)
          ..groupGamesLoadStatus = RoomDataLoadStatus.loaded
          ..groupGames = const [_liarsPokerGame];
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

    await tester.tap(find.text("Liar's Poker"));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);

    await tester.tap(find.byTooltip('닫기'));
    await tester.pumpAndSettle();

    // 서버에 선택이 남지 않았으므로 해제(null)를 보내지 않습니다.
    expect(service.selectedGameIds, ['liars_poker']);
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('보유한 게임에 없는 장르 칩은 보이지 않는다', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 768);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final gameService = _CatalogGameService();
    final roomProvider =
        RoomProvider(service: _SelectionRoomService(), gameService: gameService)
          ..roomCode = 'ABCDE'
          ..groupGamesLoadStatus = RoomDataLoadStatus.loaded
          // 전략(Final Call) + 추리(마피아)만 보유한 상태입니다.
          ..groupGames = const [_game, _mafiaGame];
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

    expect(find.widgetWithText(ChoiceChip, '전체'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, '전략'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, '추리'), findsOneWidget);
    for (final missing in ['재미', '액션', '심리', '수학', '공간', '협동']) {
      expect(find.widgetWithText(ChoiceChip, missing), findsNothing);
    }

    // 영문 장르 코드도 한글 칩으로 맞춥니다(psychology, cooperative).
    roomProvider.groupGames = const [_longGame];
    roomProvider.notifyListeners();
    await tester.pump();
    expect(find.widgetWithText(ChoiceChip, '심리'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, '협동'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, '전략'), findsNothing);
  });

  testWidgets('고른 장르가 사라지면 전체로 돌아간다', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 768);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final gameService = _CatalogGameService();
    final roomProvider =
        RoomProvider(service: _SelectionRoomService(), gameService: gameService)
          ..roomCode = 'ABCDE'
          ..groupGamesLoadStatus = RoomDataLoadStatus.loaded
          ..groupGames = const [_game, _mafiaGame];
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

    await tester.tap(find.widgetWithText(ChoiceChip, '추리'));
    await tester.pump();
    expect(find.text('Final Call'), findsNothing);
    expect(find.text('마피아'), findsOneWidget);

    // 추리 게임이 빠지면 빈 목록에 갇히지 않고 전체가 다시 보입니다.
    roomProvider.groupGames = const [_game];
    roomProvider.notifyListeners();
    await tester.pump();
    expect(find.widgetWithText(ChoiceChip, '추리'), findsNothing);
    expect(find.text('Final Call'), findsOneWidget);
    expect(find.text('조건에 맞는 게임이 없습니다.'), findsNothing);
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

/// 구성품 사진 주소가 있는 게임입니다(Storage + Firestore 경로 시험용).
const _mafiaWithComponentImage = GameInfo(
  id: 'mafia',
  name: '마피아',
  description: '정체를 숨기고 토론하는 추리 게임입니다.',
  imageUrl: '',
  componentImageUrl: 'https://example.com/mafia_components.png',
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
    this.failOnSelect = false,
    this.clearCompleter,
    this.selectCompleter,
  });

  final bool failOnClear;
  final bool failOnBeginSeating;
  final bool failOnSelect;
  final Completer<void>? clearCompleter;
  final Completer<void>? selectCompleter;
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
    if (gameId != null && selectCompleter != null) {
      await selectCompleter!.future;
    }
    if (failOnClear && gameId == null) {
      throw const RoomCommandException('게임 선택을 해제하지 못했습니다.');
    }
    if (failOnSelect && gameId != null) {
      throw const RoomCommandException('게임을 선택하지 못했습니다.');
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
