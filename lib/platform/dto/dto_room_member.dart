import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:project00/platform/dto/dto_firestore_value.dart';

class RoomMember {
  const RoomMember({
    required this.uid,
    required this.nickname,
    required this.profileImageUrl,
    required this.isHost,
    required this.isReady,
    required this.role,
    required this.status,
    this.joinedAt,
    this.updatedAt,
  });

  factory RoomMember.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return RoomMember.fromJson(
      snapshot.data() ?? const {},
      documentId: snapshot.id,
    );
  }

  factory RoomMember.fromJson(Map<String, dynamic> json, {String? documentId}) {
    final isHost = json['isHost'] as bool? ?? false;

    return RoomMember(
      uid: firestoreString(json['uid'], fallback: documentId ?? ''),
      nickname: firestoreString(json['nickname'], fallback: '사용자'),
      profileImageUrl: firestoreString(json['profileImageUrl']),
      isHost: isHost,
      isReady: json['isReady'] as bool? ?? false,
      role: firestoreString(
        json['role'],
        fallback: isHost ? 'table' : 'player',
      ),
      status: firestoreString(json['status'], fallback: 'active'),
      joinedAt: firestoreDateTime(json['joinedAt']),
      updatedAt: firestoreDateTime(json['updatedAt']),
    );
  }

  final String uid;
  final String nickname;
  final String profileImageUrl;
  final bool isHost;
  final bool isReady;
  final String role;
  final String status;
  final DateTime? joinedAt;
  final DateTime? updatedAt;

  bool get isPlayer => role == 'player';
  bool get isActive => status == 'active';
}
