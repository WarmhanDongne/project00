import 'dart:async';

import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// 플랫폼 화면과 게임 화면의 시스템 상태바 정책을 한곳에서 관리합니다.
///
/// 자리 배치부터 게임 종료까지는 전체 화면을 유지하고, 플랫폼 홈으로 돌아오면
/// 위·아래 시스템 영역을 모두 복원합니다. 게임별 화면에서 직접 다른 모드를
/// 지정하지 말고 이 API만 사용합니다.
abstract final class AppSystemUi {
  //================상태바 표시=================
  /// 자리 배치 및 게임 화면에서 상태바와 내비게이션 바를 숨깁니다.
  ///
  /// 게임 중에는 입력이 한동안 없어도(태블릿 관전, 상대 턴 대기) 화면이
  /// 절전으로 꺼지지 않도록 화면 켜짐 잠금도 함께 겁니다.
  static Future<void> enterGameFullscreen() {
    unawaited(_setWakelock(true));
    return SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  //================상태바 표시=================
  /// 게임을 나와 플랫폼 화면으로 돌아왔을 때 시스템 바를 다시 표시하고
  /// 화면 켜짐 잠금을 해제해 기기 절전 설정을 원래대로 되돌립니다.
  static Future<void> showPlatformSystemBars() {
    unawaited(_setWakelock(false));
    return SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
  }

  static Future<void> _setWakelock(bool enabled) async {
    try {
      await WakelockPlus.toggle(enable: enabled);
    } catch (_) {
      // 일부 플랫폼·테스트 환경에서 잠금이 지원되지 않아도 화면 전환과
      // 게임 진행을 막지 않습니다.
    }
  }
}
