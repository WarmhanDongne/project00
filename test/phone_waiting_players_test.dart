import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:project00/platform/home/phone/widgets/phone_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:game_kit/mosi_ui/mosi_game_art.dart';
import 'package:project00/platform/home/gamelist/models/game_info.dart';
import 'package:project00/platform/home/gamelist/service/game_list_service.dart';
import 'package:project00/platform/home/phone/screens/phone_room_waiting.dart';
import 'package:project00/platform/home/room/models/room_player.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';
import 'package:project00/platform/home/room/services/room_service.dart';
import 'package:project00/platform/theme/platform_theme.dart';

class _Rooms extends Fake implements RoomService {
  @override
  Stream<bool> watchServerConnection() =>
      Stream.multi((sink) => sink.add(true));
  @override
  Stream<String?> watchGameStatus(String roomCode) => const Stream.empty();
}

class _Games extends Fake implements GameService {}

RoomPlayer _player(
  int index, {
  bool connected = true,
  String role = 'player',
  String status = 'active',
}) => RoomPlayer(
  uid: 'player-$index',
  nickname: '친구$index',
  characterId: 'frog',
  isConnected: connected,
  seatIndex: index,
  role: role,
  status: status,
  penaltyAttemptCount: 0,
);
RoomProvider _provider() =>
    RoomProvider(service: _Rooms(), gameService: _Games())
      ..roomCode = 'ABCDE'
      ..roomStatus = 'waiting'
      ..selectedGameId = 'holdem'
      ..selectedGame = GameInfo.fromJson({
        'id': 'holdem',
        'name': '홀덤',
        'description': '게임 설명',
        'rules': '게임 규칙',
      })
      ..selectedGameLoadStatus = RoomDataLoadStatus.loaded;

Widget _app(RoomProvider provider) => MaterialApp(
  theme: PlatformTheme.light(),
  home: PhoneRoomWaiting(
    provider: provider,
    headerForTesting: const SizedBox(height: 72),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestFirebaseCoreHostApi.setUp(MockFirebaseApp());
  setUpAll(() async => Firebase.initializeApp());

  for (final gameId in ['liars_poker', 'final_call', 'mafia', 'holdem']) {
    testWidgets('$gameId 자리 배치 대기는 테이블 면 색을 공유하고 자리 찾기·상단 프로필을 숨긴다', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final provider = _provider()
        ..roomStatus = 'seating'
        ..selectedGameId = gameId
        ..selectedGame = GameInfo.fromJson({'id': gameId, 'name': gameId});
      await tester.pumpWidget(
        MaterialApp(
          theme: PlatformTheme.light(),
          home: PhoneRoomWaiting(provider: provider),
        ),
      );
      await tester.pump();
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        MosiSeatTheme.of(gameId).table,
      );
      expect(find.text('태블릿에서 내 자리 찾기'), findsNothing);
      expect(find.byType(PhoneProfile), findsNothing);
      expect(find.text('그룹 나가기'), findsOneWidget);
      expect(find.text('ABCDE'), findsOneWidget);
      expect(find.byType(MosiFace), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      provider.dispose();
    });
  }

  testWidgets('선택 전후 대기실에서 상단 프로필만 제거하고 방 코드·나가기를 유지한다', (tester) async {
    final provider = _provider()
      ..groupGamesLoadStatus = RoomDataLoadStatus.loaded;
    await tester.pumpWidget(
      MaterialApp(
        theme: PlatformTheme.light(),
        home: PhoneRoomWaiting(provider: provider),
      ),
    );
    await tester.pump();
    expect(find.byType(PhoneProfile), findsNothing);
    expect(find.text('ABCDE'), findsOneWidget);
    provider
      ..selectedGameId = null
      ..selectedGame = null;
    provider.notifyListeners();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(PhoneProfile), findsNothing);
    expect(find.text('그룹 나가기'), findsOneWidget);
    expect(find.text('ABCDE'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    provider.dispose();
  });

  testWidgets('대기→소개는 헤더를 유지하며 배경과 본문을 점진적으로 바꾼다', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final provider = _provider();
    final game = provider.selectedGame!;
    provider
      ..selectedGame = null
      ..selectedGameId = null
      ..selectedGameLoadStatus = RoomDataLoadStatus.idle
      ..groupGames = [game]
      ..groupGamesLoadStatus = RoomDataLoadStatus.loaded;
    await tester.pumpWidget(_app(provider));
    // 대기 안내 점은 계속 움직이므로 전환 시간만 진행합니다.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final header = find.byWidgetPredicate(
      (widget) => widget is SizedBox && widget.height == 72,
    );
    final headerElement = tester.element(header);
    final headerBounds = tester.getRect(header);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      MosiColors.violet,
    );
    provider
      ..selectedGameId = 'holdem'
      ..selectedGameLoadStatus = RoomDataLoadStatus.loading;
    provider.notifyListeners();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('phone-group-waiting')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('phone-game-details-holdem')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('phone-game-loading-holdem')),
      findsNothing,
    );
    final midColor = tester
        .widget<Scaffold>(find.byType(Scaffold))
        .backgroundColor;
    expect(midColor, isNot(MosiColors.violet));
    expect(midColor, isNot(MosiGameArt.holdem.shelfTheme.ground));
    expect(tester.element(header), same(headerElement));
    expect(tester.getRect(header), headerBounds);
    final enteringFade = find
        .ancestor(
          of: find.byKey(const ValueKey('phone-selected-game')),
          matching: find.byType(FadeTransition),
        )
        .first;
    expect(
      tester.widget<FadeTransition>(enteringFade).opacity.value,
      inExclusiveRange(0, 1),
    );
    provider.selectedGame = game;
    provider.selectedGameLoadStatus = RoomDataLoadStatus.loaded;
    provider.notifyListeners();
    // 대기 안내 점은 계속 움직이므로 전환 시간만 진행합니다.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('phone-group-waiting')), findsNothing);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      MosiGameArt.holdem.shelfTheme.ground,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    provider.dispose();
  });

  testWidgets('늦게 받은 설명과 빠른 선택 해제도 부드럽게 바뀌며 지난 내용이 남지 않는다', (tester) async {
    final provider = _provider()
      ..selectedGame = null
      ..selectedGameLoadStatus = RoomDataLoadStatus.loading;
    await tester.pumpWidget(_app(provider));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('phone-game-loading-holdem')),
      findsOneWidget,
    );
    provider
      ..selectedGame = GameInfo.fromJson({
        'id': 'holdem',
        'name': '홀덤',
        'rules': '규칙',
      })
      ..selectedGameLoadStatus = RoomDataLoadStatus.loaded;
    provider.notifyListeners();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.byKey(const ValueKey('phone-game-loading-holdem')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('phone-game-details-holdem')),
      findsOneWidget,
    );
    provider
      ..selectedGameId = 'mafia'
      ..selectedGame = GameInfo.fromJson({'id': 'mafia', 'name': '마피아'});
    provider.notifyListeners();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    provider
      ..selectedGameId = null
      ..selectedGame = null
      ..groupGamesLoadStatus = RoomDataLoadStatus.loaded;
    provider.notifyListeners();
    // 대기 안내 점은 계속 움직이므로 전환 시간만 진행합니다.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('phone-group-waiting')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('phone-game-details-holdem')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('phone-game-details-mafia')),
      findsNothing,
    );
    expect(find.byKey(const Key('waiting-players-bar')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    provider.dispose();
  });

  testWidgets('동작 줄이기 설정에서는 선택 전환을 즉시 완료한다', (tester) async {
    final provider = _provider();
    final game = provider.selectedGame;
    provider
      ..selectedGameId = null
      ..selectedGame = null
      ..groupGamesLoadStatus = RoomDataLoadStatus.loaded;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: PhoneRoomWaiting(
            provider: provider,
            headerForTesting: const SizedBox(height: 72),
          ),
        ),
      ),
    );
    // 대기 안내 점은 계속 움직이므로 전환 시간만 진행합니다.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    provider
      ..selectedGameId = 'holdem'
      ..selectedGame = game;
    provider.notifyListeners();
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('phone-group-waiting')), findsNothing);
    expect(
      find.byKey(const ValueKey('phone-game-details-holdem')),
      findsOneWidget,
    );
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      MosiGameArt.holdem.shelfTheme.ground,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    provider.dispose();
  });

  testWidgets('선택된 게임 하단은 실제 참가자 입장·퇴장·재연결 상태를 반영한다', (tester) async {
    final provider = _provider()
      ..players = [
        _player(0),
        _player(1, connected: false),
        _player(2, role: 'spectator'),
        _player(3, status: 'left'),
      ];
    await tester.pumpWidget(_app(provider));
    await tester.pump();
    expect(find.text('곧 시작합니다'), findsNothing);
    expect(find.text('함께하는 사람 2', findRichText: true), findsOneWidget);
    expect(find.text('1명 재연결 중'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('waiting-player-player-0')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('waiting-player-player-2')), findsNothing);
    provider.players = [_player(1), _player(4), _player(5)];
    provider.notifyListeners();
    await tester.pump();
    expect(find.text('함께하는 사람 3', findRichText: true), findsOneWidget);
    expect(find.text('1명 재연결 중'), findsNothing);
    expect(find.byKey(const ValueKey('waiting-player-player-0')), findsNothing);
    expect(
      find.byKey(const ValueKey('waiting-player-player-5')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    provider.dispose();
  });
  testWidgets('좁은 휴대폰에서도 목록을 가로 스크롤해 마지막 참가자를 볼 수 있다', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final provider = _provider()..players = List.generate(12, _player);
    await tester.pumpWidget(_app(provider));
    await tester.pump();
    final footer = find.byKey(const Key('waiting-players-bar'));
    final before = tester.getRect(footer);
    await tester.drag(
      find.byKey(const Key('waiting-players-scroll')),
      const Offset(-800, 0),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('waiting-player-player-11')).hitTestable(),
      findsOneWidget,
    );
    expect(tester.getRect(footer), before);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    provider.dispose();
  });
}
