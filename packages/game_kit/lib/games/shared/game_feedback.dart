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

  /// 내 턴 시작, 다른 플레이어의 LIAR·CALL 선언처럼 화면을 보고 있지 않아도
  /// 알아채야 하는 순간입니다. 짧은 햅틱이 아니라 기기 진동을 울립니다.
  ///
  /// 선언한 본인은 버튼을 누를 때 [declare]를 받으므로 여기서 다시 울리지
  /// 않습니다.
  static void alert() {
    HapticFeedback.vibrate();
  }
}
