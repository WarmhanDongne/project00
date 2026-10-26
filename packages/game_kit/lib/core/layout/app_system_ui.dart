// [app_system_ui.dart] 는 여러 게임이 함께 사용하는 기기 종류·화면 방향·시스템 UI 기준을 관리하는 파일이다.
//
// - [Package] : 게임 공통 기반
// - [Layout] : 기기 종류·화면 방향·시스템 UI 기준을 관리함
//
// 즉, 휴대폰과 태블릿 화면을 일관된 규칙으로 배치하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

// ============================================================

/// 플랫폼 화면과 게임 화면의 시스템 상태바 정책을 한곳에서 관리합니다.
///
/// 태블릿 플랫폼과 게임은 같은 전체 화면 영역을 유지하고, 휴대폰 플랫폼은
/// 시스템 영역을 표시합니다. 게임별 화면에서 직접 다른 모드를 지정하지 말고
/// 이 API만 사용합니다.
abstract final class AppSystemUi {
  static bool _gameScreenActive = false;
  static final Set<Object> _roomHolders = <Object>{};

  //================방 참여 중 화면 켜짐=================
  /// 방에 들어가 있는 동안은 로비·대기실에서도 화면이 꺼지지 않게 합니다.
  ///
  /// 대기실이나 자리 배치를 기다리는 동안 화면이 꺼지면 앱이 백그라운드로
  /// 내려가 연결이 끊기고, 게임 시작을 놓치거나 방에서 나가게 됩니다.
  /// [holder]마다 따로 기록하므로 방 상태를 가진 객체가 여럿이어도 모두
  /// 방을 나가야 잠금이 풀립니다. 방 밖의 로비는 기기 절전 설정을 따릅니다.
  static void setInRoom(Object holder, bool inRoom) {
    final changed = inRoom
        ? _roomHolders.add(holder)
        : _roomHolders.remove(holder);
    if (changed) unawaited(_applyWakelock());
  }

  /// 지금 화면 켜짐 잠금을 걸어야 하는지입니다.
  @visibleForTesting
  static bool get keepsScreenOn => _gameScreenActive || _roomHolders.isNotEmpty;

  @visibleForTesting
  static void resetForTesting() {
    _gameScreenActive = false;
    _roomHolders.clear();
  }

  //================태블릿 플랫폼 전체 화면=================
  /// 태블릿 로비를 전체 화면으로 유지하되, 방이 없으면 화면 켜짐 잠금을 풉니다.
  ///
  /// 로비와 자리 배치가 같은 viewport를 쓰므로 진입 순간 안전 영역과 요소 크기가
  /// 다시 계산되지 않습니다. 방이 열려 있으면 [setInRoom] 때문에 계속 켜 두고,
  /// 방이 없으면 기기 절전 설정을 그대로 따릅니다.
  static Future<void> enterTabletPlatformFullscreen() {
    _gameScreenActive = false;
    unawaited(_applyWakelock());
    return SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  //================상태바 표시=================
  /// 자리 배치 및 게임 화면에서 상태바와 내비게이션 바를 숨깁니다.
  ///
  /// 게임 중에는 입력이 한동안 없어도(태블릿 관전, 상대 턴 대기) 화면이
  /// 절전으로 꺼지지 않도록 화면 켜짐 잠금도 함께 겁니다.
  static Future<void> enterGameFullscreen() {
    _gameScreenActive = true;
    unawaited(_applyWakelock());
    return SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  //================상태바 표시=================
  /// 휴대폰 플랫폼 화면으로 돌아왔을 때 시스템 바를 다시 표시합니다. 방
  /// 대기실이면 화면을 계속 켜 두고, 방을 나왔으면 화면 켜짐 잠금을 풀어
  /// 기기 절전 설정을 원래대로 되돌립니다.
  static Future<void> showPlatformSystemBars() {
    _gameScreenActive = false;
    unawaited(_applyWakelock());
    return SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
  }

  static Future<void> _applyWakelock() async {
    try {
      await WakelockPlus.toggle(enable: keepsScreenOn);
    } catch (_) {
      // 일부 플랫폼·테스트 환경에서 잠금이 지원되지 않아도 화면 전환과
      // 게임 진행을 막지 않습니다.
    }
  }
}
