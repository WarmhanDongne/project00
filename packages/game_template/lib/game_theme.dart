// [game_theme.dart] 는 새 게임 템플릿에서 사용하는 색을 모아 두는 파일이다.
//
// - [Package] : 새 게임 템플릿
// - [Theme] : 이 게임의 대표 색
//
// 즉, 색을 화면 코드 곳곳에 흩어 두지 않고 한곳에서 고치기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'package:flutter/painting.dart';
// ============================================================

abstract final class TemplateColors {
  /// 게임 목록·자리 배치 테이블에 쓰는 대표 색입니다.
  static const primary = Color(0xFF808080);
}
