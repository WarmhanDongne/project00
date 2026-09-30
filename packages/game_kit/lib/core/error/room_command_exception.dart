// [room_command_exception.dart] 는 여러 게임이 함께 사용하는 앱과 게임에서 발생하는 오류를 공통 형태로 정리하는 파일이다.
//
// - [Package] : 게임 공통 기반
// - [Error] : 앱과 게임에서 발생하는 오류를 공통 형태로 정리함
//
// 즉, 내부 오류를 사용자 메시지와 복구 판단으로 연결하기 위해 필요한 파일이다.

/// 방 서비스가 사용자에게 전달할 수 있는 짧은 도메인 오류입니다.
class RoomCommandException implements Exception {
  const RoomCommandException(this.message);

  final String message;

  @override
  String toString() => message;
}
