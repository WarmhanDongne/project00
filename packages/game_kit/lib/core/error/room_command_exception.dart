// [error message] 외부에서 주입 받은 에러 메세지를 전달한다.
class RoomCommandException implements Exception {
  const RoomCommandException(this.message);

  final String message;

  @override
  String toString() => message;
}
