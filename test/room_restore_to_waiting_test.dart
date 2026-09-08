import 'package:flutter_test/flutter_test.dart';
import 'package:project00/platform/home/gamelist/service/game_list_service.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';
import 'package:project00/platform/home/room/services/room_common.dart';
import 'package:project00/platform/home/room/services/room_restore_to_waiting.dart';
import 'package:project00/platform/home/room/services/room_service.dart';

//=======================게임 종료 후 방 복귀 (P-02)==============================
// 게임 종료 경로 어디에도 selectedGame을 지우는 코드가 없었다. 방이
// status = finished + selectedGame 잔류 상태로 남아:
//   - 휴대폰이 룰북과 `곧 시작합니다`에 갇히고
//   - decideRoomJoin이 신규 참가를 막고
//   - isRestorablePlayerSessionState가 재접속을 막았다.
// 유일한 탈출구는 태블릿이 다른 게임을 다시 고르는 것뿐이었다.

void main() {
  (RoomProvider, _RecordingRoomService) provider({
    String? roomCode,
    String? roomStatus,
  }) {
    final service = _RecordingRoomService();
    final value = RoomProvider(
      service: service,
      gameService: _UnusedGameService(),
      currentUidReader: () => 'tablet',
    );
    value
      ..roomCode = roomCode
      ..roomStatus = roomStatus;
    addTearDown(value.dispose);
    return (value, service);
  }

  test('게임이 끝난 방은 대기 상태로 되돌린다', () async {
    final (room, service) = provider(roomCode: 'ABCDE', roomStatus: 'finished');

    await restoreRoomToWaiting(room);

    expect(service.clearedGameFor, ['ABCDE']);
  });

  test('아직 진행 중이면 건드리지 않는다', () async {
    // 태블릿만 화면을 벗어난 경우가 있다. 여기서 선택을 해제하면 서버가
    // 거부하고 화면에 불필요한 오류가 뜬다.
    final (room, service) = provider(roomCode: 'ABCDE', roomStatus: 'playing');

    await restoreRoomToWaiting(room);

    expect(service.clearedGameFor, isEmpty);
  });

  test('이미 대기 상태면 다시 보내지 않는다', () async {
    final (room, service) = provider(roomCode: 'ABCDE', roomStatus: 'waiting');

    await restoreRoomToWaiting(room);

    expect(service.clearedGameFor, isEmpty);
  });

  test('방을 이미 떠났으면 아무것도 하지 않는다', () async {
    final (room, service) = provider(roomCode: null, roomStatus: 'finished');

    await restoreRoomToWaiting(room);

    expect(service.clearedGameFor, isEmpty);
  });

  test('서버가 실패해도 던지지 않는다', () async {
    // 사용자는 이미 대기실을 보고 있다. 서버 정리 스케줄과 다음 게임 선택이
    // 같은 일을 다시 한다.
    final (room, service) = provider(roomCode: 'ABCDE', roomStatus: 'finished');
    service.failClear = true;

    await restoreRoomToWaiting(room);

    expect(service.clearedGameFor, ['ABCDE']);
  });

  test('태블릿 재실행 홈은 끝난 게임과 방이 동기화되면 정리한다', () async {
    final (room, service) = provider(roomCode: 'ABCDE', roomStatus: 'finished');

    final restored = await restoreFinishedRoomOnControllerHome(
      provider: room,
      gameStatus: 'finished',
      isControllerHomeCurrent: true,
      isOpeningGame: false,
    );

    expect(restored, isTrue);
    expect(service.clearedGameFor, ['ABCDE']);
  });

  test('결과 화면이 열려 있거나 방 상태 동기화 전에는 정리하지 않는다', () async {
    final (room, service) = provider(roomCode: 'ABCDE', roomStatus: 'playing');

    for (final isOpeningGame in [false, true]) {
      final restored = await restoreFinishedRoomOnControllerHome(
        provider: room,
        gameStatus: 'finished',
        isControllerHomeCurrent: true,
        isOpeningGame: isOpeningGame,
      );
      expect(restored, isFalse);
    }

    expect(service.clearedGameFor, isEmpty);
  });
}

/// 선택 해제 호출만 기록합니다. 나머지가 불리면 바로 알 수 있게 던집니다.
class _RecordingRoomService implements RoomService {
  final clearedGameFor = <String>[];
  bool failClear = false;

  @override
  Future<void> selectGame({required String roomCode, String? gameId}) async {
    clearedGameFor.add(roomCode);
    if (failClear) throw const RoomCommandException('서버 오류');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _UnusedGameService implements GameService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
