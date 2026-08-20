import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/platform/home/gamelist/models/game_info.dart';
import 'package:project00/platform/home/gamelist/provider/game_list_provider.dart';
import 'package:project00/platform/home/gamelist/service/game_list_service.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';
import 'package:project00/platform/home/room/services/room_common.dart';
import 'package:project00/platform/home/room/services/room_service.dart';
import 'package:project00/platform/home/tablet/widgets/tablet_game_list.dart';
import 'package:project00/platform/theme/platform_theme.dart';

void main() {
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
}

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

class _SelectionRoomService implements RoomService {
  _SelectionRoomService({this.failOnClear = false});

  final bool failOnClear;
  final List<String?> selectedGameIds = [];

  @override
  Future<void> selectGame({
    required String roomCode,
    required String? gameId,
  }) async {
    selectedGameIds.add(gameId);
    if (failOnClear && gameId == null) {
      throw const RoomCommandException('게임 선택을 해제하지 못했습니다.');
    }
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
