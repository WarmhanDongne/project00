import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:project00/platform/home/phone/widgets/phone_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/platform/home/phone/widgets/phone_room_participant_list.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:game_kit/mosi_ui/mosi_game_art.dart';
import 'package:project00/platform/home/gamelist/models/game_info.dart';
import 'package:project00/platform/home/gamelist/service/game_list_service.dart';
import 'package:project00/platform/home/phone/screens/phone_room_waiting.dart';
import 'package:project00/platform/home/phone/widgets/phone_flow_transition.dart';
import 'package:project00/platform/home/room/models/room_player.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';
import 'package:project00/platform/home/room/services/player_room_session_store.dart';
import 'package:project00/platform/home/room/services/room_service.dart';
import 'package:project00/platform/home/room/services/room_leave_intent.dart';
import 'package:project00/platform/theme/platform_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Rooms extends Fake implements RoomService {
  Completer<void>? leaveGate;
  Object? leaveError;
  int leaveCalls = 0;

  @override
  Stream<bool> watchServerConnection() =>
      Stream.multi((sink) => sink.add(true));
  @override
  Stream<String?> watchGameStatus(String roomCode) => const Stream.empty();

  @override
  Future<void> leaveRoom(String roomCode) async {
    leaveCalls++;
    await leaveGate?.future;
    final error = leaveError;
    if (error != null) throw error;
  }
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
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    RoomLeaveIntent.resetForTesting();
    FirebaseAuthPlatform.instanceFor(
      app: Firebase.app(),
      pluginConstants: {
        'APP_CURRENT_USER': [
          InternalUserInfo(
            uid: 'player-0',
            isAnonymous: true,
            isEmailVerified: false,
          ).encode(),
          <Map<Object?, Object?>>[],
        ],
      },
    );
  });

  testWidgets('그룹 나가기는 즉시 테마 전환을 열고 실패 복귀 뒤 같은 요청을 재시도한다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() async {
      RoomLeaveIntent.resetForTesting();
      await PlayerRoomSessionStore.instance.clear();
    });
    final roomService = _Rooms()
      ..leaveGate = Completer<void>()
      ..leaveError = StateError('offline');
    final provider = RoomProvider(service: roomService, gameService: _Games())
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
    addTearDown(provider.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: PlatformTheme.light(),
        home: PhoneRoomWaiting(provider: provider),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('그룹 나가기'));
    await tester.pump();

    expect(roomService.leaveCalls, 1);
    expect(find.byKey(const Key('phone-room-leaving')), findsOneWidget);
    expect(find.text('그룹에서 나가는 중이에요'), findsOneWidget);
    expect(
      tester
          .widget<PhoneBackgroundReveal>(
            find.byKey(const Key('phone-room-leaving-background')),
          )
          .color,
      MosiGameArt.holdem.shelfTheme.ground,
    );

    roomService.leaveGate!.complete();
    await tester.pump(const Duration(milliseconds: 260));
    await tester.pump(const Duration(milliseconds: 260));
    expect(find.byKey(const Key('phone-room-leave-failed')), findsOneWidget);
    expect(find.text('그룹에서 나가지 못했어요'), findsOneWidget);
    expect(find.text('대기실로 돌아가기'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);

    roomService
      ..leaveGate = Completer<void>()
      ..leaveError = null;
    await tester.tap(find.text('다시 시도'));
    await tester.pump();
    expect(roomService.leaveCalls, 2);
    expect(find.text('그룹에서 나가는 중이에요'), findsOneWidget);
    roomService.leaveGate!.complete();
    await tester.pump(const Duration(milliseconds: 260));
    await tester.pump();
    expect(provider.roomCode, isNull);
    expect(find.byKey(const Key('phone-room-leave-failed')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('강퇴되면 최상단 배경 전환으로 화면을 덮은 뒤 홈으로 돌아간다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final provider = _provider();
    addTearDown(provider.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: PlatformTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                PhoneFlowRoute<void>(
                  builder: (_) => PhoneRoomWaiting(provider: provider),
                ),
              ),
              child: const Text('홈'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('홈'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    provider
      ..roomCode = null
      ..wasKicked = true
      ..notifyListeners();
    await tester.pump();
    expect(
      find.byKey(const Key('phone-room-forced-exit-overlay')),
      findsOneWidget,
    );
    expect(find.text('방에서 나왔어요'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 180));
    expect(
      find.byKey(const Key('phone-room-leaving-background')),
      findsOneWidget,
    );
    expect(find.text('그룹 나가기'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 220));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('홈'), findsOneWidget);
    expect(
      find.byKey(const Key('phone-room-forced-exit-overlay')),
      findsNothing,
    );
    expect(find.text('방에서 추방되었습니다.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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
        tester
            .widget<PhoneBackgroundWipe>(find.byType(PhoneBackgroundWipe))
            .color,
        MosiSeatTheme.of(gameId).table,
      );
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        Colors.transparent,
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

  testWidgets('게임 소개에서 자리 배치로 갈 때 같은 배경 레이어가 테이블색을 대각선으로 덮는다', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final provider = _provider();
    addTearDown(provider.dispose);

    await tester.pumpWidget(_app(provider));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final background = find.byType(PhoneBackgroundWipe);
    final backgroundElement = tester.element(background);

    provider.roomStatus = 'seating';
    provider.notifyListeners();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.element(background), same(backgroundElement));
    expect(
      tester.widget<PhoneBackgroundWipe>(background).color,
      MosiSeatTheme.holdem.table,
    );
    expect(
      tester
          .widget<ColoredBox>(
            find.byKey(const Key('phone-background-wipe-base')),
          )
          .color,
      MosiGameArt.holdem.shelfTheme.ground,
    );
    final reveal = tester.widget<PhoneBackgroundReveal>(
      find.byKey(const Key('phone-background-wipe-reveal')),
    );
    expect(reveal.direction, PhoneBackgroundWipeDirection.topRightToBottomLeft);
    expect(reveal.color, MosiSeatTheme.holdem.table);
    expect(reveal.progress, inExclusiveRange(0, 1));
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      Colors.transparent,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('참여자 목록은 내 줄에만 나 표시를 붙인다', (tester) async {
    RoomPlayer player(String uid, String name) => RoomPlayer(
      uid: uid,
      nickname: name,
      characterId: 'frog',
      isConnected: true,
      seatIndex: 0,
      role: 'player',
      status: 'active',
      penaltyAttemptCount: 0,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PhoneRoomParticipantList(
            players: [player('me', '나의닉'), player('other', '친구')],
            myUid: 'me',
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    final badge = find.byKey(const Key('participant-me-badge'));
    final avatar = find.byKey(const ValueKey('participant-avatar-me'));
    expect(badge, findsOneWidget);
    final avatarRect = tester.getRect(avatar);
    final badgeRect = tester.getRect(badge);
    expect(badgeRect.center.dx, greaterThan(avatarRect.center.dx));
    expect(badgeRect.center.dy, greaterThan(avatarRect.center.dy));
    expect(badgeRect.left, lessThan(avatarRect.right));
    expect(badgeRect.top, lessThan(avatarRect.bottom));
    expect(badgeRect.width, lessThan(avatarRect.width));
    expect(badgeRect.height, lessThan(avatarRect.height));
    expect(tester.takeException(), isNull);
  });

  testWidgets('태블릿에서 시작한 뒤에는 게임 규칙 대신 곧 시작한다는 안내를 보여 준다', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final provider = _provider()..roomStatus = 'seating';
    await tester.pumpWidget(
      MaterialApp(
        theme: PlatformTheme.light(),
        home: PhoneRoomWaiting(provider: provider),
      ),
    );
    await tester.pump();
    expect(find.text('태블릿에서\n자리를 맞추고 있어요'), findsOneWidget);

    provider
      ..roomStatus = 'playing'
      ..notifyListeners();
    await tester.pump();
    expect(find.text('곧 게임이\n시작해요'), findsOneWidget);
    expect(find.text('게임 규칙'), findsNothing);
    expect(find.text('그룹 나가기'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    provider.dispose();
  });

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
      tester
          .widget<PhoneBackgroundWipe>(find.byType(PhoneBackgroundWipe))
          .color,
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
    expect(
      tester
          .widget<PhoneBackgroundWipe>(find.byType(PhoneBackgroundWipe))
          .color,
      MosiGameArt.holdem.shelfTheme.ground,
    );
    expect(
      tester
          .widget<ColoredBox>(
            find.byKey(const Key('phone-background-wipe-base')),
          )
          .color,
      MosiColors.violet,
    );
    final reveal = tester.widget<PhoneBackgroundReveal>(
      find.byKey(const Key('phone-background-wipe-reveal')),
    );
    expect(reveal.direction, PhoneBackgroundWipeDirection.topRightToBottomLeft);
    expect(reveal.color, MosiGameArt.holdem.shelfTheme.ground);
    expect(reveal.progress, inExclusiveRange(0, 1));
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
      tester
          .widget<PhoneBackgroundWipe>(find.byType(PhoneBackgroundWipe))
          .color,
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
      tester
          .widget<PhoneBackgroundWipe>(find.byType(PhoneBackgroundWipe))
          .color,
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

  testWidgets('phone player marker follows the selected game theme', (
    tester,
  ) async {
    final provider = _provider()..players = [_player(0)];
    await tester.pumpWidget(_app(provider));
    await tester.pump();

    MosiPill marker() => tester.widget<MosiPill>(
      find.byKey(const Key('waiting-player-me-badge')),
    );
    expect(marker().background, MosiGameArt.holdem.shelfTheme.btnBg);
    expect(marker().color, MosiGameArt.holdem.shelfTheme.btnFg);
    final avatarRect = tester.getRect(
      find.byKey(const ValueKey('waiting-player-avatar-player-0')),
    );
    final markerRect = tester.getRect(
      find.byKey(const Key('waiting-player-me-badge')),
    );
    expect(markerRect.center.dx, greaterThan(avatarRect.center.dx));
    expect(markerRect.center.dy, greaterThan(avatarRect.center.dy));
    expect(markerRect.left, lessThan(avatarRect.right));
    expect(markerRect.top, lessThan(avatarRect.bottom));

    provider
      ..selectedGameId = 'mafia'
      ..selectedGame = GameInfo.fromJson({'id': 'mafia', 'name': 'mafia'});
    provider.notifyListeners();
    await tester.pump();
    expect(marker().background, MosiGameArt.mafia.shelfTheme.btnBg);
    expect(marker().color, MosiGameArt.mafia.shelfTheme.btnFg);
    await tester.pumpWidget(const SizedBox.shrink());
    provider.dispose();
  });
}
