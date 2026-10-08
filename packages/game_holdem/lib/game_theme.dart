import 'package:flutter/material.dart';

/// 홀덤 디자인 시안의 색 토큰입니다.
///
/// 시안의 보라색 펠트 톤을 같은 명도·채도의 딥그린으로 옮겼습니다. 밝은 면
/// 위의 강조색([accent])은 흰 퍽·좌석 위에서도 4.5:1 이상 대비를 유지합니다.
abstract final class HoldemColors {
  /// 배경 이미지가 뜨기 전과 자리 배치 화면의 펠트색입니다.
  static const felt = Color(0xFF0E3A27);

  /// 좌석·요약 패널처럼 펠트 위에 얹는 반투명 어두운 면의 기준색입니다.
  static const night = Color(0xFF0B1F16);

  /// 레이즈 시트처럼 불투명한 어두운 면입니다.
  static const sheet = Color(0xFF0D2419);

  /// 펠트 위 글자와 흰 퍽·활성 좌석 면입니다.
  static const ivory = Color(0xFFF4F8F4);

  /// 보조 글자입니다.
  static const muted = Color(0xFFB7CCBF);

  /// 칩 줄무늬, 턴 링, 흰 퍽 위 금액 등 브랜드 강조색입니다.
  static const accent = Color(0xFF1E6A45);

  /// 활성 좌석·흰 면 위 짙은 글자입니다.
  static const ink = Color(0xFF0C1B13);

  /// 카드 하트·다이아입니다.
  static const cardRed = Color(0xFFA3263B);

  /// 카드 스페이드·클럽입니다.
  static const cardBlack = Color(0xFF141A17);

  /// 카드 앞면 바탕과 테두리입니다.
  static const cardFace = Color(0xFFFBFCFA);
  static const cardEdge = Color(0xFFDFE5E0);

  /// 흰 퍽 아래 두께와 어두운 퍽 그라데이션입니다.
  static const puckEdge = Color(0xFFB3BEB7);
  static const puckDarkTop = Color(0xFF26443A);
  static const puckDarkMid = Color(0xFF162A21);
  static const puckDarkBottom = Color(0xFF09140F);

  /// 오류 문구입니다.
  static const danger = Color(0xFFFFB1AB);

  static Color panel([double alpha = .6]) => night.withValues(alpha: alpha);
  static Color line([double alpha = .2]) => ivory.withValues(alpha: alpha);
}

/// 홀덤 시안의 글꼴입니다. 표시용 두 글꼴과 숫자 글꼴은 앱 번들에 있습니다.
abstract final class HoldemFonts {
  /// 제목·퍽 버튼·스탬프용 둥근 세리프입니다.
  static const display = 'Caprasimo';

  /// 카드 rank 글자용 Didone 세리프입니다.
  static const card = 'BodoniModa';

  /// 칩·팟 금액 숫자입니다.
  static const number = 'BebasNeue';

  /// 한글 본문입니다.
  static const body = 'packages/game_kit/IBMPlexSansKR';

  /// 표시용 라틴 글꼴에 없는 한글은 본문 글꼴로 그립니다.
  static const _koreanFallback = [body];

  static const cardVariations = [
    FontVariation('wght', 750),
    FontVariation('opsz', 48),
  ];

  static TextStyle text({
    double size = 14,
    FontWeight weight = FontWeight.w500,
    Color color = HoldemColors.ivory,
    double? height,
    double? letterSpacing,
  }) => TextStyle(
    fontFamily: body,
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );

  static TextStyle numbers({
    double size = 28,
    Color color = HoldemColors.ivory,
  }) => TextStyle(
    fontFamily: number,
    fontFamilyFallback: _koreanFallback,
    fontSize: size,
    color: color,
    height: 1,
    letterSpacing: .5,
  );

  static TextStyle title({
    double size = 26,
    Color color = HoldemColors.ivory,
    List<Shadow>? shadows,
  }) => TextStyle(
    fontFamily: display,
    fontFamilyFallback: _koreanFallback,
    fontSize: size,
    color: color,
    height: 1,
    shadows: shadows,
  );
}

/// 칩 금액을 세 자리마다 쉼표로 나눕니다.
String holdemChips(int value) {
  final negative = value < 0;
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
    buffer.write(digits[index]);
  }
  return negative ? '-$buffer' : buffer.toString();
}
