import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:project00/firebase/services/realtime_database_service.dart';
import 'package:project00/platform/home/room/models/random.dart';
import 'package:project00/platform/home/room/services/room_common.dart';

class RoomService {
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

  Future<String> createRoom() async {
    final hostUid = _auth.currentUser?.uid;
    if (hostUid == null) {
      throw const RoomCommandException('방을 만들려면 로그인이 필요합니다.');
    }

    while (true) {
      final code = RoomCodeGenerator.generate();

      final snapshot = await realtime.ref('rooms/$code').get();

      if (!snapshot.exists) {
        await realtime.ref('rooms/$code').set({
          'roomCode': code,
          'hostUid': hostUid,
          'createdAt': ServerValue.timestamp,
        });

        return code;
      }
    }
  }

  Future<List<RoomPlayer>> getRoomPlayers(String roomCode) async {
    final snapshot = await realtime.ref('rooms/$roomCode/players').get();
    return _playersFromSnapshot(snapshot);
  }

  Stream<DatabaseEvent> watchRoom(String roomCode) {
    return realtime.ref('rooms/$roomCode').onValue;
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
    await realtime.ref('rooms/$roomCode').update({'selectedGame': gameId});
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
    await realtime.ref('rooms/$roomCode/players/$userUid').remove();
  }

  // ========================================================== phone ==================================================================

  Future<void> joinRoom(String roomCode) async {
    // 유저 객체 생성 및 유저 존재 테스트
    final user = _auth.currentUser;
    if (user == null) {
      throw const RoomCommandException('인증 정보가 없습니다.');
    }

    final uid = user.uid;
    final code = roomCode.trim().toUpperCase();
    final roomRef = realtime.ref('rooms/$code');

    // 메모리 세션 존재를 단발성 조회
    final snapshot = await roomRef.get();
    if (!snapshot.exists) {
      throw const RoomCommandException('방을 찾을 수 없습니다.');
    }

    final data = snapshot.value as Map<dynamic, dynamic>;
    final maxplayers =
        data['maxplayers'] as int? ?? RoomLimits.defaultMaxPlayers;

    final playersSnapshot = await roomRef.child('players').get();
    final currentplayers = playersSnapshot.children.length;

    if (currentplayers >= maxplayers) {
      throw const RoomCommandException('방 인원이 초과되었습니다.');
    }

    final playerRef = roomRef.child('players/$uid');

    // 소켓 상태 모니터링
    // 데이터 쓰기 연산 이전에 서버 측 데몬에 disconnect 인터럽트를 선제적으로 예약
    await playerRef.onDisconnect().update({'isConnected': false});

    // 데이터 변이
    // 검증이 완료된 상태이므로 set() 연산을 통해 메모리 블록을 완전히 덮어씀
    await playerRef.set({
      'uid': uid,
      'nickname': user.displayName ?? 'Player',
      'profileImageUrl': user.photoURL ?? '',
      'isConnected': true,
      'seatIndex': -1,
      'role': 'player',
      'status': 'active',
    });
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
    await playerRef.onDisconnect().cancel();

    // 플레이어 노드 즉시 삭제
    await playerRef.remove();
  }
}
