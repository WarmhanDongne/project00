// [game_colors.dart] 는 파이널콜에서 여러 화면이 함께 쓰는 색을 한곳에 모으는 파일이다.
//
// - [Package] : 파이널콜
// - [Theme] : 두 곳 이상에서 쓰는 파이널콜 고유 색을 정의함
//
// 즉, 시안이 바뀔 때 고칠 자리를 한 파일로 좁히기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'package:flutter/painting.dart';

// ============================================================

// ---------------------------------------------------------------------------
// 파이널콜 고유 색
// ---------------------------------------------------------------------------
/// 파이널콜 화면에서 **두 곳 이상** 쓰이는 색입니다.
///
/// 한 번만 쓰는 색은 쓰는 자리에 그대로 둡니다.
abstract final class FinalCallColors {
  /// 선택된 카드·꼬리표의 강조 노랑입니다(Party Pop 시안의 노랑과 같음).
  static const Color highlight = yellow;

  /// 테두리·그림자·글자의 남색입니다.
  static const Color ink = Color(0xFF1B1530);

  /// 게임 배경 남보라입니다.
  static const Color night = Color(0xFF2B1E6B);

  /// 덱 뒷면·주요 버튼의 보라입니다.
  static const Color violet = Color(0xFF6C4CF0);

  /// 덱 더미의 두 번째 겹 보라입니다.
  static const Color violetDeep = Color(0xFF4A3AA8);

  /// 테이블·옅은 버튼의 연보라입니다.
  static const Color lilac = Color(0xFFF4EFFF);

  /// 보조 문구의 회보라입니다.
  static const Color muted = Color(0xFF6B6390);

  /// 카드·팀 색입니다.
  static const Color red = Color(0xFFFF5A5F);
  static const Color blue = Color(0xFF3D7BFF);
  static const Color green = Color(0xFF1FB57A);
  static const Color yellow = Color(0xFFFFC93C);
}
