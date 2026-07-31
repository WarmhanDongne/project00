import 'package:cloud_firestore/cloud_firestore.dart';

abstract final class RoomLimits {
  static const int defaultMaxMembers = 6;
}

class RoomCommandException implements Exception {
  const RoomCommandException(this.message);

  final String message;

  @override
  String toString() => message;
}

class RoomData {
  const RoomData({
    required this.code,
    required this.gameId,
    required this.hostUid,
    required this.status,
    required this.memberCount,
    required this.maxMembers,
    required this.selectedGameId,
    required this.currentMatchId,
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
      maxMembers: data['maxMembers'] as int? ?? RoomLimits.defaultMaxMembers,
      selectedGameId: data['selectedGameId'] as String?,
      currentMatchId: data['currentMatchId'] as String?,
    );
  }

  final String code;
  final String gameId;
  final String hostUid;
  final String status;
  final int memberCount;
  final int maxMembers;
  final String? selectedGameId;
  final String? currentMatchId;
}

class RoomMember {
  const RoomMember({
    required this.uid,
    required this.nickname,
    required this.profileImageUrl,
    required this.isHost,
    required this.isReady,
    required this.role,
    required this.status,
  });

  factory RoomMember.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    final isHost = data['isHost'] as bool? ?? false;

    return RoomMember(
      uid: snapshot.id,
      nickname: data['nickname'] as String? ?? '사용자',
      profileImageUrl: data['profileImageUrl'] as String? ?? '',
      isHost: isHost,
      isReady: data['isReady'] as bool? ?? false,
      role: data['role'] as String? ?? (isHost ? 'table' : 'player'),
      status: data['status'] as String? ?? 'active',
    );
  }

  final String uid;
  final String nickname;
  final String profileImageUrl;
  final bool isHost;
  final bool isReady;
  final String role;
  final String status;

  bool get isPlayer => role == 'player';
  bool get isActive => status == 'active';
}
