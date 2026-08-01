import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:project00/platform/dto/dto_firestore_value.dart';

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
    this.createdAt,
    this.updatedAt,
  });

  factory RoomData.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return RoomData.fromJson(
      snapshot.data() ?? const {},
      documentId: snapshot.id,
    );
  }

  factory RoomData.fromJson(Map<String, dynamic> json, {String? documentId}) {
    return RoomData(
      code: firestoreString(json['code'], fallback: documentId ?? ''),
      gameId: firestoreString(json['gameId']),
      hostUid: firestoreString(json['hostUid']),
      status: firestoreString(json['status'], fallback: 'waiting'),
      memberCount: firestoreInt(json['memberCount']),
      maxMembers: firestoreInt(json['maxMembers'], fallback: 6),
      selectedGameId: json['selectedGameId'] as String?,
      currentMatchId: json['currentMatchId'] as String?,
      createdAt: firestoreDateTime(json['createdAt']),
      updatedAt: firestoreDateTime(json['updatedAt']),
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
  final DateTime? createdAt;
  final DateTime? updatedAt;
}
