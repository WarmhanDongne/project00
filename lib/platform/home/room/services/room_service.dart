import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:project00/firebase/services/realtime_database_service.dart';
import 'package:project00/platform/home/room/services/room_common.dart';

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

      if (roomCode == null || roomCode.isEmpty) {
        throw const RoomCommandException('생성된 방 코드를 확인할 수 없습니다.');
      }

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

  Stream<List<RoomPlayer>> watchRoomPlayers(String roomCode) {
    return realtime
        .ref('rooms/$roomCode/players')
        .onValue
        .map((event) => _playersFromSnapshot(event.snapshot));
  }

  //게임 선택
  Future<void> selectGame({
    required String roomCode,
    required String gameId,
  }) async {
    await _writeWithRetry(
      () => realtime.ref('rooms/$roomCode').update({'selectedGame': gameId}),
    );
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
      'roomCode': roomCode,
      'seatIndexesByUid': seatIndexesByUid,
    });
  }

  Future<void> removePlayer(String roomCode, String userUid) async {
    await _writeWithRetry(
      () => realtime.ref('rooms/$roomCode/players/$userUid').remove(),
    );
  }

  // ========================================================== phone ==================================================================

  Future<void> joinRoom(String roomCode, String nickname) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const RoomCommandException('인증 정보가 없습니다.');
    }

    final uid = user.uid;
    final code = roomCode.trim().toUpperCase();
    await _joinRoomWithRetry(roomCode: code, nickname: nickname);

    // 참가 저장은 Cloud Function에서 완료됩니다. 접속 종료 표시는 보조
    // 기능이므로 클라이언트에서 한 번만 예약하고 실패해도 입장은 유지합니다.
    final playerRef = realtime.ref('rooms/$code/players/$uid');
    await _registerDisconnectPresence(playerRef);
  }

  Future<void> _joinRoomWithRetry({
    required String roomCode,
    required String nickname,
  }) async {
    FirebaseFunctionsException? lastError;

    for (var attempt = 0; attempt < _functionOperationAttempts; attempt += 1) {
      try {
        await _functions.httpsCallable('joinRealtimeRoom').call({
          'roomCode': roomCode,
          'nickname': nickname,
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

    // 플레이어 노드 즉시 삭제
    await _writeWithRetry(playerRef.remove);
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
      await playerRef.onDisconnect().update({'isConnected': false});
    } catch (_) {
      // 실시간 게임 데이터와 재접속은 UID 기준이므로 presence 예약 없이도 안전합니다.
    }
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
