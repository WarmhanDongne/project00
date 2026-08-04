import 'package:firebase_database/firebase_database.dart';
import 'package:project00/firebase/services/realtime_database_service.dart';
import 'package:project00/platform/home/room/services/room_common.dart';

abstract interface class RoomQueryService {
  Stream<RoomData?> watchRoom(String roomCode);
  Stream<List<RoomPlayer>> watchPlayers(String roomCode);
  Stream<List<RoomDevice>> watchDevices(String roomCode);
  Stream<UserRoom?> watchUserRoom(String uid);
}

class RtdbRoomQueryService implements RoomQueryService {
  RtdbRoomQueryService({FirebaseDatabase? database})
    : _database = database ?? RealtimeDatabaseService.instance;

  final FirebaseDatabase _database;

  @override
  Stream<RoomData?> watchRoom(String roomCode) {
    return _database.ref('rooms/$roomCode').onValue.map((event) {
      if (!event.snapshot.exists) return null;
      // rtdb 데이타를 Map으로 캐스팅
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      return RoomData.fromJson(data, documentId: roomCode);
    });
  }

  @override
  Stream<List<RoomPlayer>> watchPlayers(String roomCode) {
    return _database.ref('rooms/$roomCode/players').onValue.map((event) {
      if (!event.snapshot.exists) return [];
      final data = event.snapshot.value as Map<dynamic, dynamic>;

      return data.entries.map((entry) {
        final playerData = Map<String, dynamic>.from(entry.value as Map);
        return RoomPlayer.fromJson(playerData, key: entry.key as String);
      }).toList();
    });
  }

  @override
  Stream<List<RoomDevice>> watchDevices(String roomCode) {
    // return _firestore
    //     .collection('rooms')
    //     .doc(roomCode)
    //     .collection('devices')
    //     .orderBy('registeredAt')
    //     .snapshots()
    //     .map(
    //       (snapshot) => snapshot.docs
    //           .map(RoomDevice.fromSnapshot)
    //           .toList(growable: false),
    //     );
    return const Stream.empty();
  }

  @override
  Stream<UserRoom?> watchUserRoom(String uid) {
    // return _firestore
    //     .collection('userRooms')
    //     .doc(uid)
    //     .snapshots()
    //     .map(
    //       (snapshot) =>
    //           snapshot.exists ? UserRoom.fromSnapshot(snapshot) : null,
    //     );
    return const Stream.empty();
  }
}
