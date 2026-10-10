// [game_theme.dart] 라이어스 포커의 여러 화면이
// 공통으로 사용하는 색상·글꼴·룰렛 확률을 관리하는 파일이다.

// ========================[ import ]==========================
import 'package:flutter/painting.dart';

// ============================================================
// ---------------------------------------------------------------------------
// 라이어스포커 고유 색 (2026-10 GUI 리디자인 · 보랏빛 카지노와 금색)
// ---------------------------------------------------------------------------
abstract final class LiarsPokerColors {
  /// 태블릿 테이블 펠트입니다.
  static const Color felt = Color(0xFF3F1A5C);

  /// 휴대폰 바탕과 가장 어두운 면입니다.
  static const Color night = Color(0xFF160C1F);

  /// 테이블 위 원·룰렛 안쪽처럼 더 깊은 검보라입니다.
  static const Color abyss = Color(0xFF0D0912);

  /// 자리판·목록 행의 기본 면입니다.
  static const Color panel = Color(0xFF22122F);

  /// 차례 강조 자리판·관전 차례 행의 면입니다.
  static const Color panelRaised = Color(0xFF2B1640);

  /// 기본 면 테두리입니다.
  static const Color panelEdge = Color(0xFF3A2350);

  /// 빈 룰렛 점과 비활성 글자입니다.
  static const Color dim = Color(0xFF5A4170);

  /// 금색 강조(진실·차례·선택)입니다.
  static const Color gold = Color(0xFFC9A25B);
  static const Color goldLight = Color(0xFFE2C27E);
  static const Color goldShadow = Color(0xFF5A3F14);

  /// 카드·퍽 버튼의 상아색과 그 아래 두께입니다.
  static const Color ivory = Color(0xFFF3EEE6);
  static const Color ivoryEdge = Color(0xFFC8C0B4);

  /// 보조 글자입니다.
  static const Color muted = Color(0xFFA898BC);
  static const Color mutedLight = Color(0xFFD8C9EA);

  /// LIAR·거짓·탈락 위험입니다.
  static const Color red = Color(0xFFE0243A);
  static const Color redShadow = Color(0xFF5A0A14);
  static const Color redDeep = Color(0xFF9A1426);
  static const Color redPanel = Color(0xFF2B1220);
  static const Color redEdge = Color(0xFF5A2A3A);
  static const Color pink = Color(0xFFFF6B7A);
  static const Color pinkLight = Color(0xFFFF8A96);

  // 이전 화면이 쓰던 이름입니다. 새 팔레트의 같은 역할 색을 가리킵니다.
  static const Color primary = gold;
  static const Color surface = night;
  static const Color title = ivory;
  static const Color description = muted;
  static const Color spectatorSurface = night;
}

// ---------------------------------------------------------------------------
// 글꼴
// ---------------------------------------------------------------------------
/// 시안의 서부 간판 글꼴(Rye), 굵은 한글 제목(Black Han Sans), 본문입니다.
abstract final class LiarsPokerFonts {
  static const display = 'Rye';
  static const heading = 'BlackHanSans';
  static const body = 'IBMPlexSansKR';
  static const bodyPackage = 'game_kit';

  static TextStyle text({
    double size = 14,
    FontWeight weight = FontWeight.w500,
    Color color = LiarsPokerColors.ivory,
    double? height,
    double? letterSpacing,
  }) => TextStyle(
    fontFamily: body,
    package: bodyPackage,
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );

  /// `LIAR!`·`Liar`·`ACE'S TABLE`처럼 라틴 표시 문구입니다.
  static TextStyle western({
    double size = 24,
    Color color = LiarsPokerColors.ivory,
    List<Shadow>? shadows,
    double? letterSpacing,
  }) => TextStyle(
    fontFamily: display,
    fontSize: size,
    color: color,
    height: 1,
    shadows: shadows,
    letterSpacing: letterSpacing,
  );

  /// 남은 시간·`제출`·판정 제목처럼 굵은 한글 표시 문구입니다.
  static TextStyle headline({
    double size = 24,
    Color color = LiarsPokerColors.ivory,
    double? letterSpacing,
    double height = 1,
  }) => TextStyle(
    fontFamily: heading,
    fontSize: size,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );
}

// ---------------------------------------------------------------------------
// 벌칙 룰렛 확률
// ---------------------------------------------------------------------------
/// 지금까지 돌린 룰렛 횟수에 따라 다음 룰렛의 (탈락 칸, 전체 칸)입니다.
///
/// 서버와 공용 룰렛이 쓰는 1회 4/16 · 2회 5/15 · 3회 11/12 단계와 같습니다.
({int bad, int total}) liarsPokerRouletteOdds(int penaltyCount) =>
    switch (penaltyCount) {
      <= 0 => (bad: 4, total: 16),
      1 => (bad: 5, total: 15),
      _ => (bad: 11, total: 12),
    };

/// `4/16`처럼 다음 룰렛의 탈락 칸을 줄여 씁니다.
String liarsPokerOddsLabel(int penaltyCount) {
  final odds = liarsPokerRouletteOdds(penaltyCount);
  return '${odds.bad}/${odds.total}';
}

/// 세 번째(마지막) 룰렛만 남아 탈락 위험이 큰 상태인지입니다.
bool liarsPokerIsDanger(int penaltyCount) => penaltyCount >= 2;

/// 서버가 주는 행동 제한 시간입니다. 남은 시간 링의 비율 계산에만 씁니다.
Duration liarsPokerTurnWindow(String phase) => phase == 'lastCardChallenge'
    ? const Duration(seconds: 10)
    : const Duration(seconds: 30);
