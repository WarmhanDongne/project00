// [game_shadow_colors.dart] 는 여러 게임이 함께 사용하는 그림자·덮개 색을 한곳에 모으는 파일이다.
//
// - [Package] : 게임 공통 기반
// - [Theme] : 게임 화면의 그림자와 모달 덮개 색을 정의함
//
// 즉, 같은 검정 반투명 값을 게임마다 따로 적어 두지 않기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'package:flutter/painting.dart';
// ============================================================

//=======================그림자 농도 사다리==============================
/// 게임 화면에서 쓰는 검정 반투명 그림자입니다.
///
/// 게임마다 고유한 아트 색은 각 게임의 색 파일에 둡니다. 여기 있는 것은
/// **아트와 무관하게 세 게임이 같은 값을 쓰던 것**만 모은 것입니다. 그래서
/// 이름도 색이 아니라 농도로 지었습니다.
///
/// `Colors.black.withValues(alpha: …)` 로 쓰지 않는 이유는 그 형태가 const가
/// 아니어서, 상수 위젯 트리 안에서 쓸 수 없기 때문입니다.
abstract final class GameShadowColors {
  /// 60% — 모달 뒤를 덮거나, 가장 진한 그림자에 씁니다.
  static const Color strongest = Color(0x99000000);

  /// 40% — 카드·버튼이 바닥에서 떠 보이게 하는 기본 그림자입니다.
  static const Color strong = Color(0x66000000);

  /// 30%
  static const Color medium = Color(0x4D000000);

  /// 25%
  static const Color soft = Color(0x40000000);

  /// 20% — 가장 옅은 접지 그림자입니다.
  static const Color faint = Color(0x33000000);
}
