import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RoomServiceException implements Exception {
  const RoomServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _RoomCodeCollision implements Exception {
  const _RoomCodeCollision();
}

class RoomData {
  const RoomData({
    required this.code,
    required this.gameId,
    required this.hostUid,
    required this.status,
    required this.memberCount,
    required this.maxMembers,
  });

  factory RoomData.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return RoomData(
      code: snapshot.id,
      gameId: data['gameId'] as String? ?? '',
      hostUid: data['hostUid'] as String? ?? '',
      status: data['status'] as String? ?? 'waiting',
      memberCount: data['memberCount'] as int? ?? 0,
      maxMembers: data['maxMembers'] as int? ?? RoomService.defaultMaxMembers,
    );
  }

  final String code;
  final String gameId;
  final String hostUid;
  final String status;
  final int memberCount;
  final int maxMembers;
}

class RoomMember {
  const RoomMember({
    required this.uid,
    required this.nickname,
    required this.profileImageUrl,
    required this.isHost,
  });

  factory RoomMember.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    return RoomMember(
      uid: snapshot.id,
      nickname: data['nickname'] as String? ?? '사용자',
      profileImageUrl: data['profileImageUrl'] as String? ?? '',
      isHost: data['isHost'] as bool? ?? false,
    );
  }

  final String uid;
  final String nickname;
  final String profileImageUrl;
  final bool isHost;
}

class RoomService {
  RoomService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  static const int defaultMaxMembers = 6;
  static const String _roomCodeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  Future<String> ensurePersonalRoom({
    int maxMembers = defaultMaxMembers,
  }) async {
    final user = _requireUser();

    final personalRoomRef = _firestore.collection('userRooms').doc(user.uid);

    for (var attempt = 0; attempt < 20; attempt++) {
      final candidateCode = _generateRoomCode();
      try {
        return await _firestore.runTransaction<String>((transaction) async {
          final personalRoomSnapshot = await transaction.get(personalRoomRef);
          final savedCode = personalRoomSnapshot.data()?['roomCode'] as String?;
          final roomCode = savedCode ?? candidateCode;
          final roomRef = _firestore.collection('rooms').doc(roomCode);
          final memberRef = roomRef.collection('members').doc(user.uid);
          final roomSnapshot = await transaction.get(roomRef);
          final memberSnapshot = await transaction.get(memberRef);

          if (savedCode == null && roomSnapshot.exists) {
            throw const _RoomCodeCollision();
          }

          if (!personalRoomSnapshot.exists) {
            transaction.set(personalRoomRef, {
              'uid': user.uid,
              'roomCode': roomCode,
              'createdAt': FieldValue.serverTimestamp(),
            });
          }

          if (!roomSnapshot.exists) {
            transaction.set(roomRef, {
              'code': roomCode,
              'hostUid': user.uid,
              'status': 'waiting',
              'memberCount': 1,
              'maxMembers': maxMembers,
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }

          if (!memberSnapshot.exists) {
            transaction.set(memberRef, _memberData(user: user, isHost: true));
          }

          return roomCode;
        });
      } on _RoomCodeCollision {
        continue;
      } on FirebaseException catch (error) {
        throw RoomServiceException(error.message ?? '개인 방을 불러오지 못했습니다.');
      }
    }

    throw const RoomServiceException('개인 방 코드를 생성하지 못했습니다.');
  }

  Future<void> joinRoom(String rawRoomCode) async {
    final user = _requireUser();
    final roomCode = rawRoomCode.trim().toUpperCase();
    if (roomCode.isEmpty) {
      throw const RoomServiceException('방 코드를 입력해주세요.');
    }

    final roomRef = _firestore.collection('rooms').doc(roomCode);
    final memberRef = roomRef.collection('members').doc(user.uid);

    try {
      await _firestore.runTransaction((transaction) async {
        final roomSnapshot = await transaction.get(roomRef);
        if (!roomSnapshot.exists) {
          throw const RoomServiceException('존재하지 않는 방입니다.');
        }

        final roomData = roomSnapshot.data()!;
        if ((roomData['status'] as String? ?? 'waiting') != 'waiting') {
          throw const RoomServiceException('이미 게임이 시작된 방입니다.');
        }

        final memberSnapshot = await transaction.get(memberRef);
        if (memberSnapshot.exists) return;

        final memberCount = roomData['memberCount'] as int? ?? 0;
        final maxMembers = roomData['maxMembers'] as int? ?? defaultMaxMembers;
        if (memberCount >= maxMembers) {
          throw const RoomServiceException('방이 가득 찼습니다.');
        }

        transaction.set(memberRef, _memberData(user: user, isHost: false));
        transaction.update(roomRef, {
          'memberCount': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } on RoomServiceException {
      rethrow;
    } on FirebaseException catch (error) {
      throw RoomServiceException(error.message ?? '방 입장에 실패했습니다.');
    }
  }

  Future<void> leaveRoom(String roomCode) async {
    final user = _requireUser();
    final roomRef = _firestore.collection('rooms').doc(roomCode);
    final memberRef = roomRef.collection('members').doc(user.uid);

    try {
      await _firestore.runTransaction((transaction) async {
        final roomSnapshot = await transaction.get(roomRef);
        final memberSnapshot = await transaction.get(memberRef);
        if (!roomSnapshot.exists || !memberSnapshot.exists) return;

        final roomData = roomSnapshot.data()!;
        final isHost = roomData['hostUid'] == user.uid;

        if (isHost) {
          throw const RoomServiceException('개인 방의 방장은 방을 나갈 수 없습니다.');
        }

        transaction.delete(memberRef);
        transaction.update(roomRef, {
          'memberCount': FieldValue.increment(-1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } on RoomServiceException {
      rethrow;
    } on FirebaseException catch (error) {
      throw RoomServiceException(error.message ?? '방 나가기에 실패했습니다.');
    }
  }

  Stream<RoomData?> watchRoom(String roomCode) {
    return _firestore
        .collection('rooms')
        .doc(roomCode)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.exists ? RoomData.fromSnapshot(snapshot) : null,
        );
  }

  Stream<List<RoomMember>> watchMembers(String roomCode) {
    return _firestore
        .collection('rooms')
        .doc(roomCode)
        .collection('members')
        .orderBy('joinedAt')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(RoomMember.fromSnapshot)
              .toList(growable: false),
        );
  }

  Future<bool> roomExists(String roomCode) async {
    final snapshot = await _firestore.collection('rooms').doc(roomCode).get();
    return snapshot.exists;
  }

  User _requireUser() {
    final user = _auth.currentUser;
    if (user == null) {
      throw const RoomServiceException('로그인이 필요합니다.');
    }
    return user;
  }

  Map<String, Object?> _memberData({required User user, required bool isHost}) {
    final emailName = user.email?.split('@').first;
    return {
      'uid': user.uid,
      'nickname': user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : (emailName?.isNotEmpty == true ? emailName : '사용자'),
      'profileImageUrl': user.photoURL ?? '',
      'isHost': isHost,
      'joinedAt': FieldValue.serverTimestamp(),
    };
  }

  String _generateRoomCode() {
    final random = Random.secure();
    return List.generate(
      5,
      (_) => _roomCodeChars[random.nextInt(_roomCodeChars.length)],
    ).join();
  }
}
