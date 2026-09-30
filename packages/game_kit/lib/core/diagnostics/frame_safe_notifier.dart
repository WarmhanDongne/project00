// [frame_safe_notifier.dart] 는 여러 게임이 함께 사용하는 개발용 기록이 화면을 그리는 도중에 알림을 보내지 않게 하는 파일이다.
//
// - [Package] : 게임 공통 기반
// - [Diagnostics] : 빌드 중 알림을 프레임 뒤로 미룸
//
// 즉, 기록 한 줄 때문에 화면 빌드가 예외로 멈추지 않게 하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
// ============================================================

/// 화면을 그리는 중(build·layout·paint)에는 알림을 프레임 뒤로 미룹니다.
///
/// 개발용 기록([GameCommunicationLog]·[DevErrorLog])은 앱 어디서든, 심지어
/// Provider의 build나 위젯의 build 안에서도 불립니다. 그때 곧바로
/// [notifyListeners]를 하면 기록을 보여 주는 개발용 화면(조상 위젯)이 그리는
/// 도중에 다시 빌드되어 예외가 납니다. 2026-09 iPad 게임 진입 멈춤이 이
/// 경우였습니다(예열 로그 → 개발용 화면 갱신).
///
/// 한 프레임 안에 여러 번 불려도 알림은 한 번만 보냅니다.
mixin FrameSafeNotifier on ChangeNotifier {
  bool _notifyScheduled = false;

  @protected
  void notifySafely() {
    final SchedulerBinding binding;
    try {
      binding = SchedulerBinding.instance;
    } catch (_) {
      // 바인딩이 없는 순수 Dart 테스트에서는 그리는 단계도 없습니다.
      notifyListeners();
      return;
    }
    if (binding.schedulerPhase != SchedulerPhase.persistentCallbacks) {
      notifyListeners();
      return;
    }
    if (_notifyScheduled) return;
    _notifyScheduled = true;
    binding.addPostFrameCallback((_) {
      _notifyScheduled = false;
      notifyListeners();
    });
  }
}
