import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:project00/firebase/services/realtime_database_service.dart';
import 'package:project00/platform/home/room/models/ramdom.dart';
import 'package:project00/platform/home/room/models/room_player.dart';

class RoomService {
  RoomService({
    FirebaseDatabase? database,
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
  }) : realtime = database ?? RealtimeDatabaseService.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _functions =
           functions ??
           FirebaseFunctions.instanceFor(region: 'asia-northeast3');

  final FirebaseDatabase realtime;
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  Future<String> createRoom() async {
    final hostUid = _auth.currentUser?.uid;
    if (hostUid == null) {
      throw StateError('방을 만들려면 로그인이 필요합니다.');
    }

    while (true) {
      final code = RoomCodeGenerator.generate();

      final snapshot = await realtime.ref('rooms/$code').get();

      if (!snapshot.exists) {
        await realtime.ref('rooms/$code').set({
          'roomCode': code,
          'hostUid': hostUid,
          'createdAt': ServerValue.timestamp,
        });

        return code;
      }
    }
  }

  Future<List<RoomMember>> getRoomPlayers(String roomCode) async {
    final snapshot = await realtime.ref('rooms/$roomCode/players').get();
    return _membersFromSnapshot(snapshot);
  }

  Stream<DatabaseEvent> watchRoom(String roomCode) {
    return realtime.ref('rooms/$roomCode').onValue;
  }

  Stream<List<RoomMember>> watchRoomPlayers(String roomCode) {
    return realtime
        .ref('rooms/$roomCode/players')
        .onValue
        .map((event) => _membersFromSnapshot(event.snapshot));
  }

  //게임 선택
  Future<void> selectGame({
    required String roomCode,
    required String gameId,
  }) async {
    await realtime.ref('rooms/$roomCode').update({'selectedGame': gameId});
  }

  List<RoomMember> _membersFromSnapshot(DataSnapshot snapshot) {
    final value = snapshot.value;
    if (!snapshot.exists || value is! Map) {
      return const [];
    }

    return value.entries
        .where((entry) => entry.value is Map)
        .map(
          (entry) => RoomMember.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
            documentId: entry.key.toString(),
          ),
        )
        .where((member) => member.isPlayer && member.isActive)
        .toList(growable: false);
  }

  Future<void> savePlayerSeatIndexes({
    required String roomCode,
    required Map<String, int> seatIndexesByUid,
  }) async {
    await _functions.httpsCallable('saveRealtimePlayerSeatIndexes').call({
      'roomCode': roomCode,
      'seatIndexesByUid': seatIndexesByUid,
    });
  }

  Future<void> removePlayer(String roomCode,String userUid)async{
    await realtime.ref('rooms/$roomCode/players/$userUid').remove();
  }
}
