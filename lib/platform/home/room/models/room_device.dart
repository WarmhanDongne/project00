import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:project00/firebase/utils/firestore_value.dart';

class RoomDevice {
  const RoomDevice({
    required this.uid,
    required this.role,
    this.registeredAt,
    this.updatedAt,
  });

  factory RoomDevice.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return RoomDevice.fromJson(
      snapshot.data() ?? const {},
      documentId: snapshot.id,
    );
  }

  factory RoomDevice.fromJson(Map<String, dynamic> json, {String? documentId}) {
    return RoomDevice(
      uid: firestoreString(json['uid'], fallback: documentId ?? ''),
      role: firestoreString(json['role'], fallback: 'table'),
      registeredAt: firestoreDateTime(json['registeredAt']),
      updatedAt: firestoreDateTime(json['updatedAt']),
    );
  }

  final String uid;
  final String role;
  final DateTime? registeredAt;
  final DateTime? updatedAt;

  bool get isTable => role == 'table';
}
