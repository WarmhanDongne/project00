import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:project00/platform/hub/services/room_models.dart';

abstract interface class RoomQueryService {
  Stream<RoomData?> watchRoom(String roomCode);
  Stream<List<RoomMember>> watchMembers(String roomCode);
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
}
