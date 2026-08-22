abstract final class AppConstants {
  static const appName = '모시겜';
  static const supportEmail = 'support@example.com';

  /// 현재 빌드의 앱 버전입니다. Firestore 게임 문서의 `minAppVersion`과
  /// 비교해 이 빌드가 실행할 수 없는 게임을 걸러냅니다.
  ///
  /// ⚠️ `pubspec.yaml`의 `version:`(+빌드번호 제외)과 반드시 같아야 합니다.
  /// 어긋나면 `app_version_constant_test.dart`가 실패합니다.
  static const appVersion = '1.0.0';
}
