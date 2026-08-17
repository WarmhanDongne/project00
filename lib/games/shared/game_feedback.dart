import 'package:flutter/services.dart';

/// 게임의 결정적인 순간에 주는 진동 피드백입니다.
///
/// 모바일 게임에서 선언·제출 같은 되돌릴 수 없는 행동은 손끝으로도 느껴져야
/// 합니다. 세기를 게임마다 다르게 정하지 않도록 여기서 한 번만 정의합니다.
abstract final class GameFeedback {
  /// LIAR·CALL처럼 판을 뒤집는 선언입니다. 가장 강하게 울립니다.
  static void declare() {
    HapticFeedback.heavyImpact();
  }

  /// 카드 제출처럼 되돌릴 수 없는 확정 동작입니다.
  static void commit() {
    HapticFeedback.mediumImpact();
  }

  /// 카드 선택처럼 가벼운 조작입니다.
  static void select() {
    HapticFeedback.selectionClick();
  }
}
