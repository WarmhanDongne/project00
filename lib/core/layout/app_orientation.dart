import 'package:flutter/services.dart';

/// 플랫폼과 게임마다 사용하는 화면 방향 정책을 한곳에서 관리합니다.
abstract final class AppOrientation {
  /// 게임 선택·방 참여·자리 배치 등 플랫폼 화면은 세로로 고정합니다.
  static Future<void> lockPlatformPortrait() {
    return SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
    ]);
  }

  /// Liar's Poker는 세로와 양쪽 가로 회전을 모두 허용합니다.
  static Future<void> allowLiarsPokerRotation() {
    return SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  /// Final Call은 휴대폰과 태블릿 모두 가로로 고정합니다.
  static Future<void> lockFinalCallLandscape() {
    return SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }
}
