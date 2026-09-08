/// 방 서비스가 사용자에게 전달할 수 있는 짧은 도메인 오류입니다.
class RoomCommandException implements Exception {
  const RoomCommandException(this.message);

  final String message;

  @override
  String toString() => message;
}
