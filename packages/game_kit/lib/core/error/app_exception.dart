// [app_exception.dart] 는 여러 게임이 함께 사용하는 앱과 게임에서 발생하는 오류를 공통 형태로 정리하는 파일이다.
//
// - [Package] : 게임 공통 기반
// - [Error] : 앱과 게임에서 발생하는 오류를 공통 형태로 정리함
//
// 즉, 내부 오류를 사용자 메시지와 복구 판단으로 연결하기 위해 필요한 파일이다.

//==========[ 앱 공통 예외 ]==========
class AppException implements Exception {
  const AppException(this.message, {this.cause});

  //[안내문구] 화면이나 상위 계층에서 사용할 오류 설명
  final String message;

  //[원본오류] 실제로 예외를 일으킨 값이 있으면 함께 보관
  final Object? cause;

  @override
  //[로그표시] 예외 종류와 설명을 한 줄로 출력
  String toString() => 'AppException: $message';
}
