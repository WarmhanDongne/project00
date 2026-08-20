import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:project00/firebase/services/realtime_database_service.dart';
import 'package:project00/core/network/realtime_connection_monitor.dart';
import 'package:project00/platform/home/room/services/room_common.dart';
import 'package:project00/platform/home/room/services/controller_room_session_store.dart';

class RoomService {
  static const int _databaseOperationAttempts = 4;
  static const int _functionOperationAttempts = 4;

  RoomService({
    FirebaseDatabase? database,
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
  }) : realtime = database ?? RealtimeDatabaseService.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _functions =
           functions ??
           FirebaseFunctions.instanceFor(region: 'asia-northeast3');

  final FirebaseDatabase realtime;
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  Future<User> ensureAuthenticated() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      return currentUser;
    }
    final credential = await FirebaseAuth.instance.signInAnonymously();
    final user = credential.user;
    if (user == null) {
      throw const RoomCommandException('사용자 인증에 실패했습니다.');
    }
    return user;
  }

  Future<String> createRoom() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw const RoomCommandException('방을 만들려면 로그인이 필요합니다.');
    }

    try {
      final response = await _functions
          .httpsCallable('createRealtimeRoom')
          .call();

      final data = Map<String, dynamic>.from(response.data as Map);

      final roomCode = data['roomCode'] as String?;
      final controllerSessionId = data['controllerSessionId'] as String?;

      if (roomCode == null ||
          roomCode.isEmpty ||
          controllerSessionId == null ||
          controllerSessionId.isEmpty) {
        throw const RoomCommandException('생성된 방 코드를 확인할 수 없습니다.');
      }
      await ControllerRoomSessionStore.instance.save(
        roomCode: roomCode,
        sessionId: controllerSessionId,
      );
      await markControllerConnected(roomCode);
      return roomCode;
    } on FirebaseFunctionsException catch (error) {
      throw RoomCommandException(error.message ?? '방을 생성하지 못했습니다.');
    } catch (error) {
      if (error is RoomCommandException) {
        rethrow;
      }
      throw RoomCommandException('방을 생성하지 못했습니다: $error');
    }
  }

  Future<List<RoomPlayer>> getRoomPlayers(String roomCode) async {
    final snapshot = await _readWithRetry(
      realtime.ref('rooms/$roomCode/players'),
    );
    return _playersFromSnapshot(snapshot);
  }

  Stream<DatabaseEvent> watchRoom(String roomCode) {
    return realtime.ref('rooms/$roomCode/selectedGame').onValue;
  }

  /// 게임 종류와 관계없이 플랫폼 대기실이 확인하는 공통 시작 상태입니다.
  ///
  /// 게임 선택 알림보다 게임 노드가 먼저 생성되어도 현재 값을 다시 받을 수 있도록
  /// `onValue`를 사용합니다.
  Stream<String?> watchGameStatus(String roomCode) {
    return realtime
        .ref('rooms/$roomCode/game/public/status')
        .onValue
        .map((event) => event.snapshot.value?.toString());
  }

  //=======================태블릿(진행 기기) 방 수명 주기==============================
  // 방 전체를 삭제하지 않고 presence만 false로 예약합니다. 실제 삭제는
  // controller lastSeen 유예시간을 확인하는 scheduled cleanup이 담당합니다.
  Future<void> markControllerConnected(String roomCode) async {
    final roomRef = realtime.ref('rooms/$roomCode');
    final presenceRef = roomRef.child('controllerPresence');
    await presenceRef.onDisconnect().update({
      'connected': false,
      'lastSeen': ServerValue.timestamp,
    });
    await _writeWithRetry(
      () => presenceRef.set({
        'connected': true,
        'lastSeen': ServerValue.timestamp,
      }),
    );
  }

  Future<void> heartbeatController(String roomCode) async {
    await _writeWithRetry(
      () => realtime.ref('rooms/$roomCode/controllerPresence').update({
        'connected': true,
        'lastSeen': ServerValue.timestamp,
      }),
    );
  }

  /// 백그라운드·dispose에서는 presence만 멈추며 방을 삭제하지 않습니다.
  Future<void> markControllerDisconnected(String roomCode) async {
    await _writeWithRetry(
      () => realtime.ref('rooms/$roomCode/controllerPresence').update({
        'connected': false,
        'lastSeen': ServerValue.timestamp,
      }),
    );
  }

  /// 사용자가 명시적으로 방을 종료했을 때만 callable로 close 상태를 만듭니다.
  Future<void> closeControllerRoom(String roomCode) async {
    final roomRef = realtime.ref('rooms/$roomCode');
    try {
      await roomRef.child('controllerPresence').onDisconnect().cancel();
    } catch (_) {
      // 서버 close가 방 종료의 권위이므로 예약 취소 실패는 계속 진행합니다.
    }
    await _functions
        .httpsCallable('closeRoom')
        .call(controllerCommandData(roomCode));
    await ControllerRoomSessionStore.instance.clear(onlyRoomCode: roomCode);
  }

  /// 앱 재실행 뒤 로컬에 보존된 controller 세션으로 방을 복원합니다.
  Future<String?> restoreControllerRoom() async {
    final store = ControllerRoomSessionStore.instance;
    await store.load();
    final roomCode = store.roomCode;
    final sessionId = roomCode == null
        ? null
        : store.sessionIdForRoom(roomCode);
    if (roomCode == null || sessionId == null) return null;
    try {
      await _functions.httpsCallable('resumeRealtimeControllerRoom').call({
        'roomCode': roomCode,
        'controllerSessionId': sessionId,
      });
      await markControllerConnected(roomCode);
      return roomCode;
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'not-found' ||
          error.code == 'permission-denied' ||
          error.code == 'failed-precondition') {
        await store.clear(onlyRoomCode: roomCode);
        return null;
      }
      throw RoomCommandException(error.message ?? '기존 방을 복구하지 못했습니다.');
    }
  }

  /// `false`는 태블릿의 명시적 종료와 방 전체 삭제를 모두 의미합니다.
  Stream<bool?> watchControllerConnected(String roomCode) {
    return realtime
        .ref('rooms/$roomCode/controllerPresence/connected')
        .onValue
        .map((event) {
          final value = event.snapshot.value;
          return value is bool ? value : false;
        });
  }

  Stream<String?> watchRoomStatus(String roomCode) => realtime
      .ref('rooms/$roomCode/status')
      .onValue
      .map((event) => event.snapshot.value?.toString());

  Stream<List<RoomPlayer>> watchRoomPlayers(String roomCode) {
    return realtime
        .ref('rooms/$roomCode/players')
        .onValue
        .map((event) => _playersFromSnapshot(event.snapshot));
  }

  /// Firebase 서버와 이 앱 인스턴스의 실제 연결 상태입니다.
  Stream<bool> watchServerConnection() =>
      RealtimeConnectionMonitor.instance.watch(realtime);

  //게임 선택
  Future<void> selectGame({
    required String roomCode,
    required String gameId,
  }) async {
    await _functions
        .httpsCallable('selectRealtimeRoomGame')
        .call(controllerCommandData(roomCode, {'gameId': gameId}));
  }

  List<RoomPlayer> _playersFromSnapshot(DataSnapshot snapshot) {
    final value = snapshot.value;
    if (!snapshot.exists || value is! Map) {
      return const [];
    }

    return value.entries
        .where((entry) => entry.value is Map)
        .map(
          (entry) => RoomPlayer.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
            key: entry.key.toString(),
          ),
        )
        .where((player) => player.isPlayer && player.isActive)
        .toList(growable: false);
  }

  Future<void> savePlayerSeatIndexes({
    required String roomCode,
    required Map<String, int> seatIndexesByUid,
  }) async {
    await _functions.httpsCallable('saveRealtimePlayerSeatIndexes').call({
      ...controllerCommandData(roomCode),
      'seatIndexesByUid': seatIndexesByUid,
    });
  }

  Future<void> removePlayer(String roomCode, String userUid) async {
    await _functions
        .httpsCallable('removeRealtimeRoomPlayer')
        .call(controllerCommandData(roomCode, {'playerUid': userUid}));
  }

  // ========================================================== phone ==================================================================

  Future<void> joinRoom(
    String roomCode,
    String nickname, {
    required String accentColor,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const RoomCommandException('인증 정보가 없습니다.');
    }

    final uid = user.uid;
    final code = roomCode.trim().toUpperCase();
    await _joinRoomWithRetry(
      roomCode: code,
      nickname: nickname,
      accentColor: accentColor,
      preserveProfile: true,
    );

    // 참가 저장은 Cloud Function에서 완료됩니다. 접속 종료 표시는 보조
    // 기능이므로 클라이언트에서 한 번만 예약하고 실패해도 입장은 유지합니다.
    final playerRef = realtime.ref('rooms/$code/players/$uid');
    await _registerDisconnectPresence(playerRef);
  }

  /// 네트워크가 돌아온 플레이어의 presence와 onDisconnect 예약을 복원합니다.
  ///
  /// 먼저 다음 단절 예약을 등록한 뒤 서버에서 기존 UID를 merge하므로 seat와
  /// game/private 상태는 그대로 유지되고 `isConnected`만 true가 됩니다.
  Future<void> restorePlayerConnection({
    required String roomCode,
    required String nickname,
    required String accentColor,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const RoomCommandException('인증 정보가 없습니다.');
    }
    final code = roomCode.trim().toUpperCase();
    final playerRef = realtime.ref('rooms/$code/players/${user.uid}');
    await _registerDisconnectPresenceWithRetry(playerRef);
    await _joinRoomWithRetry(
      roomCode: code,
      nickname: nickname,
      accentColor: accentColor,
      preserveProfile: true,
    );
  }

  /// 저장된 세션이 실제로 현재 UID의 기존 참가자를 가리키는지 확인합니다.
  ///
  /// 이 확인 없이 join callable을 호출하면 대기 중인 방에서 강퇴된 사용자를 새
  /// 참가자로 다시 만들 수 있으므로, 자동 재접속 경로에서는 반드시 선행합니다.
  Future<bool> hasExistingPlayer(String roomCode) async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final code = roomCode.trim().toUpperCase();
    final snapshot = await _readWithRetry(
      realtime.ref('rooms/$code/players/${user.uid}'),
    );
    return snapshot.exists;
  }

  Future<void> heartbeatPlayer(String roomCode) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _writeWithRetry(
      () => realtime
          .ref('rooms/${roomCode.trim().toUpperCase()}/players/${user.uid}')
          .update({'isConnected': true, 'lastSeen': ServerValue.timestamp}),
    );
  }

  /// 이미 참가한 플레이어의 닉네임과 UI 색상만 갱신합니다.
  Future<void> updateRoomPlayerProfile(
    String roomCode,
    String nickname, {
    required String accentColor,
  }) => _joinRoomWithRetry(
    roomCode: roomCode.trim().toUpperCase(),
    nickname: nickname,
    accentColor: accentColor,
    preserveProfile: false,
  );

  Future<void> _joinRoomWithRetry({
    required String roomCode,
    required String nickname,
    required String accentColor,
    required bool preserveProfile,
  }) async {
    FirebaseFunctionsException? lastError;

    for (var attempt = 0; attempt < _functionOperationAttempts; attempt += 1) {
      try {
        await _functions.httpsCallable('joinRealtimeRoom').call({
          'roomCode': roomCode,
          'nickname': nickname,
          'accentColor': accentColor,
          'preserveProfile': preserveProfile,
        });
        return;
      } on FirebaseFunctionsException catch (error) {
        lastError = error;
        final shouldRetry =
            attempt < _functionOperationAttempts - 1 &&
            (error.code == 'not-found' ||
                error.code == 'aborted' ||
                error.code == 'internal' ||
                error.code == 'unavailable' ||
                error.code == 'deadline-exceeded');
        if (!shouldRetry) break;
        await Future<void>.delayed(Duration(milliseconds: 220 * (attempt + 1)));
      }
    }

    throw RoomCommandException(
      lastError?.message ?? '방에 참가하지 못했습니다. 잠시 후 다시 시도해주세요.',
    );
  }

  Future<void> leaveRoom(String roomCode) async {
    final user = _auth.currentUser;

    // user null 여부 검증
    if (user == null) {
      throw const RoomCommandException('인증 정보가 없습니다.');
    }
    // playerRef에
    final uid = user.uid;
    final code = roomCode.trim().toUpperCase();
    final roomRef = realtime.ref('rooms/$code');
    final playerRef = roomRef.child('players/$uid');

    // joinRoom의 연결 끊김 감지 트리거 취소
    // iOS 네이티브 플러그인의 onDisconnect 오류는 긴 unknown Stacktrace로
    // 전달될 수 있습니다. 취소 실패는 실제 퇴장 삭제를 막지 않게 합니다.
    try {
      await playerRef.onDisconnect().cancel();
    } catch (_) {
      // 아래 remove가 성공하면 예약된 update 대상도 사라지므로 계속 진행합니다.
    }

    await _functions.httpsCallable('leaveRealtimeRoom').call({
      'roomCode': code,
    });
  }

  /// 진행 중인 게임에서 퇴장합니다.
  ///
  /// 플레이어 삭제와 다음 턴 결정은 [cloudFunctionName]으로 지정한 게임별 Cloud
  /// Function 트랜잭션이 함께 처리하며, 클라이언트는 기존 연결 종료 예약만 먼저
  /// 취소합니다.
  Future<void> leaveGame({
    required String cloudFunctionName,
    required String roomCode,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const RoomCommandException('인증 정보가 없습니다.');
    }

    final code = roomCode.trim().toUpperCase();
    final playerRef = realtime.ref('rooms/$code/players/${user.uid}');
    try {
      await playerRef.onDisconnect().cancel();
    } catch (_) {
      // 서버 트랜잭션이 실제 플레이어 노드를 제거하므로 취소 실패만으로 막지 않습니다.
    }

    FirebaseFunctionsException? lastError;
    for (var attempt = 0; attempt < _functionOperationAttempts; attempt += 1) {
      try {
        await _functions.httpsCallable(cloudFunctionName).call({
          'roomCode': code,
        });
        return;
      } on FirebaseFunctionsException catch (error) {
        lastError = error;
        final shouldRetry =
            attempt < _functionOperationAttempts - 1 &&
            (error.code == 'aborted' ||
                error.code == 'internal' ||
                error.code == 'unavailable' ||
                error.code == 'deadline-exceeded');
        if (!shouldRetry) break;
        await Future<void>.delayed(Duration(milliseconds: 220 * (attempt + 1)));
      }
    }

    throw RoomCommandException(
      lastError?.message ?? '게임에서 퇴장하지 못했습니다. 잠시 후 다시 시도해주세요.',
    );
  }

  /// iOS에서 일시적인 native `unknown` 오류가 발생해도 같은 읽기를 재시도합니다.
  Future<DataSnapshot> _readWithRetry(DatabaseReference reference) async {
    Object? lastError;

    for (var attempt = 0; attempt < _databaseOperationAttempts; attempt += 1) {
      try {
        return await reference.get();
      } catch (error) {
        lastError = error;
        if (!_isTransientDatabaseError(error) ||
            attempt == _databaseOperationAttempts - 1) {
          break;
        }
        await Future<void>.delayed(Duration(milliseconds: 180 * (attempt + 1)));
      }
    }

    throw RoomCommandException(_databaseErrorMessage(lastError));
  }

  /// set/update/remove는 같은 값을 다시 적용해도 안전한 작업만 전달받습니다.
  Future<void> _writeWithRetry(Future<void> Function() operation) async {
    Object? lastError;

    for (var attempt = 0; attempt < _databaseOperationAttempts; attempt += 1) {
      try {
        await operation();
        return;
      } catch (error) {
        lastError = error;
        if (!_isTransientDatabaseError(error) ||
            attempt == _databaseOperationAttempts - 1) {
          break;
        }
        await Future<void>.delayed(Duration(milliseconds: 180 * (attempt + 1)));
      }
    }

    throw RoomCommandException(_databaseErrorMessage(lastError));
  }

  /// 접속 여부 표시는 보조 기능이므로 예약 실패가 방 입장을 중단시키지 않습니다.
  Future<void> _registerDisconnectPresence(DatabaseReference playerRef) async {
    try {
      await playerRef.onDisconnect().update({
        'isConnected': false,
        'lastSeen': ServerValue.timestamp,
      });
    } catch (_) {
      // 실시간 게임 데이터와 재접속은 UID 기준이므로 presence 예약 없이도 안전합니다.
    }
  }

  Future<void> _registerDisconnectPresenceWithRetry(
    DatabaseReference playerRef,
  ) async {
    Object? lastError;
    for (var attempt = 0; attempt < _databaseOperationAttempts; attempt += 1) {
      try {
        await playerRef.onDisconnect().update({
          'isConnected': false,
          'lastSeen': ServerValue.timestamp,
        });
        return;
      } catch (error) {
        lastError = error;
        if (attempt == _databaseOperationAttempts - 1) break;
        await Future<void>.delayed(Duration(milliseconds: 180 * (attempt + 1)));
      }
    }
    throw RoomCommandException(_databaseErrorMessage(lastError));
  }

  bool _isTransientDatabaseError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('firebase_database/unknown') ||
        message.contains('stacktrace:') ||
        message.contains('network') ||
        message.contains('disconnected') ||
        message.contains('unavailable') ||
        message.contains('timeout');
  }

  String _databaseErrorMessage(Object? error) {
    final message = error?.toString().toLowerCase() ?? '';
    if (message.contains('permission-denied')) {
      return '방에 접근할 권한이 없습니다.';
    }
    return '서버 연결이 불안정합니다. 잠시 후 다시 시도해주세요.';
  }
}
