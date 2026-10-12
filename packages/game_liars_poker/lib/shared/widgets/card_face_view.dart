// [card_face_view.dart] 는 라이어스 포커 카드 앞면을 이미지 없이 코드로 그리는 파일이다.
//
// - [Package] : 라이어스 포커
// - [Widget] : A·K·Q·조커 앞면과 뒷면을 같은 크기 규칙으로 그림
//
// 즉, 카드 그림 파일 없이도 어느 화면 크기에서나 선명한 카드를 쓰기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:game_kit/localization/game_locale.dart';

// ============================================================

//=======================카드 종류==============================
/// 카드 한 장의 종류입니다. [back]은 뒷면입니다.
enum LiarsCardFace {
  ace('A'),
  king('K'),
  queen('Q'),
  joker('JOKER'),
  back('');

  const LiarsCardFace(this.value);

  /// 서버가 보내는 카드 값입니다.
  final String value;

  /// 서버의 카드 값을 앞면 종류로 바꿉니다. 모르는 값은 뒷면입니다.
  static LiarsCardFace fromValue(String value) => switch (value.toUpperCase()) {
    'A' => ace,
    'K' => king,
    'Q' => queen,
    'JOKER' => joker,
    _ => back,
  };

  /// 화면 읽기용 이름입니다.
  String get label => switch (this) {
    ace => GameLocale.select(
      ko: '에이스 카드',
      en: 'Ace card',
      zhHans: 'A 牌',
      zhHant: 'A 牌',
    ),
    king => GameLocale.select(
      ko: '킹 카드',
      en: 'King card',
      zhHans: 'K 牌',
      zhHant: 'K 牌',
    ),
    queen => GameLocale.select(
      ko: '퀸 카드',
      en: 'Queen card',
      zhHans: 'Q 牌',
      zhHant: 'Q 牌',
    ),
    joker => GameLocale.select(
      ko: '조커 카드',
      en: 'Joker card',
      zhHans: '王牌',
      zhHant: '鬼牌',
    ),
    back => GameLocale.select(
      ko: '카드 뒷면',
      en: 'Card back',
      zhHans: '卡牌背面',
      zhHant: '卡牌背面',
    ),
  };

  /// 모서리에 쓰는 글자입니다.
  String get corner => switch (this) {
    ace => 'A',
    king => 'K',
    queen => 'Q',
    joker => 'J',
    back => '',
  };
}

//=======================카드 그리기==============================
/// 카드를 그리는 기준 크기입니다. 실제 크기는 이 판을 통째로 늘이거나 줄입니다.
const Size liarsCardDesignSize = Size(200, 280);

const Color _ink = Color(0xFF1B1022);
const Color _ivory = Color(0xFFF8F5EE);
const Color _edge = Color(0xFFC8C0B4);

/// Playfair Display 대문자 높이가 글자 크기에서 차지하는 비율입니다.
const double _capRatio = 0.708;

/// 가운데 요소(A·K·Q 글자, 조커 덩어리)의 높이입니다. 네 카드가 모두 같습니다.
const double _blockHeight = 112;

/// Q의 꼬리까지 포함한 전체 높이가 몸통의 몇 배인지입니다(측정값).
const double _qTailRatio = 145 / 112;

/// 앞면 카드를 그립니다.
///
/// 폭·높이를 주지 않으면 부모가 주는 칸을 채웁니다(비율 1:1.4 기준).
/// [rounded]가 true면 둥근 모서리와 테두리까지 그리고, 부모가 이미 잘라 주면
/// false로 둡니다.
class LiarsPokerCardView extends StatelessWidget {
  const LiarsPokerCardView({
    super.key,
    required this.face,
    this.width,
    this.height,
    this.rounded = false,
  });

  final LiarsCardFace face;
  final double? width;
  final double? height;
  final bool rounded;

  @override
  Widget build(BuildContext context) {
    final Widget content = FittedBox(
      fit: BoxFit.cover,
      child: SizedBox.fromSize(
        size: liarsCardDesignSize,
        child: face == LiarsCardFace.back
            ? _CardBack(rounded: rounded)
            : _CardFront(face: face, rounded: rounded),
      ),
    );
    return Semantics(
      image: true,
      label: face.label,
      excludeSemantics: true,
      child: SizedBox(
        width: width ?? (height == null ? null : height! / 1.4),
        height: height ?? (width == null ? null : width! * 1.4),
        child: content,
      ),
    );
  }
}

/// 뒷면: 아이보리 바탕에 잉크색 가는 테두리 한 줄과 가운데 마름모 하나뿐입니다.
class _CardBack extends StatelessWidget {
  const _CardBack({required this.rounded});

  final bool rounded;

  @override
  Widget build(BuildContext context) {
    const w = 200.0;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _ivory,
        borderRadius: rounded ? BorderRadius.circular(w * .07) : null,
        border: rounded ? Border.all(color: _edge, width: 1.5) : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(w * .05),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(w * .035),
            border: Border.all(color: _ink.withValues(alpha: .7), width: 1.5),
          ),
          child: Center(
            child: Transform.rotate(
              angle: math.pi / 4,
              child: Container(
                width: w * .16,
                height: w * .16,
                decoration: BoxDecoration(
                  color: _ink,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CardFront extends StatelessWidget {
  const _CardFront({required this.face, required this.rounded});

  final LiarsCardFace face;
  final bool rounded;

  @override
  Widget build(BuildContext context) {
    const w = 200.0;
    const h = 280.0;
    Widget corner(bool flip) => Transform.rotate(
      angle: flip ? math.pi : 0,
      child: Text(face.corner, style: _style(w * .16, _ink)),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _ivory,
        borderRadius: rounded ? BorderRadius.circular(w * .07) : null,
        border: rounded ? Border.all(color: _edge, width: 1.5) : null,
      ),
      child: Stack(
        children: [
          Positioned(left: w * .07, top: w * .06, child: corner(false)),
          Positioned(right: w * .07, bottom: w * .06, child: corner(true)),
          Positioned.fill(
            child: face == LiarsCardFace.joker
                ? const _JokerBlock(width: w, height: h)
                : CustomPaint(painter: _LetterPainter(face)),
          ),
        ],
      ),
    );
  }
}

TextStyle _style(double size, Color color, {double? letterSpacing}) =>
    TextStyle(
      fontFamily: 'PlayfairDisplay',
      package: 'game_kit',
      fontSize: size,
      fontWeight: FontWeight.w700,
      color: color,
      height: 1,
      letterSpacing: letterSpacing,
    );

/// 대문자 높이 칸을 카드 정중앙에 맞춰 글자를 그립니다.
class _LetterPainter extends CustomPainter {
  const _LetterPainter(this.face);

  final LiarsCardFace face;

  @override
  void paint(Canvas canvas, Size size) {
    final isQ = face == LiarsCardFace.queen;
    // Q는 꼬리까지 포함한 전체 높이를 다른 글자와 맞춥니다.
    final fullSize = _blockHeight / _capRatio;
    final sizePx = isQ ? fullSize / _qTailRatio : fullSize;
    final painter = TextPainter(
      text: TextSpan(text: face.corner, style: _style(sizePx, _ink)),
      textDirection: TextDirection.ltr,
    )..layout();
    final baseline = painter.computeDistanceToActualBaseline(
      TextBaseline.alphabetic,
    );
    final capHeight = sizePx * _capRatio;
    final cy = size.height / 2;
    // 글자 모양이 좌우 비대칭이라 눈에 보이는 가운데로 조금 보정합니다.
    final dx = switch (face) {
      LiarsCardFace.ace => 2.0,
      LiarsCardFace.king => -3.0,
      _ => 0.0,
    };
    final dy = isQ ? -10.0 : 0.0;
    painter.paint(
      canvas,
      Offset(
        (size.width - painter.width) / 2 + dx,
        cy + capHeight / 2 - baseline + dy,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _LetterPainter old) => old.face != face;
}

/// 조커: 방울 달린 왕관과 JOKER 글자를 합친 덩어리를 A·K·Q와 같은 높이로 둡니다.
class _JokerBlock extends StatelessWidget {
  const _JokerBlock({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final fontSize = width * .12;
    final textCap = fontSize * _capRatio;
    final gap = width * .04;
    // J의 꼬리가 기준선 아래로 내려오므로 그만큼 글자를 올려 아래 끝을 맞춥니다.
    final jDescent = fontSize * .25;
    final crownInk = _blockHeight - textCap - gap - jDescent;
    final crownSize = crownInk / .82;
    final top = height / 2 - _blockHeight / 2;
    return Stack(
      children: [
        Positioned(
          left: (width - crownSize) / 2 - 1,
          top: top,
          child: CustomPaint(
            size: Size.square(crownSize),
            painter: const _CrownPainter(),
          ),
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: _JokerTextPainter(
              fontSize: fontSize,
              letterSpacing: width * .02,
              centerY: height / 2 + _blockHeight / 2 - jDescent - textCap / 2,
            ),
          ),
        ),
      ],
    );
  }
}

class _JokerTextPainter extends CustomPainter {
  const _JokerTextPainter({
    required this.fontSize,
    required this.letterSpacing,
    required this.centerY,
  });

  final double fontSize;
  final double letterSpacing;
  final double centerY;

  @override
  void paint(Canvas canvas, Size size) {
    final painter = TextPainter(
      text: TextSpan(
        text: 'JOKER',
        style: _style(fontSize, _ink, letterSpacing: letterSpacing),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final baseline = painter.computeDistanceToActualBaseline(
      TextBaseline.alphabetic,
    );
    painter.paint(
      canvas,
      Offset(
        (size.width - painter.width + letterSpacing) / 2 - 1,
        centerY + fontSize * _capRatio / 2 - baseline,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _JokerTextPainter old) =>
      old.fontSize != fontSize ||
      old.letterSpacing != letterSpacing ||
      old.centerY != centerY;
}

/// 방울 달린 광대 왕관입니다(0~1 칸 안).
class _CrownPainter extends CustomPainter {
  const _CrownPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width, size.height);
    final path = Path()
      ..moveTo(.1, .82)
      ..quadraticBezierTo(.0, .5, .06, .2)
      ..quadraticBezierTo(.28, .3, .36, .62)
      ..quadraticBezierTo(.42, .3, .5, .1)
      ..quadraticBezierTo(.58, .3, .64, .62)
      ..quadraticBezierTo(.72, .3, .94, .2)
      ..quadraticBezierTo(1.0, .5, .9, .82)
      ..close();
    final line = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 / size.width
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, line);
    for (final center in const [
      Offset(.06, .16),
      Offset(.5, .07),
      Offset(.94, .16),
    ]) {
      canvas.drawCircle(center, .07, Paint()..color = _ivory);
      canvas.drawCircle(center, .07, line);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
