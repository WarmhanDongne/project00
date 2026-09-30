// [game_colors.dart] 는 마피아에서 여러 화면이 함께 쓰는 색을 한곳에 모으는 파일이다.
//
// - [Package] : 마피아
// - [Theme] : 두 곳 이상에서 쓰는 마피아 고유 색을 정의함
//
// 즉, 시안이 바뀔 때 고칠 자리를 한 파일로 좁히기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'package:flutter/painting.dart';
// ============================================================

// ---------------------------------------------------------------------------
// 마피아 고유 색
// ---------------------------------------------------------------------------
/// 마피아 화면에서 **두 곳 이상** 쓰이는 색입니다.
///
/// 한 번만 쓰는 색(그러데이션 중간 stop 같은 것)은 여기 올리지 않습니다.
/// 쓰는 자리에서 멀어지기만 하고 고칠 일은 그 화면 하나뿐이라, 오히려 읽기가
/// 나빠집니다.
abstract final class MafiaColors {
  /// 마피아 진영·제거 행동의 빨강입니다.
  static const Color mafiaRed = Color(0xFFFF0000);

  /// 어두운 남회색. 나가기 버튼, 투표 완료 버튼, 상단바 글자에 씁니다.
  static const Color ink = Color(0xFF212730);

  /// 중립 진영·표식 행동의 노랑입니다.
  static const Color neutralAmber = Color(0xFFFFC400);

  /// 정보 공개 행동의 파랑입니다.
  static const Color exposeBlue = Color(0xFF44ABFF);

  /// 낮 화면 바닥색입니다(테이블 색과 같습니다).
  static const Color daySurface = Color(0xFFF2F2F2);

  /// 밤 화면 바닥색입니다.
  static const Color nightSurface = Color(0xFF10131A);

  /// 상단바 등 밝은 표면입니다.
  static const Color surface = Color(0xFFECEBEB);

  /// 비활성 버튼·선택되지 않은 글자입니다.
  static const Color disabled = Color(0xFFBDBDBD);

  /// 개표판 테두리의 금갈색입니다.
  static const Color boardBorder = Color(0xFFAF7F3F);
}
