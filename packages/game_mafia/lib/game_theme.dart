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
  // -------------------------------------------------------------------------
  // Noir Poster 시안(2026-10-08) 팔레트
  // -------------------------------------------------------------------------
  /// 밤 바탕·테두리·글자의 먹색입니다.
  static const Color noirInk = Color(0xFF0B0E0D);

  /// 카드·상자 안쪽의 짙은 석판색입니다.
  static const Color noirSlab = Color(0xFF141816);

  /// 낮 바탕과 밤 글자의 바랜 종이색입니다.
  static const Color noirPaper = Color(0xFFD9C2A2);

  /// 테두리·타이머·강조 글자의 놋쇠색입니다.
  static const Color noirBrass = Color(0xFFB08A4A);

  /// 사망·처형 띠의 핏빛 빨강입니다.
  static const Color noirBlood = Color(0xFF8E2A22);

  /// 표적 선택의 선명한 빨강입니다.
  static const Color noirScarlet = Color(0xFFC23B30);

  /// 마피아 글자의 밝은 빨강입니다.
  static const Color noirRose = Color(0xFFE0675D);

  /// 얼굴 뒤 원·시민 팀의 청록입니다.
  static const Color noirTeal = Color(0xFF2F4A47);

  /// 밤 보조 글자의 흐린 모래색입니다.
  static const Color noirDust = Color(0xFF8F8A76);

  /// 낮 보조 글자의 짙은 흙색입니다.
  static const Color noirUmber = Color(0xFF4A473E);

  /// 사망자·비활성 테두리의 바랜 갈색입니다.
  static const Color noirFaded = Color(0xFF5A5040);

  /// 의사(치료)의 청록입니다.
  static const Color noirDoctor = Color(0xFF5E9C8C);

  /// 경찰(조사)의 회청색입니다.
  static const Color noirPolice = Color(0xFF7FA3B8);

  /// 시민 팀 글자의 연한 청록입니다.
  static const Color noirCitizen = Color(0xFF7FA59E);

  // -------------------------------------------------------------------------
  // 기존 이름(여러 화면이 쓰는 값). Noir 팔레트에 맞춰 다시 칠했습니다.
  // -------------------------------------------------------------------------
  /// 마피아 진영·제거 행동의 빨강입니다.
  static const Color mafiaRed = noirScarlet;

  /// 어두운 글자·버튼색입니다.
  static const Color ink = noirInk;

  /// 중립 진영·표식 행동의 노랑입니다.
  static const Color neutralAmber = noirBrass;

  /// 정보 공개 행동의 파랑입니다.
  static const Color exposeBlue = noirPolice;

  /// 낮 화면 바닥색입니다.
  static const Color daySurface = noirPaper;

  /// 밤 화면 바닥색입니다.
  static const Color nightSurface = noirInk;

  /// 밝은 표면입니다.
  static const Color surface = noirPaper;

  /// 비활성 버튼·선택되지 않은 글자입니다.
  static const Color disabled = noirFaded;

  /// 개표판 테두리의 금갈색입니다.
  static const Color boardBorder = noirBrass;
}
