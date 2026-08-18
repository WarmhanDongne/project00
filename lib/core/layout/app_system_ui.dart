import 'package:flutter/services.dart';

/// 플랫폼 화면과 게임 화면의 시스템 상태바 정책을 한곳에서 관리합니다.
///
/// 자리 배치부터 게임 종료까지는 전체 화면을 유지하고, 플랫폼 홈으로 돌아오면
/// 위·아래 시스템 영역을 모두 복원합니다. 게임별 화면에서 직접 다른 모드를
/// 지정하지 말고 이 API만 사용합니다.
abstract final class AppSystemUi {
  //================상태바 표시=================
  /// 자리 배치 및 게임 화면에서 상태바와 내비게이션 바를 숨깁니다.
  static Future<void> enterGameFullscreen() {
    return SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  //================상태바 표시=================
  /// 게임을 나와 플랫폼 화면으로 돌아왔을 때 시스템 바를 다시 표시합니다.
  static Future<void> showPlatformSystemBars() {
    return SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
  }
}
