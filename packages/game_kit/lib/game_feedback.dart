// [game_feedback.dart]는 게임 중 발생하는 기기 진동을 공통으로 관리하는 파일이다.
//
// - [Select] : 카드를 선택할 때 약한 진동
// - [Commit] : 카드를 제출할 때 중간 진동
// - [Declare] : LIAR, CALL 선언 시 강한 진동
// - [Alert] : 내 턴이나 상대방의 중요 행동을 일반 진동으로 알림

// - [abstract ] : 직접 생성하지 않고 상속해서 사용

// ========================[ import ]==========================
import 'package:flutter/services.dart';
// ============================================================

//==========[ 기기 진동 효과 ]==========
abstract final class GameFeedback {
  //무거운 진동
  static void declare() {
    HapticFeedback.heavyImpact();
  }

  //중간 진동
  static void commit() {
    HapticFeedback.mediumImpact();
  }

  //가벼운 진동
  static void select() {
    HapticFeedback.selectionClick();
  }

  //일반 진동
  static void alert() {
    HapticFeedback.vibrate();
  }
}
