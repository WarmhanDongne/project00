import 'package:flutter/foundation.dart';

@immutable
class RoomSessionIdentity {
  const RoomSessionIdentity({
    required this.uid,
    required this.role,
    required this.roomCode,
    required this.roomInstanceId,
    required this.connectionId,
    required this.connectionSeq,
    this.membershipId,
    this.controllerSessionId,
  });

  factory RoomSessionIdentity.fromJson(Map<String, dynamic> json) {
    final identity = RoomSessionIdentity(
      uid: json['uid'] as String,
      role: json['role'] as String,
      roomCode: (json['roomCode'] as String).trim().toUpperCase(),
      roomInstanceId: json['roomInstanceId'] as String,
      connectionId: json['connectionId'] as String,
      connectionSeq: (json['connectionSeq'] as num).toInt(),
      membershipId: json['membershipId'] as String?,
      controllerSessionId: json['controllerSessionId'] as String?,
    );
    if (identity.uid.isEmpty ||
        !const {'player', 'controller'}.contains(identity.role) ||
        identity.roomInstanceId.isEmpty ||
        identity.connectionId.isEmpty ||
        identity.connectionSeq < 1 ||
        (identity.role == 'player' &&
            (identity.membershipId?.isEmpty ?? true))) {
      throw const FormatException('Invalid room session identity');
    }
    return identity;
  }

  final String uid;
  final String role;
  final String roomCode;
  final String roomInstanceId;
  final String? membershipId;
  final String? controllerSessionId;
  final String connectionId;
  final int connectionSeq;

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'role': role,
    'roomCode': roomCode,
    'roomInstanceId': roomInstanceId,
    'connectionId': connectionId,
    'connectionSeq': connectionSeq,
    if (membershipId != null) 'membershipId': membershipId,
    'controllerSessionId': ?controllerSessionId,
  };

  Map<String, dynamic> get envelope => {
    'role': role,
    'roomCode': roomCode,
    'roomInstanceId': roomInstanceId,
    'connectionId': connectionId,
    'connectionSeq': connectionSeq,
    if (membershipId != null) 'membershipId': membershipId,
    'controllerSessionId': ?controllerSessionId,
  };
}
