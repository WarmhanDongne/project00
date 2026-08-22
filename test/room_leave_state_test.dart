import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/platform/home/gamelist/service/game_list_service.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';
import 'package:project00/platform/home/room/services/player_room_session_store.dart';
import 'package:project00/platform/home/room/services/room_common.dart';
import 'package:project00/platform/home/room/services/room_leave_intent.dart';
import 'package:project00/platform/home/room/services/room_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    RoomLeaveIntent.resetForTesting();
    // 저장소는 프로세스 싱글턴이라 테스트 사이에 메모리 캐시를 비웁니다.
    await PlayerRoomSessionStore.instance.clear();
  });

  test('실패한 퇴장은 상태를 되돌리고 그대로 다시 시도할 수 있다', () async {
    final service = _LeaveRoomService()..leaveError = _unavailable();
    final provider = _provider(service);
    addTearDown(() async {
      provider.dispose();
      await service.dispose();
    });

    expect(await provider.leaveRoom(), isFalse);
    expect(provider.isLeaving, isFalse, reason: '실패해도 플래그가 래치되면 안 됩니다');
    expect(provider.isLoading, isFalse);
    expect(provider.roomCode, 'ABCDE');
    expect(provider.errorMessage, isNotNull);
    expect(RoomLeaveIntent.blocksRestore('ABCDE'), isFalse);

    // 네트워크가 돌아온 뒤 첫 재시도 한 번으로 완료돼야 합니다.
    service.leaveError = null;
    expect(await provider.leaveRoom(), isTrue);
    expect(service.leaveCalls, 2);
    expect(provider.roomCode, isNull);
    expect(provider.errorMessage, isNull);
    expect(RoomLeaveIntent.hasLeft('ABCDE'), isTrue);
  });

  test('중복 탭은 요청을 한 번만 보내고 두 번째는 조용히 끝난다', () async {
    final service = _LeaveRoomService()..gate = Completer<void>();
    final provider = _provider(service);
    addTearDown(() async {
      provider.dispose();
      await service.dispose();
    });

    final first = provider.leaveRoom();
    final second = provider.leaveRoom();
    await _flushEvents();

    expect(service.leaveCalls, 1);
    expect(await second, isFalse);
    expect(provider.isLeaving, isTrue, reason: '진행 중임을 호출자가 구분할 수 있어야 합니다');
    expect(provider.errorMessage, isNull, reason: '삼켜진 중복 탭은 실패가 아닙니다');

    service.gate!.complete();
    expect(await first, isTrue);
    expect(provider.isLeaving, isFalse);
  });

  test('게임 중 퇴장은 강퇴로 표시되지 않는다', () async {
    final service = _LeaveRoomService()..gate = Completer<void>();
    final provider = _provider(service)..listenRoom();
    addTearDown(() async {
      provider.dispose();
      await service.dispose();
    });

    service.players.add(const [_player]);
    await _flushEvents();

    final leaving = provider.leaveGame('liars_poker');
    await _flushEvents();
    // 서버 트랜잭션이 내 노드를 지운 이벤트가 callable 응답보다 먼저 옵니다.
    service.players.add(const []);
    await _flushEvents();
    service.gate!.complete();

    expect(await leaving, isTrue);
    expect(provider.wasKicked, isFalse);
    expect(service.roomExistenceReads, 0);
    expect(provider.roomCode, isNull);
  });

  test('방이 사라져 실패로 답한 퇴장은 성공으로 처리한다', () async {
    final service = _LeaveRoomService()
      ..leaveError = _aborted()
      ..roomExistsResult = false;
    final provider = _provider(service);
    addTearDown(() async {
      provider.dispose();
      await service.dispose();
    });

    expect(await provider.leaveGame('liars_poker'), isTrue);
    expect(provider.errorMessage, isNull);
    expect(provider.roomCode, isNull);
    expect(await PlayerRoomSessionStore.instance.load(), isNull);
  });

  test('내 참가자 노드가 이미 없으면 성공으로 처리한다', () async {
    final service = _LeaveRoomService()
      ..leaveError = _aborted()
      ..activePlayerNodeResult = false;
    final provider = _provider(service);
    addTearDown(() async {
      provider.dispose();
      await service.dispose();
    });

    expect(await provider.leaveGame('liars_poker'), isTrue);
    expect(provider.errorMessage, isNull);
    expect(provider.roomCode, isNull);
  });

  test('퇴장 완료 확인이 실패하면 실패로 남긴다', () async {
    final service = _LeaveRoomService()
      ..leaveError = _unavailable()
      ..roomExistsThrows = true;
    final provider = _provider(service);
    addTearDown(() async {
      provider.dispose();
      await service.dispose();
    });

    expect(await provider.leaveRoom(), isFalse);
    expect(provider.errorMessage, isNotNull);
    expect(provider.isLeaving, isFalse);
    expect(provider.roomCode, 'ABCDE');
  });

  test('퇴장이 끝난 방은 다른 provider에서도 자동 복원되지 않는다', () async {
    await PlayerRoomSessionStore.instance.save(
      uid: 'me',
      roomCode: 'ABCDE',
      nickname: '나',
      characterId: 'frog',
    );
    final service = _LeaveRoomService();
    final provider = _provider(service);
    addTearDown(() async {
      provider.dispose();
      await service.dispose();
    });

    expect(await provider.leaveRoom(), isTrue);

    // 같은 인스턴스도, 홈 화면이 들고 있는 별도 인스턴스도 되살리지 않습니다.
    expect(await provider.restorePlayerRoom(), isFalse);
    final otherService = _LeaveRoomService()..roomCode = null;
    final other = RoomProvider(
      service: otherService,
      gameService: _NoopGameService(),
      currentUidReader: () => 'me',
    );
    addTearDown(() async {
      other.dispose();
      await otherService.dispose();
    });
    expect(await other.restorePlayerRoom(), isFalse);
    expect(otherService.restoreCalls, 0);
    expect(otherService.existingPlayerReads, 0);
  });

  test('퇴장 중에는 네트워크 복구가 방을 되살리지 않는다', () async {
    final service = _LeaveRoomService()..gate = Completer<void>();
    final provider = _provider(service)..listenRoom();
    addTearDown(() async {
      provider.dispose();
      await service.dispose();
    });

    service.serverConnection.add(true);
    await _flushEvents();
    final leaving = provider.leaveRoom();
    await _flushEvents();

    // 퇴장 도중 연결이 끊기고 돌아옵니다.
    service.serverConnection.add(false);
    await _flushEvents();
    service.serverConnection.add(true);
    await _flushEvents();
    expect(service.restoreCalls, 0, reason: '사용자의 첫 재시도 전에 다시 입장하면 안 됩니다');

    service.gate!.complete();
    expect(await leaving, isTrue);
    expect(service.restoreCalls, 0);
  });

  test('퇴장 중 도착한 구독 오류는 사용자 오류로 남지 않는다', () async {
    final service = _LeaveRoomService()..gate = Completer<void>();
    final provider = _provider(service)..listenRoom();
    addTearDown(() async {
      provider.dispose();
      await service.dispose();
    });

    final leaving = provider.leaveRoom();
    await _flushEvents();
    // 참가자 노드가 사라지면 살아 있는 구독이 permission-denied로 끝납니다.
    service.players.addError(_permissionDenied());
    await _flushEvents();
    expect(provider.errorMessage, isNull);

    service.gate!.complete();
    expect(await leaving, isTrue);
    expect(provider.errorMessage, isNull);
  });

  test('구독 취소보다 늦게 도착한 오류는 버린다', () async {
    final service = _LeaveRoomService();
    final provider = _provider(service)..listenRoom();
    addTearDown(() async {
      provider.dispose();
      await service.dispose();
    });

    provider.clearRoom();
    service.players.addError(StateError('늦게 도착한 오류'));
    await _flushEvents();
    expect(provider.errorMessage, isNull);
  });
}

RoomProvider _provider(_LeaveRoomService service) => RoomProvider(
  service: service,
  gameService: _NoopGameService(),
  currentUidReader: () => 'me',
)..roomCode = service.roomCode;

FirebaseFunctionsException _unavailable() => FirebaseFunctionsException(
  code: 'unavailable',
  message: 'The service is currently unavailable.',
);

FirebaseFunctionsException _aborted() =>
    FirebaseFunctionsException(code: 'aborted', message: '게임에서 퇴장하지 못했습니다.');

FirebaseException _permissionDenied() => FirebaseException(
  plugin: 'firebase_database',
  code: 'permission-denied',
  message: 'Client does not have permission to access the desired data.',
);

const _player = RoomPlayer(
  uid: 'me',
  nickname: '나',
  characterId: 'frog',
  isConnected: true,
  seatIndex: 0,
  role: 'player',
  status: 'active',
  penaltyAttemptCount: 0,
);

Future<void> _flushEvents() async {
  for (var i = 0; i < 6; i += 1) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _LeaveRoomService implements RoomService {
  final serverConnection = StreamController<bool>.broadcast();
  final controllerConnected = StreamController<bool?>.broadcast();
  final roomExistsChanges = StreamController<bool>.broadcast();
  final roomStatus = StreamController<String?>.broadcast();
  final players = StreamController<List<RoomPlayer>>.broadcast();

  String? roomCode = 'ABCDE';

  /// 퇴장 callable이 던질 예외입니다. null이면 성공합니다.
  Object? leaveError;

  /// 완료 시점을 시험이 통제하기 위한 게이트입니다.
  Completer<void>? gate;

  bool roomExistsResult = true;
  bool roomExistsThrows = false;
  bool activePlayerNodeResult = true;

  int leaveCalls = 0;
  int roomExistenceReads = 0;
  int restoreCalls = 0;
  int existingPlayerReads = 0;

  Future<void> _leave() async {
    leaveCalls += 1;
    final pending = gate;
    if (pending != null) await pending.future;
    final error = leaveError;
    if (error != null) throw error;
  }

  @override
  Future<void> leaveRoom(String roomCode) => _leave();

  @override
  Future<void> leaveGame({
    required String cloudFunctionName,
    required String roomCode,
  }) => _leave();

  @override
  Future<bool> roomExists(String roomCode) async {
    roomExistenceReads += 1;
    if (roomExistsThrows) throw const RoomCommandException('확인 실패');
    return roomExistsResult;
  }

  @override
  Future<bool> hasActivePlayerNode(String roomCode) async =>
      activePlayerNodeResult;

  @override
  Future<bool> hasExistingPlayer(String roomCode) async {
    existingPlayerReads += 1;
    return true;
  }

  @override
  Future<void> restorePlayerConnection({
    required String roomCode,
    required String nickname,
    required String characterId,
  }) async {
    restoreCalls += 1;
  }

  @override
  Future<void> heartbeatPlayer(String roomCode) async {}

  @override
  Stream<bool> watchServerConnection() => serverConnection.stream;

  @override
  Stream<bool?> watchControllerConnected(String roomCode) =>
      controllerConnected.stream;

  @override
  Stream<bool> watchRoomExists(String roomCode) => roomExistsChanges.stream;

  @override
  Stream<String?> watchRoomStatus(String roomCode) => roomStatus.stream;

  @override
  Stream<DatabaseEvent> watchRoom(String roomCode) => const Stream.empty();

  @override
  Stream<List<RoomPlayer>> watchRoomPlayers(String roomCode) => players.stream;

  Future<void> dispose() async {
    await Future.wait([
      serverConnection.close(),
      controllerConnected.close(),
      roomExistsChanges.close(),
      roomStatus.close(),
      players.close(),
    ]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoopGameService implements GameService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
