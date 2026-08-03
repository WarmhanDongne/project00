import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:project00/firebase/services/realtime_database_service.dart';
import 'package:project00/platform/home/room/services/room_common.dart';

abstract interface class PhoneRoomCommandService {
  Future<void> joinRoom(String roomCode);

  Future<void> setReady({required String roomCode, required bool isReady});

  Future<void> leaveRoom(String roomCode);
}

class RtdbPhoneRoomCommandService implements PhoneRoomCommandService {
  RtdbPhoneRoomCommandService({FirebaseDatabase? database, FirebaseAuth? auth})
    : _database = database ?? RealtimeDatabaseService.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseDatabase _database;
  final FirebaseAuth _auth;

  @override
  Future<void> joinRoom(String roomCode) async {
    // 유저 객체 생성 및 유저 존재 테스트
    final user = _auth.currentUser;
    if (user == null) {
      throw const RoomCommandException('인증 정보가 없습니다.');
    }

    final uid = user.uid;
    final code = roomCode.trim().toUpperCase();
    final roomRef = _database.ref('rooms/$code');

    // 메모리 세션 존재를 단발성 조회
    final snapshot = await roomRef.get();
    if (!snapshot.exists) {
      throw const RoomCommandException('방을 찾을 수 없습니다.');
    }

    final data = snapshot.value as Map<dynamic, dynamic>;
    final maxMembers =
        data['maxMembers'] as int? ?? RoomLimits.defaultMaxMembers;

    final playersSnapshot = await roomRef.child('players').get();
    final currentMembers = playersSnapshot.children.length;

    if (currentMembers >= maxMembers) {
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

  @override
  Future<void> leaveRoom(String roomCode) {
    // TODO: implement leaveRoom
    throw UnimplementedError();
  }

  @override
  Future<void> setReady({required String roomCode, required bool isReady}) {
    // TODO: implement setReady
    throw UnimplementedError();
  }
}
