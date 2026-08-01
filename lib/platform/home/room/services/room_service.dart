import 'package:firebase_database/firebase_database.dart';
import 'package:project00/firebase/services/realtime_database_service.dart';
import 'package:project00/platform/home/room/models/ramdom.dart';

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
