// [party_pop.dart] 는 파이널콜 'Party Pop' 시안의 공용 생김새를 모아 둔 파일이다.
//
// - [Package] : 파이널콜
// - [Widget] : 태블릿·휴대폰이 함께 쓰는 배경, 테두리 상자, 버튼, 하트, 얼굴을 구성함
//
// 즉, 두 기기의 게임 화면이 같은 시안 언어로 보이도록 하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:game_final_call/game_theme.dart';
import 'package:game_final_call/shared/models/game_models.dart';
import 'package:game_kit/core/constants/room_character.dart';

// ============================================================

/// 시안 글자 스타일입니다. 시안의 Jua 글꼴은 번들하지 않아 공용 본문 글꼴
/// 굵게로 대체합니다.
TextStyle finalCallPopText(
  double size, {
  Color color = FinalCallColors.ink,
  List<Shadow>? shadows,
  double? height,
}) => TextStyle(
  fontFamily: 'IBMPlexSansKR',
  package: 'game_kit',
  fontSize: size,
  fontWeight: FontWeight.w700,
  color: color,
  height: height,
  shadows: shadows,
);

/// 흰 글자 아래 남색 그림자(2px 오프셋)입니다.
List<Shadow> finalCallPopOutline([double offset = 2]) => [
  Shadow(color: FinalCallColors.ink, offset: Offset(offset, offset)),
];

/// 팀 색입니다.
Color finalCallTeamColor(FinalCallTeam team) => switch (team) {
  FinalCallTeam.red => FinalCallColors.red,
  FinalCallTeam.blue => FinalCallColors.blue,
  FinalCallTeam.green => FinalCallColors.green,
};

/// 카드 색입니다.
Color finalCallCardColor(String color) => switch (color) {
  'blue' => FinalCallColors.blue,
  'green' => FinalCallColors.green,
  'yellow' => FinalCallColors.yellow,
  _ => FinalCallColors.red,
};

/// 카드 색의 한글 이름입니다.
String finalCallCardColorLabel(String color) => switch (color) {
  'blue' => '파랑',
  'green' => '초록',
  'yellow' => '노랑',
  _ => '빨강',
};

// ---------------------------------------------------------------------------
// 배경
// ---------------------------------------------------------------------------
/// 남보라 바탕에 옅은 점무늬를 깐 게임 배경입니다.
class FinalCallPopBackground extends StatelessWidget {
  const FinalCallPopBackground({super.key, this.spacing = 24, this.child});

  final double spacing;
  final Widget? child;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: FinalCallColors.night,
    child: CustomPaint(
      painter: _DotGridPainter(spacing),
      child: child ?? const SizedBox.expand(),
    ),
  );
}

class _DotGridPainter extends CustomPainter {
  const _DotGridPainter(this.spacing);

  final double spacing;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x14FFFFFF);
    for (var y = spacing / 2; y < size.height; y += spacing) {
      for (var x = spacing / 2; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter oldDelegate) =>
      oldDelegate.spacing != spacing;
}

// ---------------------------------------------------------------------------
// 테두리 상자
// ---------------------------------------------------------------------------
/// 굵은 남색 테두리와 아래로 떨어지는 단단한 그림자를 가진 상자입니다.
class FinalCallPopBox extends StatelessWidget {
  const FinalCallPopBox({
    super.key,
    required this.child,
    this.color = Colors.white,
    this.radius = 24,
    this.borderWidth = 4,
    this.shadowDepth = 6,
    this.borderColor = FinalCallColors.ink,
    this.padding,
    this.width,
    this.height,
    this.ringColor,
  });

  final Widget child;
  final Color color;
  final double radius;
  final double borderWidth;
  final double shadowDepth;
  final Color borderColor;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;

  /// 차례 강조처럼 바깥에 한 겹 더 두르는 색 테두리입니다.
  final Color? ringColor;

  @override
  Widget build(BuildContext context) {
    final ring = ringColor;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: ring ?? borderColor, width: borderWidth),
        boxShadow: [
          if (ring != null)
            BoxShadow(color: borderColor, spreadRadius: borderWidth),
          BoxShadow(
            color: borderColor,
            offset: Offset(0, shadowDepth),
            spreadRadius: ring != null ? borderWidth : 0,
          ),
        ],
      ),
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// 버튼
// ---------------------------------------------------------------------------
/// 누르면 그림자만큼 내려앉는 시안 버튼입니다.
class FinalCallPopButton extends StatefulWidget {
  const FinalCallPopButton({
    super.key,
    required this.child,
    required this.onPressed,
    required this.semanticLabel,
    this.color = Colors.white,
    this.height = 48,
    this.radius = 16,
    this.borderWidth = 3,
    this.shadowDepth = 4,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final String semanticLabel;
  final Color color;
  final double height;
  final double radius;
  final double borderWidth;
  final double shadowDepth;

  @override
  State<FinalCallPopButton> createState() => _FinalCallPopButtonState();
}

class _FinalCallPopButtonState extends State<FinalCallPopButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!mounted || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final depth = _pressed ? 1.0 : widget.shadowDepth;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      excludeSemantics: true,
      onTap: widget.onPressed,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        onTapDown: enabled ? (_) => _setPressed(true) : null,
        onTapUp: enabled ? (_) => _setPressed(false) : null,
        onTapCancel: enabled ? () => _setPressed(false) : null,
        child: AnimatedOpacity(
          opacity: enabled ? 1 : 0.45,
          duration: const Duration(milliseconds: 150),
          child: SizedBox(
            height: widget.height + widget.shadowDepth,
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 80),
              padding: EdgeInsets.only(
                top: widget.shadowDepth - depth,
                bottom: depth,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(widget.radius),
                  border: Border.all(
                    color: FinalCallColors.ink,
                    width: widget.borderWidth,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: FinalCallColors.ink,
                      offset: Offset(0, depth),
                    ),
                  ],
                ),
                child: Center(child: widget.child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 상단 모서리의 정사각형 아이콘 버튼(규칙·나가기)입니다.
class FinalCallPopIconButton extends StatelessWidget {
  const FinalCallPopIconButton({
    super.key,
    required this.semanticLabel,
    required this.onPressed,
    required this.child,
    this.size = 44,
    this.color = Colors.white,
  });

  final String semanticLabel;
  final VoidCallback onPressed;
  final Widget child;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    child: FinalCallPopButton(
      semanticLabel: semanticLabel,
      onPressed: onPressed,
      color: color,
      height: size - 3,
      radius: 14,
      shadowDepth: 3,
      child: child,
    ),
  );
}

/// 나가기 아이콘(문과 화살표)입니다.
class FinalCallExitGlyph extends StatelessWidget {
  const FinalCallExitGlyph({super.key, this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: const _ExitGlyphPainter());
}

class _ExitGlyphPainter extends CustomPainter {
  const _ExitGlyphPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    final paint = Paint()
      ..color = FinalCallColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6 * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    Offset p(double x, double y) => Offset(x * scale, y * scale);
    canvas
      ..drawPath(
        Path()
          ..moveTo(p(14, 4).dx, p(14, 4).dy)
          ..lineTo(p(19, 4).dx, p(19, 4).dy)
          ..lineTo(p(19, 20).dx, p(19, 20).dy)
          ..lineTo(p(14, 20).dx, p(14, 20).dy),
        paint,
      )
      ..drawPath(
        Path()
          ..moveTo(p(10, 8).dx, p(10, 8).dy)
          ..lineTo(p(6, 12).dx, p(6, 12).dy)
          ..lineTo(p(10, 16).dx, p(10, 16).dy),
        paint,
      )
      ..drawLine(p(6, 12), p(16, 12), paint);
  }

  @override
  bool shouldRepaint(_ExitGlyphPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// 하트
// ---------------------------------------------------------------------------
/// 팀 색으로 채운 하트입니다. [filled]가 false면 잃은 하트(흰 점선)입니다.
class FinalCallPopHeart extends StatelessWidget {
  const FinalCallPopHeart({
    super.key,
    required this.color,
    this.filled = true,
    this.size = 20,
  });

  final Color color;
  final bool filled;
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size(size, size * 22 / 24),
    painter: _HeartPainter(color: color, filled: filled),
  );
}

/// 시안 SVG의 하트 경로(24×22)를 그대로 옮긴 경로입니다.
Path finalCallHeartPath(Size size) {
  final sx = size.width / 24;
  final sy = size.height / 22;
  return Path()
    ..moveTo(12 * sx, 20 * sy)
    ..cubicTo(12 * sx, 20 * sy, 3.5 * sx, 14.6 * sy, 1.4 * sx, 9.7 * sy)
    ..cubicTo(0 * sx, 5.5 * sy, 3 * sx, 2 * sy, 7 * sx, 2 * sy)
    ..cubicTo(9.2 * sx, 2 * sy, 10.7 * sx, 3.2 * sy, 12 * sx, 4.6 * sy)
    ..cubicTo(13.3 * sx, 3.2 * sy, 14.8 * sx, 2 * sy, 17 * sx, 2 * sy)
    ..cubicTo(21 * sx, 2 * sy, 24 * sx, 5.5 * sy, 22.6 * sx, 9.7 * sy)
    ..cubicTo(20.5 * sx, 14.6 * sy, 12 * sx, 20 * sy, 12 * sx, 20 * sy)
    ..close();
}

class _HeartPainter extends CustomPainter {
  const _HeartPainter({required this.color, required this.filled});

  final Color color;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final path = finalCallHeartPath(size);
    canvas.drawPath(path, Paint()..color = filled ? color : Colors.white);
    final stroke = Paint()
      ..color = FinalCallColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2 * size.width / 24
      ..strokeJoin = StrokeJoin.round;
    if (filled) {
      canvas.drawPath(path, stroke);
      return;
    }
    // 잃은 하트는 점선 테두리로 빈자리만 남깁니다.
    final dash = 3 * size.width / 24;
    for (final metric in path.computeMetrics()) {
      for (var distance = 0.0; distance < metric.length; distance += dash * 2) {
        canvas.drawPath(
          metric.extractPath(
            distance,
            math.min(distance + dash, metric.length),
          ),
          stroke,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_HeartPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.filled != filled;
}

// ---------------------------------------------------------------------------
// 얼굴
// ---------------------------------------------------------------------------
/// 팀 색 테두리를 두른 원형 캐릭터 얼굴입니다.
class FinalCallPopAvatar extends StatelessWidget {
  const FinalCallPopAvatar({
    super.key,
    required this.characterId,
    required this.color,
    this.size = 42,
    this.borderWidth = 3,
  });

  final String characterId;
  final Color color;
  final double size;
  final double borderWidth;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: color, width: borderWidth),
    ),
    child: ClipOval(
      child: ColoredBox(
        color: Colors.white,
        child: Image.asset(
          roomCharacterAssetPath(characterId),
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
      ),
    ),
  );
}

/// 작은 둥근 꼬리표(바꿀 카드·NEW·CALL 등)입니다.
class FinalCallPopTag extends StatelessWidget {
  const FinalCallPopTag({
    super.key,
    required this.label,
    this.color = FinalCallColors.yellow,
    this.textColor = FinalCallColors.ink,
    this.fontSize = 15,
    this.borderWidth = 3,
  });

  final String label;
  final Color color;
  final Color textColor;
  final double fontSize;
  final double borderWidth;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: FinalCallColors.ink, width: borderWidth),
    ),
    child: Text(
      label,
      maxLines: 1,
      style: finalCallPopText(fontSize, color: textColor, height: 1.3),
    ),
  );
}
