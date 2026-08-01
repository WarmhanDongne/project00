import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:project00/firebase/utils/firestore_value.dart';

class UserRoom {
  const UserRoom({
    required this.uid,
    required this.roomCode,
    this.createdAt,
    this.updatedAt,
  });

  factory UserRoom.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return UserRoom.fromJson(
      snapshot.data() ?? const {},
      documentId: snapshot.id,
    );
  }

  factory UserRoom.fromJson(Map<String, dynamic> json, {String? documentId}) {
    return UserRoom(
      uid: firestoreString(json['uid'], fallback: documentId ?? ''),
      roomCode: firestoreString(json['roomCode']),
      createdAt: firestoreDateTime(json['createdAt']),
      updatedAt: firestoreDateTime(json['updatedAt']),
    );
  }

  final String uid;
  final String roomCode;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}
