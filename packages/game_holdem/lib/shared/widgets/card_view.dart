import 'package:flutter/material.dart';
import 'package:game_holdem/game_assets.dart';
import 'package:game_holdem/game_theme.dart';
import 'package:game_holdem/shared/models/game_models.dart';

/// 카드 앞면의 배치 방식입니다.
enum HoldemCardLayout {
  /// 태블릿 공용 테이블처럼 여러 방향에서 보는 정대칭 카드입니다.
  table,

  /// 휴대폰 손패처럼 한 방향에서 보는 비대칭 카드입니다.
  hand,

  /// 휴대폰 보드 요약처럼 rank와 무늬만 보이는 작은 카드입니다.
  mini,
}

/// 쇼다운에서 카드가 최종 5장에 들었는지 표시합니다.
enum HoldemCardEmphasis { none, win, lose }

/// 코드로 그리는 홀덤 카드입니다. 뒷면은 패키지에 포함된 이미지를 씁니다.
class HoldemCardView extends StatelessWidget {
  const HoldemCardView({
    super.key,
    this.card,
    this.width = 78,
    this.layout = HoldemCardLayout.table,
    this.faceDown = false,
    this.emphasis = HoldemCardEmphasis.none,
  });

  static const aspectRatio = 1.44;

  final HoldemCardModel? card;
  final double width;
  final HoldemCardLayout layout;
  final bool faceDown;
  final HoldemCardEmphasis emphasis;

  @override
  Widget build(BuildContext context) {
    final height = width * aspectRatio;
    final radius = BorderRadius.circular(width * .115);
    final face = card;
    final shadow = BoxShadow(
      color: Colors.black.withValues(alpha: .45),
      blurRadius: width * .18,
      offset: Offset(0, width * .075),
    );
    if (faceDown || face == null) {
      return Semantics(
        image: true,
        excludeSemantics: true,
        label: '뒷면 카드',
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: radius,
            color: Colors.white,
            boxShadow: [shadow],
          ),
          clipBehavior: Clip.antiAlias,
          child: HoldemAssets.cardBack.image(
            width: width,
            height: height,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const ColoredBox(color: Colors.white),
          ),
        ),
      );
    }
    final suit = HoldemSuit.from(face.suit);
    final color = suit.red ? HoldemColors.cardRed : HoldemColors.cardBlack;
    final rank = holdemRankLabel(face.rank);
    final shadows = [
      if (emphasis == HoldemCardEmphasis.win) ...[
        const BoxShadow(color: HoldemColors.ivory, spreadRadius: 3),
        BoxShadow(
          color: HoldemColors.ivory.withValues(alpha: .65),
          blurRadius: 24,
          spreadRadius: 3,
        ),
      ] else
        shadow,
    ];
    final cardFace = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: HoldemColors.cardFace,
        borderRadius: radius,
        border: Border.all(color: HoldemColors.cardEdge),
        boxShadow: shadows,
      ),
      child: switch (layout) {
        HoldemCardLayout.table => _TableFace(
          width: width,
          rank: rank,
          suit: suit,
          color: color,
        ),
        HoldemCardLayout.hand => _HandFace(
          width: width,
          rank: rank,
          suit: suit,
          color: color,
        ),
        HoldemCardLayout.mini => _MiniFace(
          width: width,
          rank: rank,
          suit: suit,
          color: color,
        ),
      },
    );
    return Semantics(
      image: true,
      excludeSemantics: true,
      label: '${suit.label} $rank',
      child: emphasis == HoldemCardEmphasis.lose
          ? Opacity(opacity: .35, child: cardFace)
          : cardFace,
    );
  }
}

class _RankMark extends StatelessWidget {
  const _RankMark({
    required this.rank,
    required this.suit,
    required this.color,
    required this.fontSize,
    required this.suitSize,
  });
  final String rank;
  final HoldemSuit suit;
  final Color color;
  final double fontSize;
  final double suitSize;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        rank,
        maxLines: 1,
        softWrap: false,
        style: TextStyle(
          fontFamily: HoldemFonts.card,
          fontVariations: HoldemFonts.cardVariations,
          fontWeight: FontWeight.w700,
          fontSize: fontSize,
          height: 1,
          letterSpacing: rank.length > 1 ? -fontSize * .08 : 0,
          color: color,
        ),
      ),
      SizedBox(height: suitSize * .2),
      HoldemSuitIcon(suit: suit, size: suitSize, color: color),
    ],
  );
}

class _TableFace extends StatelessWidget {
  const _TableFace({
    required this.width,
    required this.rank,
    required this.suit,
    required this.color,
  });
  final double width;
  final String rank;
  final HoldemSuit suit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final mark = _RankMark(
      rank: rank,
      suit: suit,
      color: color,
      fontSize: width * .31,
      suitSize: width * .167,
    );
    return Stack(
      children: [
        Positioned(left: width * .07, top: width * .065, child: mark),
        Center(
          child: HoldemSuitIcon(suit: suit, size: width * .436, color: color),
        ),
        Positioned(
          right: width * .07,
          bottom: width * .065,
          child: RotatedBox(quarterTurns: 2, child: mark),
        ),
      ],
    );
  }
}

class _HandFace extends StatelessWidget {
  const _HandFace({
    required this.width,
    required this.rank,
    required this.suit,
    required this.color,
  });
  final double width;
  final String rank;
  final HoldemSuit suit;
  final Color color;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned(
        left: width * .09,
        top: width * .075,
        child: _RankMark(
          rank: rank,
          suit: suit,
          color: color,
          fontSize: width * .333,
          suitSize: width * .167,
        ),
      ),
      Positioned(
        right: width * .106,
        bottom: width * .106,
        child: HoldemSuitIcon(suit: suit, size: width * .47, color: color),
      ),
    ],
  );
}

class _MiniFace extends StatelessWidget {
  const _MiniFace({
    required this.width,
    required this.rank,
    required this.suit,
    required this.color,
  });
  final double width;
  final String rank;
  final HoldemSuit suit;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(left: width * .1, top: width * .08),
    child: Align(
      alignment: Alignment.topLeft,
      child: _RankMark(
        rank: rank,
        suit: suit,
        color: color,
        fontSize: width * .41,
        suitSize: width * .26,
      ),
    ),
  );
}

/// 아직 공개되지 않은 커뮤니티 카드 자리입니다.
class HoldemCardSlot extends StatelessWidget {
  const HoldemCardSlot({super.key, this.width = 78});
  final double width;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size(width, width * HoldemCardView.aspectRatio),
    painter: HoldemDashedRectPainter(
      color: HoldemColors.line(.3),
      radius: width * .115,
    ),
  );
}

/// 빈 자리와 카드 자리의 점선 테두리입니다.
class HoldemDashedRectPainter extends CustomPainter {
  const HoldemDashedRectPainter({
    required this.color,
    required this.radius,
    this.strokeWidth = 1.5,
    this.dash = 5,
    this.gap = 4,
  });
  final Color color;
  final double radius;
  final double strokeWidth;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final inset = strokeWidth / 2;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            inset,
            inset,
            size.width - strokeWidth,
            size.height - strokeWidth,
          ),
          Radius.circular(radius),
        ),
      );
    for (final metric in path.computeMetrics()) {
      for (
        var distance = 0.0;
        distance < metric.length;
        distance += dash + gap
      ) {
        canvas.drawPath(metric.extractPath(distance, distance + dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(HoldemDashedRectPainter oldDelegate) =>
      color != oldDelegate.color ||
      radius != oldDelegate.radius ||
      strokeWidth != oldDelegate.strokeWidth;
}

/// 서버 카드 suit 문자열을 화면 무늬로 바꿉니다.
enum HoldemSuit {
  spades('스페이드', false),
  hearts('하트', true),
  diamonds('다이아몬드', true),
  clubs('클로버', false);

  const HoldemSuit(this.label, this.red);
  final String label;
  final bool red;

  static HoldemSuit from(String value) => switch (value) {
    'hearts' => hearts,
    'diamonds' => diamonds,
    'clubs' => clubs,
    _ => spades,
  };
}

/// 서버 rank(`a`, `2`–`10`, `j`, `q`, `k`)를 카드 글자로 바꿉니다.
String holdemRankLabel(String rank) => rank.toUpperCase();

/// 24×24 시안 좌표로 그린 카드 무늬입니다.
class HoldemSuitIcon extends StatelessWidget {
  const HoldemSuitIcon({
    super.key,
    required this.suit,
    required this.size,
    required this.color,
  });
  final HoldemSuit suit;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _SuitPainter(suit, color));
}

class _SuitPainter extends CustomPainter {
  const _SuitPainter(this.suit, this.color);
  final HoldemSuit suit;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final paint = Paint()..color = color;
    switch (suit) {
      case HoldemSuit.spades:
        canvas.drawPath(
          Path()
            ..moveTo(12, 2)
            ..cubicTo(10, 5.2, 3, 9.4, 3, 13.9)
            ..cubicTo(3, 16.6, 5, 18.4, 7.4, 18.4)
            ..cubicTo(8.9, 18.4, 10.2, 17.7, 10.9, 16.6)
            ..cubicTo(10.7, 18.7, 9.9, 20.1, 8.3, 21.5)
            ..lineTo(15.7, 21.5)
            ..cubicTo(14.1, 20.1, 13.3, 18.7, 13.1, 16.6)
            ..cubicTo(13.8, 17.7, 15.1, 18.4, 16.6, 18.4)
            ..cubicTo(19, 18.4, 21, 16.6, 21, 13.9)
            ..cubicTo(21, 9.4, 14, 5.2, 12, 2)
            ..close(),
          paint,
        );
      case HoldemSuit.hearts:
        canvas.drawPath(
          Path()
            ..moveTo(12, 21.2)
            ..cubicTo(12, 21.2, 3.7, 16.2, 2.3, 10.9)
            ..cubicTo(1.4, 7.4, 3.5, 4, 7, 4)
            ..cubicTo(9.2, 4, 10.8, 5.2, 12, 7)
            ..cubicTo(13.2, 5.2, 14.8, 4, 17, 4)
            ..cubicTo(20.5, 4, 22.6, 7.4, 21.7, 10.9)
            ..cubicTo(20.3, 16.2, 12, 21.2, 12, 21.2)
            ..close(),
          paint,
        );
      case HoldemSuit.diamonds:
        canvas.drawPath(
          Path()
            ..moveTo(12, 2)
            ..lineTo(19.5, 12)
            ..lineTo(12, 22)
            ..lineTo(4.5, 12)
            ..close(),
          paint,
        );
      case HoldemSuit.clubs:
        canvas
          ..drawCircle(const Offset(12, 7), 4.4, paint)
          ..drawCircle(const Offset(6.8, 13.6), 4.4, paint)
          ..drawCircle(const Offset(17.2, 13.6), 4.4, paint)
          ..drawPath(
            Path()
              ..moveTo(10.6, 10.5)
              ..lineTo(13.4, 10.5)
              ..lineTo(15, 21.5)
              ..lineTo(9, 21.5)
              ..close(),
            paint,
          );
    }
  }

  @override
  bool shouldRepaint(_SuitPainter oldDelegate) =>
      suit != oldDelegate.suit || color != oldDelegate.color;
}
