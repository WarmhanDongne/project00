// [mosi_game_art.dart] 는 게임 상자 표지와 선반 위 상자 옆면을 그리는 파일이다.
//
// - [Package] : 게임 공통 기반
// - [Design] : 시안의 300×400 표지를 Flutter 캔버스와 패키지 이미지로 구성
//
// 선반, 게임 상세, 상점, 게임 안 설정 모달이 같은 표지를 씁니다. 표지 그림이
// 없는 게임(새로 추가된 게임)은 이름으로 만든 기본 표지를 그립니다.

// ========================[ import ]==========================
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';

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
    spineColor: Color(0xFF141414),
    spineText: MosiColors.white,
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
    shelfTheme: MosiShelfTheme.court,
    spineColor: Color(0xFF063B2B),
    spineText: Color(0xFFF7F1DE),
    accent: Color(0xFFD7B56D),
  );

  static const _known = <String, MosiGameArt>{
    'liars_poker': liarsPoker,
    'final_call': finalCall,
    'mafia': mafia,
    'holdem': holdem,
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
        spineColor: MosiColors.navy,
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
  });

  final String gameId;
  final double width;

  /// 오프셋 그림자 크기입니다. null이면 너비의 4.7%입니다.
  final double? shadow;
  final Color shadowColor;
  final String? fallbackName;

  /// 그림이 등록되지 않은 게임은 서버 이미지를 표지로 씁니다.
  final String? fallbackImageUrl;

  @override
  Widget build(BuildContext context) {
    final height = width * 4 / 3;
    final s = shadow ?? (width * 0.047).roundToDouble();
    final known = MosiGameArt.isKnown(gameId);
    final imageUrl = fallbackImageUrl;
    Widget art;
    if (gameId == 'holdem') {
      art = Image.asset(
        'packages/game_kit/assets/images/covers/holdem_cardbox.webp',
        key: const Key('holdem-cardbox-cover'),
        width: width,
        height: height,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
      );
    } else if (known) {
      art = CustomPaint(
        size: Size(width, height),
        painter: _CoverPainter(gameId: gameId),
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
    final name = MosiGameArt.of(gameId, fallbackName: fallbackName).koreanName;
    return Semantics(
      image: true,
      label: '$name 상자 표지',
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
  const _CoverPainter({required this.gameId});

  final String gameId;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 300, size.height / 400);
    switch (gameId) {
      case 'liars_poker':
        _paintLiar(canvas);
      case 'final_call':
        _paintFinal(canvas);
      case 'mafia':
        _paintMafia(canvas);
      case 'holdem':
        _paintHoldem(canvas);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CoverPainter oldDelegate) =>
      oldDelegate.gameId != gameId;
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
}) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  )..layout();
  final baseline = painter.computeDistanceToActualBaseline(
    TextBaseline.alphabetic,
  );
  final dx = switch (align) {
    TextAlign.center => x - painter.width / 2,
    TextAlign.right || TextAlign.end => x - painter.width,
    _ => x,
  };
  painter.paint(canvas, Offset(dx, y - baseline));
}

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
void _paintLiar(Canvas canvas) {
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 300, 400),
    _fill(const Color(0xFF4A1A5E)),
  );
  canvas.drawCircle(
    const Offset(150, 300),
    190,
    _fill(const Color(0xFF5A2272)),
  );
  _text(canvas, "LIAR'S", 24, 62, _playfair(44, const Color(0xFFF8F4FA)));
  _text(canvas, 'POKER', 24, 106, _playfair(44, const Color(0xFFF8F4FA)));
  _text(canvas, '라이어스 포커', 26, 132, _plex(14, const Color(0xFFC7B8CC)));
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
void _paintFinal(Canvas canvas) {
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 300, 400),
    _fill(const Color(0xFFEFEDE8)),
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
  _text(canvas, 'FINAL', 24, 62, _playfair(46, const Color(0xFF141414)));
  canvas.drawRect(
    const Rect.fromLTWH(22, 76, 134, 30),
    _fill(const Color(0xFFE5DB00)),
  );
  _text(canvas, 'CALL', 24, 104, _playfair(46, const Color(0xFF141414)));
  _text(canvas, '파이널콜', 26, 132, _plex(14, const Color(0xFF141414)));
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
void _paintMafia(Canvas canvas) {
  const night = Color(0xFF10131A);
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
    '마피아',
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
  _text(
    canvas,
    'MAFIA',
    150,
    382,
    _grotesk(16, night, 8),
    align: TextAlign.center,
  );
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

//=======================선반 위 상자 옆면==============================
/// 선반에 꽂힌 상자의 옆면입니다. 누르면 그 게임을 고릅니다.
class MosiGameSpine extends StatelessWidget {
  const MosiGameSpine({
    super.key,
    required this.gameId,
    required this.onTap,
    this.fallbackName,
    this.deep = MosiColors.navy,
    this.width = 46,
    this.height = 288,
  });

  final String gameId;
  final VoidCallback onTap;
  final String? fallbackName;
  final Color deep;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final art = MosiGameArt.of(gameId, fallbackName: fallbackName);
    final englishTitle = Text(
      art.englishName,
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
    return Semantics(
      button: true,
      label: '${art.koreanName} 선택',
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
                    art.koreanName,
                    style: MosiFonts.sans(
                      size: 11,
                      weight: FontWeight.w700,
                      color: const Color(0xFFC7B8CC),
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
      label: '곧 나올 게임',
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

  static MosiSeatTheme of(String? gameId) => switch (gameId) {
    'liars_poker' => liarsPoker,
    'final_call' => finalCall,
    'mafia' => mafia,
    'holdem' => holdem,
    _ => fallback,
  };
}
