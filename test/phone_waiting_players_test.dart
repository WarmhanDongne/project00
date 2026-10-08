import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
