export 'package:project00/platform/home/room/models/room_data.dart';
export 'package:project00/platform/home/room/models/room_device.dart';
export 'package:project00/platform/home/room/models/room_player.dart';
export 'package:project00/platform/home/room/models/user_room.dart';

abstract final class RoomLimits {
  static const int defaultMaxMembers = 6;
}

class RoomCommandException implements Exception {
  const RoomCommandException(this.message);

  final String message;

  @override
  String toString() => message;
}
