/// 방 명령에서 사용자에게 전달할 수 있는 오류 문구를 보존합니다.
class RoomCommandException implements Exception {
  const RoomCommandException(this.message);

  final String message;

  @override
  String toString() => message;
}
