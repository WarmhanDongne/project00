import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:project00/platform/home/room/services/room_common.dart';

abstract interface class RoomQueryService {
  Stream<RoomData?> watchRoom(String roomCode);
  Stream<List<RoomMember>> watchMembers(String roomCode);
  Stream<List<RoomDevice>> watchDevices(String roomCode);
  Stream<UserRoom?> watchUserRoom(String uid);
}

class FirebaseRoomQueryService implements RoomQueryService {
  FirebaseRoomQueryService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
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

  @override
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
              .where((member) => member.isPlayer)
              .toList(growable: false),
        );
  }

  @override
  Stream<List<RoomDevice>> watchDevices(String roomCode) {
    return _firestore
        .collection('rooms')
        .doc(roomCode)
        .collection('devices')
        .orderBy('registeredAt')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(RoomDevice.fromSnapshot)
              .toList(growable: false),
        );
  }

  @override
  Stream<UserRoom?> watchUserRoom(String uid) {
    return _firestore
        .collection('userRooms')
        .doc(uid)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.exists ? UserRoom.fromSnapshot(snapshot) : null,
        );
  }
}
