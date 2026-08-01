export 'package:project00/platform/lobby/models/room_data.dart';
export 'package:project00/platform/lobby/models/room_device.dart';
export 'package:project00/platform/lobby/models/room_member.dart';
export 'package:project00/platform/lobby/models/user_room.dart';

abstract final class RoomLimits {
  static const int defaultMaxMembers = 6;
}

class RoomCommandException implements Exception {
  const RoomCommandException(this.message);

  final String message;

  @override
  String toString() => message;
}
