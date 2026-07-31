import 'package:cloud_functions/cloud_functions.dart';
import 'package:project00/platform/hub/services/room_models.dart';

abstract interface class TabletRoomCommandService {
  Future<String> createOrLoadRoom({
    int maxMembers = RoomLimits.defaultMaxMembers,
  });

  Future<String> resetRoom({int maxMembers = RoomLimits.defaultMaxMembers});

  Future<void> selectGame({required String roomCode, required String gameId});
}

class FirebaseTabletRoomCommandService implements TabletRoomCommandService {
  FirebaseTabletRoomCommandService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'asia-northeast3');

  final FirebaseFunctions _functions;

  @override
  Future<String> createOrLoadRoom({
    int maxMembers = RoomLimits.defaultMaxMembers,
  }) async {
    final data = await _call('createOrLoadRoom', <String, Object?>{
      'clientType': 'tablet',
      'maxMembers': maxMembers,
    });
    final roomCode = data['roomCode'];
    if (roomCode is! String || roomCode.isEmpty) {
      throw const RoomCommandException('방 코드를 확인할 수 없습니다.');
    }
    return roomCode;
  }

  @override
  Future<String> resetRoom({
    int maxMembers = RoomLimits.defaultMaxMembers,
  }) async {
    await _call('resetRoom', const <String, Object?>{'clientType': 'tablet'});
    return createOrLoadRoom(maxMembers: maxMembers);
  }

  @override
  Future<void> selectGame({
    required String roomCode,
    required String gameId,
  }) async {
    await _call('selectRoomGame', <String, Object?>{
      'roomCode': roomCode,
      'gameId': gameId,
    });
  }

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, Object?> data,
  ) async {
    try {
      final result = await _functions.httpsCallable(name).call(data);
      final value = result.data;
      if (value is Map) {
        return Map<String, dynamic>.from(value);
      }
      return const <String, dynamic>{};
    } on FirebaseFunctionsException catch (error) {
      throw RoomCommandException(error.message ?? '방 요청에 실패했습니다.');
    }
  }
}
