import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:project00/firebase/services/realtime_database_service.dart';

class FinalCallService {
  FinalCallService({FirebaseFunctions? functions, FirebaseDatabase? database})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'asia-northeast3'),
      _database = database ?? RealtimeDatabaseService.instance;

  final FirebaseFunctions _functions;
  final FirebaseDatabase _database;

  Stream<DatabaseEvent> watchPublic(String roomCode) =>
      _database.ref('rooms/$roomCode/game/public').onValue;

  Stream<DatabaseEvent> watchHand(String roomCode, String uid) =>
      _database.ref('rooms/$roomCode/game/private/$uid').onValue;

  Future<Map<String, dynamic>> start(String roomCode, {bool restart = false}) =>
      _call('startFinalCallGame', {'roomCode': roomCode, 'restart': restart});

  Future<Map<String, dynamic>> completeDealing(String roomCode) =>
      _call('completeFinalCallDealing', {'roomCode': roomCode});

  Future<Map<String, dynamic>> draw(String roomCode, String source) => _call(
    'drawFinalCallCard',
    {'roomCode': roomCode, 'source': source, 'commandId': _id('draw')},
  );

  Future<Map<String, dynamic>> completeTurn(String roomCode, String? cardId) =>
      _call('completeFinalCallTurn', {
        'roomCode': roomCode,
        'replaceCardId': cardId,
        'commandId': _id('turn'),
      });

  Future<Map<String, dynamic>> call(String roomCode) =>
      _call('callFinalCall', {'roomCode': roomCode, 'commandId': _id('call')});

  Future<Map<String, dynamic>> nextRound(String roomCode) =>
      _call('startFinalCallNextRound', {'roomCode': roomCode});

  Future<Map<String, dynamic>> timeoutTurn(String roomCode) =>
      _call('timeoutFinalCallTurn', {'roomCode': roomCode});

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> data,
  ) async {
    FirebaseFunctionsException? lastError;
    for (var attempt = 0; attempt < 4; attempt++) {
      try {
        final response = await _functions.httpsCallable(name).call(data);
        return response.data is Map
            ? Map<String, dynamic>.from(response.data as Map)
            : const {};
      } on FirebaseFunctionsException catch (error) {
        lastError = error;
        if (attempt == 3 ||
            !const {
              'not-found',
              'aborted',
              'unavailable',
              'deadline-exceeded',
              'internal',
            }.contains(error.code)) {
          rethrow;
        }
        await Future<void>.delayed(Duration(milliseconds: 220 * (attempt + 1)));
      }
    }
    throw lastError ?? Exception('Final Call 요청 실패');
  }

  String _id(String prefix) =>
      '${prefix}_${DateTime.now().microsecondsSinceEpoch}';
}
