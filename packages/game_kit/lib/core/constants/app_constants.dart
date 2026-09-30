// [app_constants.dart] 는 여러 게임이 함께 사용하는 앱 전체에서 반복 사용하는 고정값과 기준을 모아두는 파일이다.
//
// - [Package] : 게임 공통 기반
// - [Constant] : 앱 전체에서 반복 사용하는 고정값과 기준을 관리
//
// 즉, 같은 값을 여러 위치에서 다르게 정의하는 문제를 방지하기 위해 필요한 파일이다.

abstract final class AppConstants {
  static const appName = '모시겜';
  static const supportEmail = 'warmhandongne@gmail.com';

  /// 현재 빌드의 앱 버전입니다. Firestore 게임 문서의 `minAppVersion`과
  /// 비교해 이 빌드가 실행할 수 없는 게임을 걸러냅니다.
  ///
  /// ⚠️ `pubspec.yaml`의 `version:`(+빌드번호 제외)과 반드시 같아야 합니다.
  /// 어긋나면 `app_version_constant_test.dart`가 실패합니다.
  static const appVersion = '1.0.0';
}
