// [mosi_game_art.dart] 는 게임 상자 표지와 선반 위 상자 옆면을 그리는 파일이다.
//
// - [Package] : 게임 공통 기반
// - [Design] : 시안의 300×400 표지를 Flutter 캔버스와 패키지 자산으로 구성
//
// 선반, 게임 상세, 상점, 게임 안 설정 모달이 같은 표지를 씁니다. 표지 그림이
// 없는 게임(새로 추가된 게임)은 이름으로 만든 기본 표지를 그립니다.

// ========================[ import ]==========================
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:game_kit/localization/game_locale.dart';

part 'mosi_game_art_yut_covers.dart';
part 'mosi_game_art_holdem_cover.dart';

// ============================================================

//=======================게임별 그림 정보==============================
/// 게임 id별 상자 그림 정보입니다. 등록되지 않은 게임은 [fallback]을 씁니다.
@immutable
class MosiGameArt {
  const MosiGameArt({
    required this.id,
    required this.koreanName,
    required this.englishName,
    required this.shelfTheme,
    required this.spineColor,
    required this.spineText,
    required this.accent,
  });

  final String id;
  final String koreanName;
  final String englishName;
  final MosiShelfTheme shelfTheme;
  final Color spineColor;
  final Color spineText;

  /// 상세 제목 옆 영문 라벨 색입니다.
  final Color accent;

  static const liarsPoker = MosiGameArt(
    id: 'liars_poker',
    koreanName: '라이어스 포커',
    englishName: "LIAR'S POKER",
    shelfTheme: MosiShelfTheme.violet,
    spineColor: Color(0xFF4A1A5E),
    spineText: Color(0xFFF8F4FA),
    accent: MosiColors.lime,
  );

  static const finalCall = MosiGameArt(
    id: 'final_call',
    koreanName: '파이널콜',
    englishName: 'FINAL CALL',
    shelfTheme: MosiShelfTheme.court,
    spineColor: Color(0xFFEFEDE8),
    spineText: Color(0xFF141414),
    accent: MosiColors.sun,
  );

  static const mafia = MosiGameArt(
    id: 'mafia',
    koreanName: '마피아',
    englishName: 'MAFIA',
    shelfTheme: MosiShelfTheme.midnight,
    spineColor: Color(0xFF10131A),
    spineText: MosiColors.white,
    accent: Color(0xFFFF4D4D),
  );

  static const holdem = MosiGameArt(
    id: 'holdem',
    koreanName: '홀덤',
    englishName: "TEXAS HOLD'EM",
    shelfTheme: MosiShelfTheme(
      ground: MosiColors.green,
      fg: MosiColors.white,
      fgDim: Color(0x99FFFFFF),
      deep: Color(0xFF103C2A),
      btnBg: Color(0xFFD7B56D),
      btnFg: MosiColors.navy,
      accA: Color(0xFFD7B56D),
      accB: Color(0xFFD7B56D),
    ),
    // 원본 빨간 표지의 장식 없는 영역 대표색.
    spineColor: Color(0xFFC42732),
    spineText: MosiColors.white,
    accent: Color(0xFFD7B56D),
  );

  static const yut = MosiGameArt(
    id: 'yut',
    koreanName: '윷놀이',
    englishName: 'YUT NORI',
    shelfTheme: MosiShelfTheme(
      ground: Color(0xFFB85A47),
      fg: MosiColors.white,
      fgDim: Color(0xB3FFFFFF),
      deep: Color(0xFF4D2A28),
      btnBg: Color(0xFFE8C77C),
      btnFg: Color(0xFF30201B),
      accA: Color(0xFFE8C77C),
      accB: Color(0xFF2C775F),
    ),
    spineColor: Color(0xFF8D3F35),
    spineText: MosiColors.white,
    accent: Color(0xFFE8C77C),
  );

  static const strategyYut = MosiGameArt(
    id: 'strategy_yut',
    koreanName: '전략 윷놀이',
    englishName: 'STRATEGY YUT',
    shelfTheme: MosiShelfTheme(
      ground: Color(0xFF286A68),
      fg: MosiColors.white,
      fgDim: Color(0xB3FFFFFF),
      deep: Color(0xFF173F47),
      btnBg: Color(0xFFE1C990),
      btnFg: Color(0xFF173F47),
      accA: Color(0xFFE1C990),
      accB: Color(0xFFCE5A4A),
    ),
    spineColor: Color(0xFF1D5353),
    spineText: MosiColors.white,
    accent: Color(0xFFE1C990),
  );

  static const strategyYutEdition = MosiGameArt(
    id: 'strategy_yut_edition',
    koreanName: '전략 윷놀이 에디션',
    englishName: 'STRATEGY YUT · EDITION',
    shelfTheme: MosiShelfTheme(
      ground: Color(0xFF151E58),
      fg: Color(0xFFF4E8CA),
      fgDim: Color(0xB3F4E8CA),
      deep: Color(0xFF0D143F),
      btnBg: Color(0xFFC99A48),
      btnFg: Color(0xFF111B55),
      accA: Color(0xFFC99A48),
      accB: Color(0xFFCF5A50),
    ),
    spineColor: Color(0xFF101747),
    spineText: Color(0xFFF2D58F),
    accent: Color(0xFFC99A48),
  );

  static const _known = <String, MosiGameArt>{
    'liars_poker': liarsPoker,
    'final_call': finalCall,
    'mafia': mafia,
    'holdem': holdem,
    'yut': yut,
    'strategy_yut': strategyYut,
    'strategy_yut_edition': strategyYutEdition,
  };

  /// 표지 그림이 등록된 게임인지 알려 줍니다.
  static bool isKnown(String id) => _known.containsKey(id);

  static MosiGameArt of(String id, {String? fallbackName}) =>
      _known[id] ??
      MosiGameArt(
        id: id,
        koreanName: fallbackName ?? id,
        englishName: (fallbackName ?? id).toUpperCase(),
        shelfTheme: MosiShelfTheme.paper,
        spineColor: MosiColors.violet,
        spineText: MosiColors.white,
        accent: MosiColors.violet,
      );
}

//=======================상자 표지==============================
/// 3:4 상자 표지입니다. [width]만 주면 높이는 4/3배입니다.
class MosiGameCover extends StatelessWidget {
  const MosiGameCover({
    super.key,
    required this.gameId,
    this.width = 240,
    this.shadow,
    this.shadowColor = MosiColors.navy,
    this.fallbackName,
    this.fallbackImageUrl,
    this.displayName,
    this.englishName,
  });

  final String gameId;
  final double width;

  /// 오프셋 그림자 크기입니다. null이면 너비의 4.7%입니다.
  final double? shadow;
  final Color shadowColor;
  final String? fallbackName;
  final String? displayName;
  final String? englishName;

  /// 그림이 등록되지 않은 게임은 서버 이미지를 표지로 씁니다.
  final String? fallbackImageUrl;

  @override
  Widget build(BuildContext context) {
    final height = width * 4 / 3;
    final s = shadow ?? (width * 0.047).roundToDouble();
    final known = MosiGameArt.isKnown(gameId);
    final artInfo = MosiGameArt.of(gameId, fallbackName: fallbackName);
    final localizedTitle = displayName?.trim().isNotEmpty == true
        ? displayName!.trim()
        : _localizedGameTitle(artInfo);
    final englishTitle = englishName?.trim().isNotEmpty == true
        ? englishName!.trim()
        : artInfo.englishName;
    final imageUrl = fallbackImageUrl;
    Widget art;
    if (gameId == 'yut' ||
        gameId == 'strategy_yut' ||
        gameId == 'strategy_yut_edition') {
      art = _YutCoverArtwork(gameId: gameId, width: width, height: height);
    } else if (gameId == 'holdem') {
      // 빨간 카드 상자 표지(749×1050)를 코드로 그려 상자 비율에 맞춥니다.
      art = SizedBox(
        key: const Key('holdem-cardbox-cover'),
        width: width,
        height: height,
        child: const FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: 749,
            height: 1050,
            child: CustomPaint(painter: _HoldemCardboxPainter()),
          ),
        ),
      );
    } else if (gameId == 'final_call') {
      // 코드로 그린 새 표지입니다. 300×400 판을 상자 크기에 맞춰 줄입니다.
      art = SizedBox(
        width: width,
        height: height,
        child: FittedBox(
          fit: BoxFit.fill,
          child: SizedBox(
            width: 300,
            height: 400,
            child: _FinalCallCover(title: englishTitle),
          ),
        ),
      );
    } else if (known) {
      art = CustomPaint(
        size: Size(width, height),
        painter: _CoverPainter(
          gameId: gameId,
          displayName: localizedTitle,
          englishName: englishTitle,
        ),
      );
    } else if (imageUrl != null && imageUrl.isNotEmpty) {
      art = Image.network(
        imageUrl,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            _GenericCover(name: fallbackName ?? gameId, width: width),
      );
    } else {
      art = _GenericCover(name: fallbackName ?? gameId, width: width);
    }
    return Semantics(
      image: true,
      label: GameLocale.select(
        ko: '$localizedTitle 상자 표지',
        en: '$localizedTitle box cover',
        zhHans: '$localizedTitle 游戏盒封面',
        zhHant: '$localizedTitle 遊戲盒封面',
      ),
      excludeSemantics: true,
      child: Container(
        width: width,
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: MosiColors.ink,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: MosiColors.ink, width: 3),
          boxShadow: s > 0
              ? [BoxShadow(color: shadowColor, offset: Offset(s, s))]
              : null,
        ),
        child: FittedBox(fit: BoxFit.cover, child: art),
      ),
    );
  }
}

/// 윷놀이 표지는 게임 디자인(300×400)을 그대로 코드로 그립니다. 벡터 그림은
/// 생성 파일 `mosi_game_art_yut_covers.dart`에 있고, 글자는 같은 좌표계에서
/// 그려 상자 크기가 바뀌어도 배치가 유지됩니다. 언어가 바뀌면 제목만
/// 번역하고, 길면 정해진 폭에 맞춰 줄입니다.
class _YutCoverArtwork extends StatelessWidget {
  const _YutCoverArtwork({
    required this.gameId,
    required this.width,
    required this.height,
  });

  final String gameId;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: height,
    child: CustomPaint(
      painter: _YutCoverPainter(
        gameId: gameId,
        language: GameLocale.current.toLanguageTag(),
      ),
    ),
  );
}

/// 300×400 디자인 좌표의 윷놀이 표지를 상자 크기에 맞춰 그립니다.
class _YutCoverPainter extends CustomPainter {
  const _YutCoverPainter({required this.gameId, required this.language});

  final String gameId;

  /// 언어가 바뀌면 다시 그리도록 비교에만 씁니다.
  final String language;

  static const _myeongjo = ['SongMyung', 'Noto Serif CJK KR', 'serif'];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(size.width / 300, size.height / 400);
    switch (gameId) {
      case 'yut':
        _paintYutClassicCover(canvas);
        _classicTitle(canvas);
      case 'strategy_yut_edition':
        _paintStrategyYutEditionCover(canvas);
        _strategyText(canvas, edition: true);
      default:
        _paintStrategyYutCover(canvas);
        _strategyText(canvas, edition: false);
    }
    canvas.restore();
  }

  /// 표지 밖으로 넘칠 만큼 큰 붓글씨 제목(한글판 `윷`, 영어판 `YUT`)입니다.
  void _classicTitle(Canvas canvas) {
    final english = GameLocale.isEnglish;
    final glyph = GameLocale.select(
      ko: '윷',
      en: 'YUT',
      zhHans: '柶',
      zhHant: '柶',
    );
    final style = english
        ? MosiFonts.playfair(
            size: 196,
            color: const Color(0xFFF4F1EA),
            height: 1,
          ).copyWith(letterSpacing: -10, fontWeight: FontWeight.w700)
        : const TextStyle(
            fontFamily: 'SongMyung',
            fontFamilyFallback: _myeongjo,
            fontSize: 410,
            height: 1,
          );
    final at = english ? const Offset(150, 300) : const Offset(128, 372);
    _coverText(
      canvas,
      glyph,
      at,
      style.copyWith(
        foreground: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xFF2B2A28),
      ),
      maxWidth: english ? 290 : 520,
    );
    _coverText(
      canvas,
      glyph,
      at,
      style.copyWith(color: const Color(0xFFF4F1EA)),
      maxWidth: english ? 290 : 520,
    );
  }

  void _strategyText(Canvas canvas, {required bool edition}) {
    final ink = edition ? const Color(0xFF0B0A12) : const Color(0xFFEFE6D3);
    final mark = TextStyle(
      fontFamily: 'SongMyung',
      fontFamilyFallback: _myeongjo,
      fontSize: 13,
      height: 1,
      color: ink,
    );
    // 판 모서리의 팔각 말 두 개에는 팀 글자(백·청)가 새겨져 있습니다.
    _coverText(canvas, '백', const Offset(40, 44.3), mark);
    _coverText(
      canvas,
      '청',
      const Offset(272, 152.3),
      mark.copyWith(color: edition ? Colors.white : const Color(0xFF2A3654)),
    );
    final label = edition ? 'SPECIAL EDITION · 吉祥' : 'KOREAN TRADITIONAL GAME';
    final caption = MosiFonts.playfair(
      size: 9.5,
      color: edition ? const Color(0xFFC9B8FF) : const Color(0xFF5C6478),
      height: 1,
    ).copyWith(letterSpacing: 4, fontWeight: FontWeight.w600);
    _coverText(canvas, label, const Offset(150, 306), caption, maxWidth: 230);

    // 제목은 언어에 맞추되 에디션도 `전략 윷놀이`만 씁니다.
    final title = GameLocale.select(
      ko: '전략 윷놀이',
      en: 'Strategy Yut',
      zhHans: '策略掷柶',
      zhHant: '策略擲柶',
    );
    final gradient = edition
        ? const LinearGradient(
            colors: [
              Color(0xFFC9B8FF),
              Color(0xFFA9E8F0),
              Color(0xFFF6C3DF),
              Color(0xFFD9F2E4),
              Color(0xFFB6C7FF),
              Color(0xFFF3D2F0),
            ],
          )
        : const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2A3654), Color(0xFF1E2840)],
          );
    final titleStyle = GameLocale.isEnglish
        ? MosiFonts.playfair(
            size: 32,
            color: Colors.white,
            height: 1,
          ).copyWith(letterSpacing: 1)
        : const TextStyle(
            fontFamily: 'SongMyung',
            fontFamilyFallback: _myeongjo,
            fontSize: 34,
            fontWeight: FontWeight.w800,
            letterSpacing: 4,
            height: 1,
          );
    _coverText(
      canvas,
      title,
      const Offset(150, 342),
      titleStyle.copyWith(
        foreground: Paint()
          ..shader = gradient.createShader(
            const Rect.fromLTWH(60, 312, 180, 36),
          ),
      ),
      maxWidth: 220,
    );
    _coverText(
      canvas,
      'STRATEGIC YUT',
      const Offset(150, 366),
      MosiFonts.playfair(
        size: 10.5,
        color: edition ? const Color(0xFFE6DCFF) : const Color(0xFF5C6478),
        height: 1,
      ).copyWith(letterSpacing: 5, fontWeight: FontWeight.w600),
      maxWidth: 220,
    );
    if (!edition) return;
    canvas.save();
    canvas.translate(258, 42);
    canvas.rotate(math.pi / 4);
    _coverText(
      canvas,
      'LIMITED',
      Offset.zero,
      MosiFonts.playfair(
        size: 11,
        color: const Color(0xFF0B0A12),
        height: 1,
      ).copyWith(letterSpacing: 3, fontWeight: FontWeight.w600),
    );
    canvas.restore();
    _coverText(
      canvas,
      'No. 001',
      const Offset(268, 384),
      MosiFonts.playfair(
        size: 8.5,
        color: const Color(0xFFB9B0D6),
        height: 1,
      ).copyWith(letterSpacing: 1.5),
      align: TextAlign.right,
    );
  }

  @override
  bool shouldRepaint(_YutCoverPainter old) =>
      old.gameId != gameId || old.language != language;
}

/// SVG `<text>`처럼 [baseline] 위치에 글자를 놓습니다. [maxWidth]보다 길면
/// 가로로 줄여 표지 디자인을 흐트러뜨리지 않습니다.
void _coverText(
  Canvas canvas,
  String text,
  Offset baseline,
  TextStyle style, {
  double? maxWidth,
  TextAlign align = TextAlign.center,
}) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  )..layout();
  final ascent = painter.computeDistanceToActualBaseline(
    TextBaseline.alphabetic,
  );
  final scale = maxWidth != null && painter.width > maxWidth
      ? maxWidth / painter.width
      : 1.0;
  canvas.save();
  canvas.translate(baseline.dx, baseline.dy);
  canvas.scale(scale, scale);
  final dx = switch (align) {
    TextAlign.right || TextAlign.end => -painter.width,
    TextAlign.left || TextAlign.start => 0.0,
    _ => -painter.width / 2,
  };
  painter.paint(canvas, Offset(dx, -ascent));
  canvas.restore();
}

class _GenericCover extends StatelessWidget {
  const _GenericCover({required this.name, required this.width});

  final String name;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: width * 4 / 3,
      color: MosiColors.violet,
      padding: EdgeInsets.all(width * 0.08),
      alignment: Alignment.topLeft,
      child: Text(
        name,
        style: MosiFonts.sans(
          size: width * 0.13,
          weight: FontWeight.w700,
          color: MosiColors.white,
          height: 1.1,
        ),
      ),
    );
  }
}

class _CoverPainter extends CustomPainter {
  const _CoverPainter({
    required this.gameId,
    required this.displayName,
    required this.englishName,
  });

  final String gameId;
  final String displayName;
  final String englishName;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 300, size.height / 400);
    switch (gameId) {
      case 'liars_poker':
        _paintLiar(canvas, displayName, englishName);
      case 'final_call':
        _paintFinal(canvas, displayName, englishName);
      case 'mafia':
        _paintMafia(canvas, displayName, englishName);
      case 'holdem':
        _paintHoldem(canvas);
      case 'yut':
      case 'strategy_yut':
      case 'strategy_yut_edition':
        _paintYut(canvas, gameId, displayName, englishName);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CoverPainter oldDelegate) =>
      oldDelegate.gameId != gameId ||
      oldDelegate.displayName != displayName ||
      oldDelegate.englishName != englishName;
}

//=======================캔버스 도우미==============================
Paint _fill(Color color) => Paint()..color = color;

Paint _stroke(Color color, double width) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeJoin = StrokeJoin.round;

/// SVG `<text>`처럼 기준선 [y]에 글자를 놓습니다.
void _text(
  Canvas canvas,
  String text,
  double x,
  double y,
  TextStyle style, {
  TextAlign align = TextAlign.left,
  double maxWidth = 276,
}) => _coverText(
  canvas,
  text,
  Offset(x, y),
  style,
  maxWidth: maxWidth,
  align: align,
);

TextStyle _playfair(double size, Color color) =>
    MosiFonts.playfair(size: size, color: color, height: 1);

TextStyle _plex(double size, Color color) => MosiFonts.sans(
  size: size,
  weight: FontWeight.w700,
  color: color,
  height: 1,
);

TextStyle _grotesk(double size, Color color, double spacing) =>
    MosiFonts.grotesk(
      size: size,
      color: color,
      letterSpacing: spacing,
      height: 1,
    );

/// (tx,ty) 이동 후 (cx,cy) 기준 회전 — SVG `translate() rotate(a cx cy)`.
void _withTransform(
  Canvas canvas,
  double tx,
  double ty,
  double degrees,
  double cx,
  double cy,
  void Function() draw,
) {
  canvas.save();
  canvas.translate(tx, ty);
  if (degrees != 0) {
    canvas.translate(cx, cy);
    canvas.rotate(degrees * math.pi / 180);
    canvas.translate(-cx, -cy);
  }
  draw();
  canvas.restore();
}

//=======================라이어스 포커 · 세 장의 거짓말==============================
void _paintLiar(Canvas canvas, String displayName, String englishName) {
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 300, 400),
    _fill(MosiGameArt.liarsPoker.spineColor),
  );
  canvas.drawCircle(
    const Offset(150, 300),
    190,
    _fill(const Color(0xFF5A2272)),
  );
  _text(
    canvas,
    englishName.toUpperCase(),
    24,
    88,
    _playfair(44, const Color(0xFFF8F4FA)),
    maxWidth: 252,
  );
  if (displayName.toUpperCase() != englishName.toUpperCase()) {
    _text(canvas, displayName, 26, 118, _plex(14, const Color(0xFFC7B8CC)));
  }
  canvas.drawOval(
    Rect.fromCenter(center: const Offset(150, 352), width: 236, height: 24),
    _fill(const Color(0xFF1B1022)),
  );

  void backCard() {
    final rect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, 110, 154),
      const Radius.circular(8),
    );
    canvas.drawRRect(rect, _fill(MosiColors.white));
    canvas.drawRRect(rect, _stroke(MosiColors.ink, 2.5));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(7, 7, 96, 140),
        const Radius.circular(4),
      ),
      _stroke(MosiColors.ink, 1),
    );
    final outer = Path()
      ..moveTo(55, 52)
      ..lineTo(80, 77)
      ..lineTo(55, 102)
      ..lineTo(30, 77)
      ..close();
    canvas.drawPath(outer, _stroke(MosiColors.ink, 1.2));
    final inner = Path()
      ..moveTo(55, 62)
      ..lineTo(70, 77)
      ..lineTo(55, 92)
      ..lineTo(40, 77)
      ..close();
    canvas.drawPath(inner, _stroke(MosiColors.ink, 1));
    canvas.drawRect(
      const Rect.fromLTWH(50, 72, 10, 10),
      _stroke(MosiColors.ink, 1),
    );
    canvas.drawLine(
      const Offset(55, 28),
      const Offset(55, 48),
      _stroke(MosiColors.ink, 1),
    );
    canvas.drawLine(
      const Offset(55, 106),
      const Offset(55, 126),
      _stroke(MosiColors.ink, 1),
    );
  }

  _withTransform(canvas, 95, 182, -17, 55, 154, backCard);
  _withTransform(canvas, 95, 182, 17, 55, 154, backCard);
  _withTransform(canvas, 95, 172, 0, 0, 0, () {
    final rect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, 110, 154),
      const Radius.circular(8),
    );
    canvas.drawRRect(rect, _fill(MosiColors.white));
    canvas.drawRRect(rect, _stroke(MosiColors.ink, 2.5));
    _text(canvas, 'A', 11, 24, _playfair(16, MosiColors.ink));
    _text(
      canvas,
      'A',
      55,
      102,
      _playfair(66, MosiColors.ink),
      align: TextAlign.center,
    );
    _text(
      canvas,
      'A',
      99,
      142,
      _playfair(16, MosiColors.ink),
      align: TextAlign.right,
    );
  });
  _text(
    canvas,
    'MOSIGAME',
    24,
    386,
    _grotesk(10, const Color(0xFFC7B8CC), 2.5),
  );
}

//=======================파이널콜 · 네 장의 손패==============================
void _paintFinal(Canvas canvas, String displayName, String englishName) {
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 300, 400),
    _fill(MosiGameArt.finalCall.spineColor),
  );
  canvas.drawCircle(
    const Offset(150, 300),
    170,
    _stroke(const Color(0xFFDCD8CF), 1.5),
  );
  canvas.drawCircle(
    const Offset(40, 360),
    110,
    _stroke(const Color(0xFFDCD8CF), 1.5),
  );
  _text(
    canvas,
    englishName.toUpperCase(),
    24,
    84,
    _playfair(40, const Color(0xFF141414)),
  );
  canvas.drawRect(
    const Rect.fromLTWH(22, 94, 134, 12),
    _fill(const Color(0xFFE5DB00)),
  );
  if (displayName.toUpperCase() != englishName.toUpperCase()) {
    _text(canvas, displayName, 26, 128, _plex(14, const Color(0xFF141414)));
  }
  canvas.drawOval(
    Rect.fromCenter(center: const Offset(150, 356), width: 240, height: 22),
    _fill(const Color(0xFFD2CEC5)),
  );

  void card(String number, Color line) {
    final rect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, 110, 154),
      const Radius.circular(6),
    );
    canvas.drawRRect(rect, _fill(const Color(0xFF111111)));
    canvas.drawRRect(rect, _stroke(const Color(0xFF000000), 2));
    canvas.drawRect(const Rect.fromLTWH(8, 8, 94, 138), _stroke(line, 1.6));
    canvas.drawRect(const Rect.fromLTWH(14, 14, 82, 126), _stroke(line, 0.8));
    final corners = _stroke(line, 1.4);
    canvas.drawLine(const Offset(8, 26), const Offset(26, 8), corners);
    canvas.drawLine(const Offset(84, 8), const Offset(102, 26), corners);
    canvas.drawLine(const Offset(8, 128), const Offset(26, 146), corners);
    canvas.drawLine(const Offset(84, 146), const Offset(102, 128), corners);
    _text(
      canvas,
      number,
      55,
      96,
      _playfair(52, MosiColors.white),
      align: TextAlign.center,
    );
  }

  _withTransform(
    canvas,
    95,
    196,
    -27,
    55,
    154,
    () => card('7', const Color(0xFFE0302E)),
  );
  _withTransform(
    canvas,
    95,
    196,
    -9,
    55,
    154,
    () => card('3', const Color(0xFFE0302E)),
  );
  _withTransform(
    canvas,
    95,
    196,
    9,
    55,
    154,
    () => card('2', const Color(0xFFE5DB00)),
  );
  _withTransform(
    canvas,
    95,
    196,
    27,
    55,
    154,
    () => card('7', const Color(0xFF2F5BEA)),
  );
  _text(
    canvas,
    'MOSIGAME',
    276,
    386,
    _grotesk(10, const Color(0xFF141414), 2.5),
    align: TextAlign.right,
  );
}

//=======================마피아==============================
void _paintMafia(Canvas canvas, String displayName, String englishName) {
  final night = MosiGameArt.mafia.spineColor;
  const gold = Color(0xFFFFC400);
  canvas.drawRect(const Rect.fromLTWH(0, 0, 300, 400), _fill(night));
  canvas.drawCircle(const Offset(206, 92), 56, _fill(gold));
  canvas.drawCircle(const Offset(206, 92), 56, _stroke(MosiColors.ink, 3));
  canvas.drawCircle(const Offset(226, 80), 56, _fill(night));
  final star = _fill(MosiColors.white);
  canvas.drawCircle(const Offset(40, 40), 3, star);
  canvas.drawCircle(const Offset(96, 70), 2.5, star);
  canvas.drawCircle(const Offset(130, 28), 3, star);
  canvas.drawCircle(const Offset(268, 170), 2, star);
  final skyline = Path()
    ..moveTo(0, 230)
    ..relativeLineTo(40, 0)
    ..relativeLineTo(0, -40)
    ..relativeLineTo(36, 0)
    ..relativeLineTo(0, 24)
    ..relativeLineTo(30, 0)
    ..relativeLineTo(0, -60)
    ..relativeLineTo(52, 0)
    ..relativeLineTo(0, 46)
    ..relativeLineTo(34, 0)
    ..relativeLineTo(0, -30)
    ..relativeLineTo(46, 0)
    ..relativeLineTo(0, 40)
    ..relativeLineTo(62, 0)
    ..relativeLineTo(0, 190)
    ..lineTo(0, 420)
    ..close();
  canvas.drawPath(skyline, _fill(const Color(0xFF212730)));
  canvas.drawPath(skyline, _stroke(MosiColors.ink, 3));
  final window = _fill(gold);
  canvas.drawRect(const Rect.fromLTWH(12, 246, 18, 22), window);
  canvas.drawRect(const Rect.fromLTWH(50, 210, 16, 20), window);
  canvas.drawRect(
    const Rect.fromLTWH(116, 172, 34, 40),
    _fill(const Color(0xFF000000)),
  );
  canvas.drawRect(const Rect.fromLTWH(116, 172, 34, 40), _stroke(gold, 2));
  final eye = _fill(const Color(0xFFFF0000));
  canvas.drawOval(
    Rect.fromCenter(center: const Offset(126, 192), width: 8, height: 5.2),
    eye,
  );
  canvas.drawOval(
    Rect.fromCenter(center: const Offset(140, 192), width: 8, height: 5.2),
    eye,
  );
  canvas.drawRect(const Rect.fromLTWH(198, 198, 18, 22), window);
  canvas.drawRect(const Rect.fromLTWH(250, 214, 18, 22), window);
  canvas.drawRect(
    const Rect.fromLTWH(0, 292, 300, 108),
    _fill(const Color(0xFFFF0000)),
  );
  canvas.drawLine(
    const Offset(0, 292),
    const Offset(300, 292),
    _stroke(MosiColors.ink, 3),
  );
  _text(
    canvas,
    displayName,
    150,
    352,
    MosiFonts.sans(
      size: 56,
      weight: FontWeight.w700,
      color: MosiColors.white,
      letterSpacing: -2,
      height: 1,
    ),
    align: TextAlign.center,
  );
  if (displayName.toUpperCase() != englishName.toUpperCase()) {
    _text(
      canvas,
      englishName.toUpperCase(),
      150,
      382,
      _grotesk(16, night, 8),
      align: TextAlign.center,
    );
  }
}

void _paintHoldem(Canvas canvas) {
  const felt = Color(0xFF0A5B3E);
  const deep = Color(0xFF063B2B);
  const ivory = Color(0xFFF7F1DE);
  const gold = Color(0xFFD7B56D);
  canvas.drawRect(const Rect.fromLTWH(0, 0, 300, 400), _fill(deep));
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(22, 34, 256, 250),
      const Radius.circular(118),
    ),
    _fill(felt),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(22, 34, 256, 250),
      const Radius.circular(118),
    ),
    _stroke(gold, 5),
  );
  _text(canvas, 'A', 91, 196, _playfair(96, ivory), align: TextAlign.center);
  _text(canvas, '♠', 207, 202, _playfair(92, ivory), align: TextAlign.center);
  _text(
    canvas,
    "TEXAS HOLD'EM",
    150,
    334,
    _grotesk(21, gold, 3),
    align: TextAlign.center,
  );
  _text(
    canvas,
    'MOSIGAME',
    150,
    370,
    _grotesk(12, ivory, 5),
    align: TextAlign.center,
  );
}

void _paintYut(
  Canvas canvas,
  String gameId,
  String displayName,
  String englishName,
) {
  final edition = gameId == 'strategy_yut_edition';
  final strategy = gameId != 'yut';
  final art = MosiGameArt.of(gameId);
  final ground = edition ? const Color(0xFF101747) : art.shelfTheme.ground;
  final ink = edition ? const Color(0xFFF2D58F) : const Color(0xFFF5EEDC);
  final line = edition ? const Color(0xFFC99A48) : const Color(0xFF203C42);
  canvas.drawRect(const Rect.fromLTWH(0, 0, 300, 400), _fill(ground));

  // Quiet Korean pattern around the title keeps the three covers related while
  // the board geometry and palette distinguish the strategy edition.
  for (var i = -1; i < 5; i++) {
    final x = 28.0 + i * 62;
    canvas.drawCircle(
      Offset(x, 24),
      22,
      _stroke(line.withValues(alpha: .55), 1),
    );
    canvas.drawCircle(
      Offset(x, 24),
      13,
      _stroke(line.withValues(alpha: .4), 1),
    );
  }
  _text(
    canvas,
    displayName,
    150,
    104,
    MosiFonts.sans(
      size: displayName.length > 8 ? 25 : 32,
      weight: FontWeight.w900,
      color: ink,
      letterSpacing: -1,
      height: 1,
    ),
    align: TextAlign.center,
  );
  _text(
    canvas,
    englishName.toUpperCase(),
    150,
    132,
    _grotesk(10, ink.withValues(alpha: .82), 2.2),
    align: TextAlign.center,
  );

  final board = RRect.fromRectAndRadius(
    const Rect.fromLTWH(35, 168, 230, 184),
    const Radius.circular(16),
  );
  canvas.drawRRect(board, _fill(edition ? const Color(0xFF18235F) : ink));
  canvas.drawRRect(board, _stroke(line, 3));
  final track = Path()
    ..moveTo(150, 194)
    ..lineTo(236, 260)
    ..lineTo(150, 326)
    ..lineTo(64, 260)
    ..close();
  canvas.drawPath(track, _stroke(edition ? ink : line, 5));
  canvas.drawLine(
    const Offset(64, 260),
    const Offset(236, 260),
    _stroke(edition ? ink : line, 4),
  );
  canvas.drawLine(
    const Offset(150, 194),
    const Offset(150, 326),
    _stroke(edition ? ink : line, 4),
  );
  for (final point in const [
    Offset(150, 194),
    Offset(236, 260),
    Offset(150, 326),
    Offset(64, 260),
    Offset(150, 260),
  ]) {
    canvas.drawCircle(point, 9, _fill(edition ? line : art.accent));
    canvas.drawCircle(point, 9, _stroke(edition ? ink : line, 2));
  }

  for (var i = 0; i < 4; i++) {
    canvas.save();
    canvas.translate(60 + i * 52, 365);
    canvas.rotate((i - 1.5) * .08);
    final stickColor = !strategy && i == 0
        ? const Color(0xFFB83D37)
        : edition
        ? const Color(0xFFE6D2A2)
        : const Color(0xFFD7B878);
    final stick = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, -38, 16, 50),
      const Radius.circular(8),
    );
    canvas.drawRRect(stick, _fill(stickColor));
    canvas.drawRRect(stick, _stroke(line, 2));
    canvas.restore();
  }
  _text(
    canvas,
    'MOSIGAME',
    150,
    397,
    _grotesk(8, ink.withValues(alpha: .72), 3),
    align: TextAlign.center,
  );
}

//=======================선반 위 상자 옆면==============================
/// 선반에 꽂힌 상자의 옆면입니다. 누르면 그 게임을 고릅니다.
class MosiGameSpine extends StatelessWidget {
  const MosiGameSpine({
    super.key,
    required this.gameId,
    required this.onTap,
    this.fallbackName,
    this.displayName,
    this.englishName,
    this.deep = MosiColors.navy,
    this.width = 46,
    this.height = 288,
  });

  final String gameId;
  final VoidCallback onTap;
  final String? fallbackName;
  final String? displayName;
  final String? englishName;
  final Color deep;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final art = MosiGameArt.of(gameId, fallbackName: fallbackName);
    final localizedTitle = displayName?.trim().isNotEmpty == true
        ? displayName!.trim()
        : _localizedGameTitle(art);
    final englishTitleValue = englishName?.trim().isNotEmpty == true
        ? englishName!.trim()
        : art.englishName;
    final englishTitle = Text(
      englishTitleValue,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: gameId == 'mafia'
          ? MosiFonts.grotesk(size: 16, color: art.spineText, letterSpacing: 4)
          : MosiFonts.playfair(
              size: 18,
              color: art.spineText,
              letterSpacing: 1,
            ),
    );
    if (gameId == 'final_call') {
      return Semantics(
        button: true,
        label: GameLocale.select(
          ko: '$localizedTitle 선택',
          en: 'Select $localizedTitle',
          zhHans: '选择 $localizedTitle',
          zhHant: '選擇 $localizedTitle',
        ),
        excludeSemantics: true,
        child: GestureDetector(
          onTap: onTap,
          child: _FinalCallSpine(
            title: englishTitleValue,
            deep: deep,
            width: width,
            height: height,
          ),
        ),
      );
    }
    return Semantics(
      button: true,
      label: GameLocale.select(
        ko: '$localizedTitle 선택',
        en: 'Select $localizedTitle',
        zhHans: '选择 $localizedTitle',
        zhHant: '選擇 $localizedTitle',
      ),
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: width,
          height: height,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: art.spineColor,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: MosiColors.ink, width: 3),
            boxShadow: [BoxShadow(color: deep, offset: const Offset(5, 5))],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SpineBadge(gameId: gameId),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: RotatedBox(
                    quarterTurns: 1,
                    child: Center(child: englishTitle),
                  ),
                ),
              ),
              switch (gameId) {
                'final_call' => Container(
                  width: 8,
                  height: 22,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5DB00),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                'mafia' => Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF0000),
                    shape: BoxShape.circle,
                  ),
                ),
                _ => RotatedBox(
                  quarterTurns: 1,
                  child: Text(
                    localizedTitle,
                    style: MosiFonts.sans(
                      size: 11,
                      weight: FontWeight.w700,
                      color: art.spineText,
                    ),
                  ),
                ),
              },
            ],
          ),
        ),
      ),
    );
  }
}

/// New Yut covers can also appear in contexts without a GameInfo object.
/// Keep those covers in sync with the app language instead of falling back to
/// the Korean catalog label.
String _localizedGameTitle(MosiGameArt art) => switch (art.id) {
  'yut' => GameLocale.select(
    ko: '윷놀이',
    en: 'Yut Nori',
    zhHans: '掷柶游戏',
    zhHant: '擲柶遊戲',
  ),
  'strategy_yut' => GameLocale.select(
    ko: '전략 윷놀이',
    en: 'Strategy Yut',
    zhHans: '策略掷柶',
    zhHant: '策略擲柶',
  ),
  'strategy_yut_edition' => GameLocale.select(
    ko: '전략 윷놀이 에디션',
    en: 'Strategy Yut · Edition',
    zhHans: '策略掷柶 · 特别版',
    zhHant: '策略擲柶 · 特別版',
  ),
  'liars_poker' => GameLocale.select(
    ko: '라이어스 포커',
    en: "Liar's Poker",
    zhHans: '骗子扑克',
    zhHant: '騙子撲克',
  ),
  'final_call' => GameLocale.select(
    ko: '파이널 콜',
    en: 'Final Call',
    zhHans: '最后叫牌',
    zhHant: '最後叫牌',
  ),
  'mafia' => GameLocale.select(
    ko: '마피아',
    en: 'Mafia',
    zhHans: '黑手党',
    zhHant: '黑手黨',
  ),
  'holdem' => GameLocale.select(
    ko: '텍사스 홀덤',
    en: "Texas Hold'em",
    zhHans: '德州扑克',
    zhHant: '德州撲克',
  ),
  _ => art.koreanName,
};

class _SpineBadge extends StatelessWidget {
  const _SpineBadge({required this.gameId});

  final String gameId;

  @override
  Widget build(BuildContext context) {
    final (background, border, label, labelColor) = switch (gameId) {
      'final_call' => (
        const Color(0xFF111111),
        const Color(0xFFE0302E),
        '7',
        MosiColors.white,
      ),
      'mafia' => (const Color(0xFFFFC400), MosiColors.ink, '', MosiColors.ink),
      _ => (MosiColors.white, MosiColors.ink, 'A', MosiColors.ink),
    };
    return Container(
      width: 22,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(gameId == 'mafia' ? 11 : 3),
        border: Border.all(color: border, width: 1.5),
      ),
      child: Text(
        label,
        style: MosiFonts.playfair(size: 14, color: labelColor),
      ),
    );
  }
}

/// 아직 비어 있는 선반 칸입니다.
class MosiEmptySpine extends StatelessWidget {
  const MosiEmptySpine({super.key, required this.color, this.height = 266});

  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '곧 나올 게임'.localized,
      excludeSemantics: true,
      child: MosiDashedBorder(
        color: color,
        radius: 4,
        child: SizedBox(
          width: 46,
          height: height,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(Icons.add_rounded, size: 16, color: color),
                RotatedBox(
                  quarterTurns: 1,
                  child: Text(
                    'COMING SOON',
                    style: MosiFonts.grotesk(
                      size: 12,
                      color: color,
                      letterSpacing: 3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

//=======================자리 배치 테마==============================
/// 좌우 팀 자리배치에서 한 진영의 표시를 정의합니다.
@immutable
class MosiSeatTeamSide {
  const MosiSeatTeamSide({
    required this.nameKo,
    required this.nameEn,
    required this.nameZhHans,
    required this.nameZhHant,
    required this.markKo,
    required this.markEn,
    required this.markZhHans,
    required this.markZhHant,
    required this.accent,
    required this.zone,
    required this.badge,
    required this.badgeFg,
  });

  final String nameKo;
  final String nameEn;
  final String nameZhHans;
  final String nameZhHant;
  final String markKo;
  final String markEn;
  final String markZhHans;
  final String markZhHant;
  final Color accent;
  final Color zone;
  final Color badge;
  final Color badgeFg;

  String get name => GameLocale.select(
    ko: nameKo,
    en: nameEn,
    zhHans: nameZhHans,
    zhHant: nameZhHant,
  );

  String get mark => GameLocale.select(
    ko: markKo,
    en: markEn,
    zhHans: markZhHans,
    zhHant: markZhHant,
  );
}

/// 짝수 좌석은 왼쪽, 홀수 좌석은 오른쪽인 4인 팀전 자리배치입니다.
@immutable
class MosiSeatTeams {
  const MosiSeatTeams({
    required this.left,
    required this.right,
    required this.divider,
  });

  final MosiSeatTeamSide left;
  final MosiSeatTeamSide right;
  final Color divider;
}

/// 자리 배치 화면(시안 SeatSync)의 게임별 색입니다.
@immutable
class MosiSeatTheme {
  const MosiSeatTheme({
    required this.ground,
    required this.deep,
    required this.table,
    required this.dots,
    required this.pill,
    required this.pillLine,
    required this.button,
    required this.buttonFg,
    required this.selected,
    required this.ring,
    this.teams,
    this.tableFit = 0.93,
    this.tableDy = -0.014,
  });

  final Color ground;
  final Color deep;
  final Color table;
  final Color dots;
  final Color pill;
  final Color pillLine;
  final Color button;
  final Color buttonFg;
  final Color selected;
  final Color ring;
  final MosiSeatTeams? teams;

  /// 플랫 테이블이 실제 테이블 그림의 '보이는 원'과 맞도록 하는 비율·위치입니다.
  final double tableFit;
  final double tableDy;

  static const liarsPoker = MosiSeatTheme(
    ground: Color(0xFF4A1A5E),
    deep: Color(0xFF1B1022),
    table: Color(0xFF6E2A82),
    dots: Color(0x14FFFFFF),
    pill: Color(0x991B1022),
    pillLine: Color(0x99F2C14E),
    button: Color(0xFFF2C14E),
    buttonFg: Color(0xFF1B1022),
    selected: Color(0xFFF2C14E),
    ring: Color(0x99F2C14E),
    tableFit: 0.921,
    tableDy: -0.0144,
  );

  static const finalCall = MosiSeatTheme(
    ground: Color(0xFF141414),
    deep: Color(0xFF000000),
    table: Color(0xFFF7F6F2),
    dots: Color(0x12FFFFFF),
    pill: Color(0x14FFFFFF),
    pillLine: Color(0x99E5DB00),
    button: Color(0xFFE5DB00),
    buttonFg: Color(0xFF141414),
    selected: Color(0xFFE5DB00),
    ring: Color(0x99E5DB00),
    tableFit: 0.937,
    tableDy: -0.0136,
  );

  static const mafia = MosiSeatTheme(
    ground: Color(0xFF10131A),
    deep: Color(0xFF000000),
    table: Color(0xFF212730),
    dots: Color(0x0FFFFFFF),
    pill: Color(0x0DFFFFFF),
    pillLine: Color(0x80FF2A2A),
    button: Color(0xFFFF2A2A),
    buttonFg: MosiColors.white,
    selected: Color(0xFFFFD6D6),
    ring: Color(0x8CFF2A2A),
  );

  static const holdem = MosiSeatTheme(
    ground: Color(0xFF07130F),
    deep: Color(0xFF031E16),
    table: Color(0xFF0A5B3E),
    dots: Color(0x12FFFFFF),
    pill: Color(0xB3063B2B),
    pillLine: Color(0x99D7B56D),
    button: Color(0xFFD7B56D),
    buttonFg: Color(0xFF101713),
    selected: Color(0xFFF7F1DE),
    ring: Color(0x99D7B56D),
    tableFit: 0.93,
  );

  static const fallback = MosiSeatTheme(
    ground: MosiColors.navy,
    deep: MosiColors.navyDeepest,
    table: MosiColors.violet,
    dots: Color(0x14FFFFFF),
    pill: Color(0x14FFFFFF),
    pillLine: Color(0x99A4D65E),
    button: MosiColors.lime,
    buttonFg: MosiColors.navy,
    selected: MosiColors.lime,
    ring: Color(0x99A4D65E),
  );

  static const strategyYut = MosiSeatTheme(
    ground: MosiColors.navy,
    deep: MosiColors.navyDeepest,
    table: MosiColors.violet,
    dots: Color(0x14FFFFFF),
    pill: Color(0x14FFFFFF),
    pillLine: Color(0x99A4D65E),
    button: MosiColors.lime,
    buttonFg: MosiColors.navy,
    selected: MosiColors.lime,
    ring: Color(0x99A4D65E),
    teams: MosiSeatTeams(
      left: MosiSeatTeamSide(
        nameKo: '청군',
        nameEn: 'Blue Team',
        nameZhHans: '青军',
        nameZhHant: '青軍',
        markKo: '청',
        markEn: 'B',
        markZhHans: '青',
        markZhHant: '青',
        accent: Color(0xFF71B0FF),
        zone: Color(0x323478DF),
        badge: Color(0xFF397DE7),
        badgeFg: MosiColors.white,
      ),
      right: MosiSeatTeamSide(
        nameKo: '백군',
        nameEn: 'White Team',
        nameZhHans: '白军',
        nameZhHant: '白軍',
        markKo: '백',
        markEn: 'W',
        markZhHans: '白',
        markZhHant: '白',
        accent: Color(0xFFFFF9E9),
        zone: Color(0x20F7F4EC),
        badge: Color(0xFFEAE7DF),
        badgeFg: MosiColors.navy,
      ),
      divider: MosiColors.lime,
    ),
  );

  static MosiSeatTheme of(String? gameId) => switch (gameId) {
    'liars_poker' => liarsPoker,
    'final_call' => finalCall,
    'mafia' => mafia,
    'holdem' => holdem,
    'strategy_yut' || 'strategy_yut_edition' => strategyYut,
    _ => fallback,
  };
}

//=======================파이널콜 표지·책등 (코드로 그림)==============================
const Color _fcRed = Color(0xFFFF5A5F);
const Color _fcBlue = Color(0xFF3D7BFF);
const Color _fcYellow = Color(0xFFFFC93C);
const Color _fcInk = Color(0xFF1B1530);

/// 외곽선과 아래 그림자를 가진 굵은 흰 글자입니다.
Widget _fcTitleText(String text, double size, {double stroke = 10}) {
  TextStyle style({Color? color, Paint? foreground}) => TextStyle(
    fontFamily: MosiFonts.body,
    package: MosiFonts.package,
    fontSize: size,
    fontWeight: FontWeight.w700,
    height: 1,
    color: foreground == null ? color : null,
    foreground: foreground,
  );
  Paint pen(double width) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeJoin = StrokeJoin.round
    ..color = _fcInk;
  return Stack(
    clipBehavior: Clip.none,
    children: [
      Transform.translate(
        offset: Offset(0, size * .09),
        child: Text(text, style: style(foreground: pen(stroke + 2))),
      ),
      Text(text, style: style(foreground: pen(stroke))),
      Text(text, style: style(color: Colors.white)),
    ],
  );
}

class _FcDots extends CustomPainter {
  const _FcDots();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x2EFFFFFF);
    for (var y = 12.0; y < size.height; y += 24) {
      for (var x = 12.0; x < size.width; x += 24) {
        canvas.drawCircle(Offset(x, y), 2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FcBurst extends CustomPainter {
  const _FcBurst();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final path = Path();
    const points = 10;
    for (var i = 0; i < points * 2; i++) {
      final angle = -math.pi / 2 + i * math.pi / points;
      final radius = size.width / 2 * (i.isEven ? 1 : .68);
      final point = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      i == 0
          ? path.moveTo(point.dx, point.dy)
          : path.lineTo(point.dx, point.dy);
    }
    path.close();
    canvas.drawPath(path.shift(const Offset(0, 5)), Paint()..color = _fcInk);
    canvas.drawPath(path, Paint()..color = _fcYellow);
    canvas.drawPath(
      path,
      Paint()
        ..color = _fcInk
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 숫자 카드 한 장입니다(게임의 색 카드와 같은 모양).
class _FcCard extends StatelessWidget {
  const _FcCard({
    required this.color,
    required this.value,
    required this.angle,
  });

  final Color color;
  final int value;
  final double angle;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: angle * math.pi / 180,
    child: Container(
      width: 78,
      height: 110,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _fcInk, width: 3),
        boxShadow: const [BoxShadow(color: _fcInk, offset: Offset(0, 4))],
      ),
      child: Text(
        '$value',
        style: TextStyle(
          fontFamily: MosiFonts.body,
          package: MosiFonts.package,
          fontSize: 54,
          fontWeight: FontWeight.w700,
          height: 1,
          color: Colors.white,
          shadows: const [Shadow(color: _fcInk, offset: Offset(3, 3))],
        ),
      ),
    ),
  );
}

/// 파이널콜 표지: 위 파랑 팀과 아래 빨강 팀이 마주 보는 정면 대치입니다.
class _FinalCallCover extends StatelessWidget {
  const _FinalCallCover({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final words = title.trim().toUpperCase().split(RegExp(r'\s+'));
    final first = words.first;
    final second = words.length > 1 ? words.skip(1).join(' ') : null;
    Widget half(Color color) => Expanded(
      child: CustomPaint(
        painter: const _FcDots(),
        child: ColoredBox(color: color, child: const SizedBox.expand()),
      ),
    );
    return Stack(
      children: [
        Positioned.fill(
          child: Column(
            children: [
              half(_fcBlue),
              Container(height: 6, color: _fcInk),
              half(_fcRed),
            ],
          ),
        ),
        const Positioned(
          left: 40,
          top: 20,
          child: _FcCard(color: _fcBlue, value: 7, angle: 188),
        ),
        const Positioned(
          left: 118,
          top: 14,
          child: _FcCard(color: _fcBlue, value: 2, angle: 172),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: second == null ? 168 : 134,
          child: Center(child: _fcTitleText(first, 56)),
        ),
        if (second != null)
          Positioned(
            left: 0,
            right: 0,
            top: 206,
            child: Center(child: _fcTitleText(second, 56)),
          ),
        Positioned(
          right: 4,
          top: 170,
          width: 54,
          height: 54,
          child: CustomPaint(
            painter: const _FcBurst(),
            child: Center(
              child: Text(
                'VS',
                style: TextStyle(
                  fontFamily: MosiFonts.body,
                  package: MosiFonts.package,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  color: _fcInk,
                ),
              ),
            ),
          ),
        ),
        const Positioned(
          left: 56,
          bottom: 18,
          child: _FcCard(color: _fcRed, value: 7, angle: -8),
        ),
        const Positioned(
          left: 134,
          bottom: 24,
          child: _FcCard(color: _fcRed, value: 3, angle: 8),
        ),
      ],
    );
  }
}

/// 파이널콜 책등: 위 파랑·아래 빨강 반반에 흰 제목을 세로로 씁니다.
class _FinalCallSpine extends StatelessWidget {
  const _FinalCallSpine({
    required this.title,
    required this.deep,
    required this.width,
    required this.height,
  });

  final String title;
  final Color deep;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: MosiColors.ink, width: 3),
      boxShadow: [BoxShadow(color: deep, offset: const Offset(5, 5))],
    ),
    child: Stack(
      children: [
        Positioned.fill(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Expanded(child: ColoredBox(color: _fcBlue)),
              Container(height: 4, color: _fcInk),
              const Expanded(child: ColoredBox(color: _fcRed)),
            ],
          ),
        ),
        Center(
          child: RotatedBox(
            quarterTurns: 1,
            child: _fcTitleText(title.toUpperCase(), 17, stroke: 5),
          ),
        ),
      ],
    ),
  );
}
