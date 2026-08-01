import 'package:cloud_functions/cloud_functions.dart';
import 'package:project00/platform/hub/services/room_models.dart';

abstract interface class MobileRoomCommandService {
  Future<void> joinRoom(String roomCode);

  Future<void> setReady({required String roomCode, required bool isReady});

  Future<void> leaveRoom(String roomCode);
}

class FirebaseMobileRoomCommandService implements MobileRoomCommandService {
  FirebaseMobileRoomCommandService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'asia-northeast3');

  final FirebaseFunctions _functions;

  @override
  Future<void> joinRoom(String roomCode) {
    return _call('joinRoom', <String, Object?>{'roomCode': roomCode});
  }

  @override
  Future<void> setReady({required String roomCode, required bool isReady}) {
    return _call('setRoomReady', <String, Object?>{
      'roomCode': roomCode,
      'isReady': isReady,
    });
  }

  @override
  Future<void> leaveRoom(String roomCode) {
    return _call('leaveRoom', <String, Object?>{'roomCode': roomCode});
  }

  Future<void> _call(String name, Map<String, Object?> data) async {
    try {
      await _functions.httpsCallable(name).call(data);
    } on FirebaseFunctionsException catch (error) {
      throw RoomCommandException(error.message ?? '방 요청에 실패했습니다.');
    }
  }
}
