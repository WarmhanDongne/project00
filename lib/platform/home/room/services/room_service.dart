import 'package:firebase_database/firebase_database.dart';
import 'package:project00/firebase/services/realtime_database_service.dart';
import 'package:project00/platform/home/room/models/ramdom.dart';
import 'package:project00/platform/home/room/models/room_member.dart';

class RoomService {
  final FirebaseDatabase realtime = RealtimeDatabaseService.instance;

  Future<String> createRoom() async {
    while (true) {
      final code = RoomCodeGenerator.generate();

      final snapshot = await realtime.ref('rooms/$code').get();

      if (!snapshot.exists) {
        await realtime.ref('rooms/$code').set({
          'roomCode': code,
          'createdAt': ServerValue.timestamp,
        });

        return code;
      }
    }
  }

  Future<List<RoomMember>> getRoomPlayers(String roomCode) async {
    final realtime = FirebaseDatabase.instance;

    final snapshot = await realtime.ref('rooms/$roomCode/players').get();

    if (!snapshot.exists) return [];

    final data = Map<String, dynamic>.from(snapshot.value as Map);

    return data.entries.map((entry) {
      return RoomMember.fromJson(Map<String, dynamic>.from(entry.value));
    }).toList();
  }

  Stream<DatabaseEvent> watchRoom(String roomCode) {
    return realtime.ref('rooms/$roomCode').onValue;
  }

  Future<void> selectGame({
    required String roomCode,
    required String gameId,
  }) async {
    await realtime.ref('rooms/$roomCode').update({'selectedGame': gameId});
  }
}
