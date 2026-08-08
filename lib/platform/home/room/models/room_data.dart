import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:project00/firebase/utils/firestore_value.dart';

class RoomData {
  const RoomData({
    required this.code,
    required this.gameId,
    required this.controllerUid,
    required this.status,
    required this.playerCount,
    required this.maxplayers,
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
      controllerUid: firestoreString(
        json['controllerUid'],
        fallback: firestoreString(json['hostUid']),
      ),
      status: firestoreString(json['status'], fallback: 'waiting'),
      playerCount: firestoreInt(json['playerCount']),
      maxplayers: firestoreInt(json['maxplayers'], fallback: 6),
      selectedGameId: json['selectedGameId'] as String?,
      currentMatchId: json['currentMatchId'] as String?,
      createdAt: firestoreDateTime(json['createdAt']),
      updatedAt: firestoreDateTime(json['updatedAt']),
    );
  }

  final String code;
  final String gameId;
  final String controllerUid;
  final String status;
  final int playerCount;
  final int maxplayers;
  final String? selectedGameId;
  final String? currentMatchId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}
