/// 휴대폰/태블릿이 함께 사용하는 발표 시간표입니다.
/// 값을 바꾸면 두 기기의 공개 순서가 함께 바뀝니다. 서버 제한시간은 별개입니다.
abstract final class MafiaPresentationTiming {
  static const morningOpening = Duration(milliseconds: 2500);
  static const morningDeaths = Duration(seconds: 8);
  static const exposure = Duration(seconds: 9);
  static const nextPhase = Duration(milliseconds: 2500);
  static const voteTally = Duration(seconds: 4);
  static const executionName = Duration(seconds: 4);
  static const executionReveal = Duration(seconds: 5);
  static const closing = Duration(seconds: 3);
}
