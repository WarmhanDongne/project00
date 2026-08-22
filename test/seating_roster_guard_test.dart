import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/games/shared/player_layouts/seating_roster_guard.dart';
import 'package:project00/platform/home/gamelist/service/game_list_service.dart';
import 'package:project00/platform/home/room/models/room_player.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';
import 'package:project00/platform/home/room/services/room_service.dart';

//=======================자리 배치 중 참가자 변경 (C-13)==============================
// 자리 배치 초안은 태블릿 메모리에만 있고, 화면에 넘긴 PlayerLayoutModel은 라우트를
// push할 때 한 번 만들어진 뒤 갱신되지 않습니다. 그동안 참가자가 나가면 서버가
// 좌석 저장을 거부하는데(UID 집합 일치 검사) 진행자에게는 원인이 보이지 않습니다.
//
// ⚠️ 가장 중요한 계약: **heartbeat로는 취소하지 않는다.** players 노드는 10초
// 주기 lastSeen 갱신마다 이벤트를 냅니다. 노드 내용을 비교하면 자리 배치가 10초마다
// 스스로 취소됩니다.

void main() {
  RoomPlayer player(
    String uid, {
    bool isConnected = true,
    String status = 'active',
    String role = 'player',
    int seatIndex = -1,
  }) {
    return RoomPlayer(
      uid: uid,
      nickname: uid,
      characterId: 'frog',
      isConnected: isConnected,
      seatIndex: seatIndex,
      role: role,
      status: status,
      penaltyAttemptCount: 0,
    );
  }

  /// 가드를 띄우고 변경 횟수를 세는 카운터를 돌려줍니다.
  Future<(RoomProvider, List<int>)> pumpGuard(
    WidgetTester tester,
    List<RoomPlayer> initial,
  ) async {
    // 기본 생성자는 RoomService()를 만들며 Firebase에 손을 댑니다. 이 가드는
    // players와 roomCode만 읽으므로 가짜를 넣어 Firebase 없이 띄웁니다.
    final provider =
        RoomProvider(
            service: _UnusedRoomService(),
            gameService: _UnusedGameService(),
            currentUidReader: () => 'tablet',
          )
          ..roomCode = 'TESTR'
          ..players = initial;
    addTearDown(provider.dispose);
    final changes = <int>[];

    await tester.pumpWidget(
      MaterialApp(
        home: SeatingRosterGuard(
          provider: provider,
          onRosterChanged: () => changes.add(changes.length + 1),
          child: const SizedBox.shrink(),
        ),
      ),
    );
    return (provider, changes);
  }

  /// players를 바꾸고 알림을 흘려보냅니다.
  void emit(RoomProvider provider, List<RoomPlayer> players) {
    provider
      ..players = players
      ..notifyListeners();
  }

  testWidgets('heartbeat만 바뀌면 취소하지 않는다', (tester) async {
    final (provider, changes) = await pumpGuard(tester, [
      player('a'),
      player('b'),
    ]);

    // lastSeen 갱신은 같은 UID로 새 RoomPlayer 객체를 만들어 냅니다.
    for (var tick = 0; tick < 5; tick += 1) {
      emit(provider, [player('a'), player('b')]);
      await tester.pump();
    }

    expect(changes, isEmpty, reason: '10초마다 자리 배치가 취소되면 안 됩니다');
  });

  testWidgets('좌석 번호가 저장돼도 취소하지 않는다', (tester) async {
    // savePlayerSeatIndexes가 성공하면 서버가 seatIndex를 씁니다. 이때 players
    // 노드가 바뀌지만 UID 집합은 그대로입니다.
    final (provider, changes) = await pumpGuard(tester, [
      player('a'),
      player('b'),
    ]);

    emit(provider, [player('a', seatIndex: 0), player('b', seatIndex: 1)]);
    await tester.pump();

    expect(changes, isEmpty);
  });

  testWidgets('연결이 끊긴 참가자는 아직 나간 것이 아니다', (tester) async {
    final (provider, changes) = await pumpGuard(tester, [
      player('a'),
      player('b'),
    ]);

    emit(provider, [player('a'), player('b', isConnected: false)]);
    await tester.pump();

    expect(changes, isEmpty, reason: '재접속 유예 중인 참가자로 자리 배치를 되감으면 안 됩니다');
  });

  testWidgets('참가자가 나가면 한 번만 알린다', (tester) async {
    final (provider, changes) = await pumpGuard(tester, [
      player('a'),
      player('b'),
      player('c'),
    ]);

    emit(provider, [player('a'), player('b')]);
    await tester.pump();
    expect(changes, hasLength(1));

    // 이어지는 heartbeat와 추가 변경으로 취소 요청이 중복되면 안 됩니다.
    emit(provider, [player('a')]);
    await tester.pump();
    emit(provider, [player('a'), player('b')]);
    await tester.pump();
    expect(changes, hasLength(1));
  });

  testWidgets('참가자가 늘어도 알린다', (tester) async {
    // 서버가 seating에서 신규 참가를 막지만, 자리 배치 직전에 들어온 참가자가
    // 태블릿 화면에 늦게 도착할 수 있습니다.
    final (provider, changes) = await pumpGuard(tester, [player('a')]);

    emit(provider, [player('a'), player('b')]);
    await tester.pump();

    expect(changes, hasLength(1));
  });

  testWidgets('강퇴로 status가 바뀌어도 알린다', (tester) async {
    final (provider, changes) = await pumpGuard(tester, [
      player('a'),
      player('b'),
    ]);

    emit(provider, [player('a'), player('b', status: 'removed')]);
    await tester.pump();

    expect(changes, hasLength(1));
  });

  testWidgets('관전자(role != player)는 자리 배치 대상이 아니다', (tester) async {
    final (provider, changes) = await pumpGuard(tester, [
      player('a'),
      player('b'),
    ]);

    emit(provider, [
      player('a'),
      player('b'),
      player('watcher', role: 'observer'),
    ]);
    await tester.pump();

    expect(changes, isEmpty);
  });

  testWidgets('방을 떠난 뒤의 빈 목록은 참가자 변경이 아니다', (tester) async {
    // clearRoom은 players를 비우고 roomCode를 null로 만듭니다. 그 순간을 변경으로
    // 읽으면 이미 닫히는 화면에서 취소 요청이 한 번 더 나갑니다.
    final (provider, changes) = await pumpGuard(tester, [
      player('a'),
      player('b'),
    ]);

    provider
      ..roomCode = null
      ..players = []
      ..notifyListeners();
    await tester.pump();

    expect(changes, isEmpty);
  });

  test('자리 배치 대상 UID는 활성 참가자만 센다', () {
    expect(
      SeatingRosterGuard.seatedUids([
        player('a'),
        player('b', isConnected: false),
        player('c', status: 'removed'),
        player('d', role: 'observer'),
      ]),
      {'a', 'b'},
    );
  });
}

/// 이 시험은 서버를 부르지 않습니다. 불리면 바로 알 수 있게 던집니다.
class _UnusedRoomService implements RoomService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _UnusedGameService implements GameService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
