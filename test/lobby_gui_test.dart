import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:game_kit/template_game.dart';
import 'package:game_kit/player_layouts/player_layout_model.dart';
import 'package:project00/platform/home/tablet/tablet_game_launcher.dart';
import 'package:game_kit/mosi_ui/mosi_game_art.dart';
import 'package:project00/platform/home/gamelist/models/game_info.dart';
import 'package:project00/platform/home/gamelist/provider/game_list_provider.dart';
import 'package:project00/platform/home/gamelist/service/game_list_service.dart';
import 'package:project00/platform/home/phone/widgets/lobby_reconnect_guard.dart';
import 'package:project00/platform/home/room/models/room_player.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';
import 'package:project00/platform/home/room/services/room_service.dart';
import 'package:project00/platform/home/tablet/screens/tablet_game_detail.dart';
import 'package:project00/platform/home/tablet/tablet_lobby_selection.dart';
import 'package:project00/platform/home/tablet/widgets/tablet_game_shelf.dart';
import 'package:project00/platform/home/tablet/widgets/tablet_lobby_layout.dart';
import 'package:project00/platform/home/tablet/widgets/tablet_room_panel.dart';

final _game = GameInfo.fromJson({
  'id': 'liars_poker',
  'name': '라이어스 포커',
  'description': '함께 즐기는 카드 게임',
  'minPlayers': 2,
  'maxPlayers': 6,
  'playTime': 15,
});
final _other = GameInfo.fromJson({'id': 'mafia', 'name': '마피아'});
const _players = [
  RoomPlayer(
    uid: 'one',
    nickname: '친구1',
    characterId: 'burger',
    seatIndex: 0,
    isConnected: true,
    role: 'player',
    status: 'active',
    penaltyAttemptCount: 0,
  ),
  RoomPlayer(
    uid: 'two',
    nickname: '친구2',
    characterId: 'cone',
    seatIndex: 1,
    isConnected: true,
    role: 'player',
    status: 'active',
    penaltyAttemptCount: 0,
  ),
];

void main() {
  group('게임 선택과 방 수명', () {
    late _RoomService service;
    late _RoomProvider provider;
    late TabletLobbySelection selection;
    setUp(() {
      service = _RoomService();
      provider = _RoomProvider(service);
      selection = TabletLobbySelection(provider);
    });
    tearDown(() {
      selection.dispose();
      provider.dispose();
    });

    test('상세를 먼저 열고 방을 만들거나 다시 만들면 그 방에 게임을 선택한다', () async {
      selection.show(_game);
      expect(service.commands, isEmpty);
      provider.roomCode = 'FIRST';
      provider.notifyListeners();
      expect(await selection.prepare(), isTrue);
      provider.roomCode = null;
      provider.notifyListeners();
      provider.roomCode = 'NEXT1';
      provider.notifyListeners();
      expect(await selection.prepare(), isTrue);
      expect(service.commands, ['FIRST:liars_poker', 'NEXT1:liars_poker']);
    });

    test('선택 응답 전에 닫아도 선택 완료 뒤 해제한다', () async {
      provider.roomCode = 'FIRST';
      service.selectionWait = Completer<void>();
      selection.show(_game);
      await Future<void>.delayed(Duration.zero);
      final closed = selection.close();
      expect(service.commands, ['FIRST:liars_poker']);
      service.selectionWait!.complete();
      expect(await closed, isTrue);
      expect(service.commands, ['FIRST:liars_poker', 'FIRST:null']);
    });

    test('빠르게 닫고 다른 게임을 열어도 최신 선택을 지우지 않는다', () async {
      provider.roomCode = 'FIRST';
      service.selectionWait = Completer<void>();
      selection.show(_game);
      await Future<void>.delayed(Duration.zero);
      final closed = selection.close();
      selection.show(_other);
      service.selectionWait!.complete();
      await closed;
      expect(await selection.prepare(), isTrue);
      expect(service.commands, ['FIRST:liars_poker', 'FIRST:mafia']);
    });

    test('방이 바뀌면 이전 방 선택 성공을 새 방 시작에 사용하지 않는다', () async {
      provider.roomCode = 'FIRST';
      service.selectionWait = Completer<void>();
      selection.show(_game);
      final prepared = selection.prepare();
      await Future<void>.delayed(Duration.zero);
      provider.roomCode = 'NEXT1';
      provider.notifyListeners();
      service.selectionWait!.complete();
      expect(await prepared, isFalse);
      expect(await selection.prepare(), isTrue);
      expect(service.commands.last, 'NEXT1:liars_poker');
    });

    test('자리 배치 진입 후에는 선택을 해제하거나 다시 보내지 않는다', () async {
      provider.roomCode = 'FIRST';
      selection.show(_game);
      await selection.prepare();
      selection.didLaunch();
      provider.notifyListeners();
      await Future<void>.delayed(Duration.zero);
      expect(service.commands, ['FIRST:liars_poker']);
    });
  });

  testWidgets('선택 응답을 기다린 뒤 자리 배치를 열고 로비 route는 유지한다', (tester) async {
    final service = _RoomService()..selectionWait = Completer<void>();
    final provider = _RoomProvider(service)
      ..roomCode = 'FIRST'
      ..players = _players;
    final selection = TabletLobbySelection(provider);
    addTearDown(provider.dispose);
    addTearDown(selection.dispose);
    var launched = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () {
                selection.show(_game);
                unawaited(
                  launchTabletGame(
                    context: context,
                    game: _game,
                    provider: provider,
                    ensureSelection: selection.prepare,
                    isCurrent: () => context.mounted,
                    onLaunched: () {
                      launched = true;
                      selection.didLaunch();
                    },
                  ),
                );
              },
              child: const Text('로비 시작'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('로비 시작'));
    await tester.pump();
    expect(service.commands, ['FIRST:liars_poker']);
    expect(launched, isFalse);
    service.selectionWait!.complete();
    await tester.pumpAndSettle();
    expect(service.commands, ['FIRST:liars_poker', 'FIRST:seating']);
    expect(launched, isTrue);
    expect(find.text('자리 배치'), findsOneWidget);
    final context = tester.element(find.text('자리 배치'));
    Navigator.of(context).pop();
    await tester.pumpAndSettle();
    expect(find.text('로비 시작'), findsOneWidget);
  });

  testWidgets('활성 버튼은 접근성 실행을 지원하고 로딩 버튼은 실행하지 않는다', (tester) async {
    final semantics = tester.ensureSemantics();
    var calls = 0;
    Future<void> pump(bool loading) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MosiButton(
            label: '시작',
            loading: loading,
            onPressed: () => calls++,
          ),
        ),
      ),
    );
    await pump(false);
    var node = tester.getSemantics(find.byType(MosiButton));
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    tester
        .renderObject(find.byType(MosiButton))
        .owner!
        .semanticsOwner!
        .performAction(node.id, SemanticsAction.tap);
    expect(calls, 1);
    await pump(true);
    node = tester.getSemantics(find.byType(MosiButton));
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
    semantics.dispose();
  });

  for (final size in [
    const Size(800, 600),
    const Size(1024, 768),
    const Size(1194, 834),
    const Size(600, 900),
  ]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('로비 $size 글자 $scale에서 선반·상세가 넘치지 않고 방 패널을 유지한다', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final provider = _RoomProvider(_RoomService())
          ..roomCode = 'ABCDE'
          ..players = _players
          ..groupGames = [_game, _other]
          ..groupGamesLoadStatus = RoomDataLoadStatus.loaded;
        final games = GameProvider(service: _GameService())
          ..games = [_game, _other];
        addTearDown(provider.dispose);
        addTearDown(games.dispose);
        final oldError = FlutterError.onError;
        FlutterError.onError = (error) {
          FlutterError.dumpErrorToConsole(error);
          oldError!(error);
        };
        addTearDown(() => FlutterError.onError = oldError);
        var detail = false;
        late StateSetter change;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.linear(scale),
              ),
              child: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    change = setState;
                    return TabletLobbyLayout(
                      header: const SizedBox(height: 48),
                      content: detail
                          ? TabletGameDetailContent(
                              game: _game,
                              roomProvider: provider,
                            )
                          : TabletGameShelf(
                              gameProvider: games,
                              roomProvider: provider,
                              selectedGameId: _game.id,
                              onSelect: (_) {},
                              onOpenDetail: (_) =>
                                  setState(() => detail = true),
                              theme: MosiGameArt.liarsPoker.shelfTheme,
                              onlyPlayable: false,
                              onOnlyPlayableChanged: (_) {},
                            ),
                      roomPanel: TabletRoomPanel(
                        provider: provider,
                        onStart: () {},
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        final state = tester.state(find.byType(TabletRoomPanel));
        await tester.tap(find.byKey(const Key('shelf-selected-cover')));
        await tester.pump();
        expect(find.byType(TabletGameDetailContent), findsOneWidget);
        expect(tester.state(find.byType(TabletRoomPanel)), same(state));
        expect(tester.takeException(), isNull);
        change(() => detail = false);
        await tester.pump();
        expect(tester.state(find.byType(TabletRoomPanel)), same(state));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  testWidgets('시작 처리 중에도 방 버튼의 위치와 로딩 표시를 유지한다', (tester) async {
    final provider = _RoomProvider(_RoomService())
      ..roomCode = 'ABCDE'
      ..players = _players;
    addTearDown(provider.dispose);
    Future<void> pump(bool loading) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 372,
            child: TabletRoomPanel(
              provider: provider,
              startLoading: loading,
              onStart: () {},
            ),
          ),
        ),
      ),
    );
    await pump(false);
    final button = find.byKey(const Key('room-start-button'));
    final position = tester.getTopLeft(button);
    await pump(true);
    expect(tester.getTopLeft(button), position);
    expect(
      find.descendant(
        of: button,
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
  });

  testWidgets('자리 대기 단절 모달은 복구 시 닫히며 실패한 퇴장은 재시도할 수 있다', (tester) async {
    final provider = _RoomProvider(_RoomService())
      ..roomCode = 'ABCDE'
      ..roomStatus = 'seating'
      ..controllerPresenceState = ControllerPresenceState.reconnecting;
    addTearDown(provider.dispose);
    final exit = Completer<bool>();
    var exits = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LobbyReconnectGuard(
            provider: provider,
            onExit: () {
              exits++;
              return exit.future;
            },
            child: const Text('자리 배치 대기'),
          ),
        ),
      ),
    );
    expect(find.text('태블릿에 다시 연결하는 중'), findsOneWidget);
    expect(find.byKey(const Key('lobby-reconnect-barrier')), findsOneWidget);
    await tester.tap(find.text('그룹 나가고 홈으로'));
    await tester.pump();
    expect(exits, 1);
    expect(tester.widget<MosiButton>(find.byType(MosiButton)).loading, isTrue);
    exit.complete(false);
    await tester.pump();
    expect(find.text('그룹을 나가지 못했어요. 다시 시도해 주세요.'), findsOneWidget);
    provider.controllerPresenceState = ControllerPresenceState.connected;
    provider.notifyListeners();
    await tester.pump();
    expect(find.text('태블릿에 다시 연결하는 중'), findsNothing);
    expect(find.text('자리 배치 대기'), findsOneWidget);
    provider.controllerPresenceState = ControllerPresenceState.reconnecting;
    provider.connected = false;
    provider.notifyListeners();
    await tester.pump();
    expect(find.text('태블릿에 다시 연결하는 중'), findsNothing);
  });
}

class _RoomProvider extends RoomProvider {
  _RoomProvider(_RoomService service)
    : super(
        service: service,
        gameService: _GameService(),
        gameCatalog: _Catalog(),
      );
  bool connected = true;
  @override
  bool get isServerConnected => connected;
}

class _RoomService implements RoomService {
  final commands = <String>[];
  Completer<void>? selectionWait;
  @override
  Future<void> selectGame({required String roomCode, String? gameId}) async {
    commands.add('$roomCode:$gameId');
    if (gameId != null) await selectionWait?.future;
  }

  @override
  Future<List<RoomPlayer>> beginPlayerSeating(String roomCode) async {
    commands.add('$roomCode:seating');
    return _players;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _GameService implements GameService {
  @override
  Future<List<GameInfo>> fetchGames() async => [_game, _other];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Catalog implements GameCatalog {
  @override
  Iterable<TemplateGame> get games => [const _TestGame()];
  @override
  TemplateGame? find(String id) =>
      id == 'liars_poker' ? const _TestGame() : null;
}

class _TestGame extends TemplateGame {
  const _TestGame();
  @override
  String get id => 'liars_poker';
  @override
  Widget? buildStartSetupScreen({
    required PlayerLayoutModel layout,
    required Future<bool> Function(
      PlayerLayoutModel, {
      Map<String, Object?>? options,
    })
    onPrepare,
    required void Function(PlayerLayoutModel) onComplete,
    required Future<bool> Function() onCancel,
  }) => const Scaffold(body: Text('자리 배치'));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
