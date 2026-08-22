import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:project00/platform/home/room/models/room_character.dart';
import 'package:project00/platform/theme/platform_theme.dart';

//=======================안내 연출 공통 조각==============================
// 플레이 방식 안내의 네 장면이 함께 쓰는 도형(테이블, 태블릿, 휴대폰, 사람)과
// 타임라인 계산 함수를 모아 둡니다. 장면 파일은 배치와 타이밍만 담당합니다.

/// 0~1 전체 진행도 [t]에서 [start]~[end] 구간만 잘라 다시 0~1로 만듭니다.
///
/// 하나의 반복 애니메이션 안에서 여러 동작을 순서대로 넣을 때 사용합니다.
double segment(
  double t,
  double start,
  double end, {
  Curve curve = Curves.linear,
}) {
  if (end <= start) return t >= end ? 1 : 0;
  return curve.transform(((t - start) / (end - start)).clamp(0.0, 1.0));
}

/// 기기 테두리 색입니다. 밝은 테마와 어두운 테마 모두에서 '기기'로 보이도록
/// 테마 색을 따르지 않고 고정합니다.
const Color guideDeviceFrame = Color(0xFF2A2825);

/// 정규화 좌표([center], 0~1)를 기준으로 자식을 판 위에 중앙 정렬해 놓습니다.
Widget placeAt({
  required Size board,
  required Offset center,
  required Widget child,
}) {
  return Positioned(
    left: center.dx * board.width,
    top: center.dy * board.height,
    child: FractionalTranslation(
      translation: const Offset(-0.5, -0.5),
      child: child,
    ),
  );
}

/// 문구처럼 폭이 넓은 자식을 판 위 [center] 자리에 놓습니다.
///
/// [placeAt]은 자식에게 '왼쪽 여백을 뺀 나머지'만 폭으로 주기 때문에 긴 문구가
/// 넘칠 수 있습니다. 문구는 판 전체 폭을 쓰고 그 안에서 정렬합니다.
Widget placeLabel({required Offset center, required Widget child}) {
  return Positioned.fill(
    child: Align(
      alignment: Alignment(center.dx * 2 - 1, center.dy * 2 - 1),
      child: child,
    ),
  );
}

/// 기기 화면 안의 내용을 화면 크기에 맞춰 줄여서 가운데에 놓습니다.
///
/// 태블릿·휴대폰 화면은 판 크기에 따라 픽셀 단위로 작아지므로, 글자 크기가
/// 반올림되며 조금만 커져도 넘칠 수 있습니다.
class GuideScreenFit extends StatelessWidget {
  const GuideScreenFit({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
    child: FittedBox(fit: BoxFit.scaleDown, child: child),
  );
}

//=======================테이블==============================
class GuideTable extends StatelessWidget {
  const GuideTable({super.key, required this.size, this.progress = 1});

  /// 테이블 상판의 실제 크기입니다.
  final Size size;

  /// 0이면 아직 나타나지 않은 상태, 1이면 완전히 나타난 상태입니다.
  final double progress;

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    return Opacity(
      opacity: progress.clamp(0.0, 1.0),
      child: Transform.scale(
        scale: 0.92 + 0.08 * progress,
        child: Container(
          width: size.width,
          height: size.height,
          decoration: BoxDecoration(
            color: colors.surfaceMuted,
            borderRadius: BorderRadius.circular(size.height / 2),
            border: Border.all(color: colors.border, width: 2),
            boxShadow: [
              BoxShadow(
                color: colors.text.withValues(alpha: 0.06),
                blurRadius: 26,
                offset: const Offset(0, 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

//=======================태블릿==============================
class GuideTablet extends StatelessWidget {
  const GuideTablet({
    super.key,
    required this.width,
    this.child,
    this.glow = 0,
    this.landscape = true,
  });

  final double width;
  final Widget? child;

  /// 0~1. 주목시킬 때 테두리 주변에 번지는 빛의 세기입니다.
  final double glow;
  final bool landscape;

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    final height = landscape ? width * 0.72 : width / 0.72;
    final bezel = width * 0.035;
    return Container(
      width: width,
      height: height,
      padding: EdgeInsets.all(bezel),
      decoration: BoxDecoration(
        color: guideDeviceFrame,
        borderRadius: BorderRadius.circular(width * 0.06),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: width * 0.12,
            offset: Offset(0, width * 0.04),
          ),
          if (glow > 0)
            BoxShadow(
              color: colors.primary.withValues(alpha: 0.45 * glow),
              blurRadius: width * 0.3 * glow,
              spreadRadius: width * 0.02 * glow,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(width * 0.035),
        child: ColoredBox(
          color: colors.surface,
          child: SizedBox.expand(child: child),
        ),
      ),
    );
  }
}

//=======================휴대폰==============================
class GuidePhone extends StatelessWidget {
  const GuidePhone({
    super.key,
    required this.width,
    this.child,
    this.glow = 0,
    this.tilt = 0,
  });

  final double width;
  final Widget? child;
  final double glow;

  /// 라디안 단위의 기울기입니다. 손에 든 느낌을 줄 때 사용합니다.
  final double tilt;

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    final bezel = width * 0.07;
    return Transform.rotate(
      angle: tilt,
      child: Container(
        width: width,
        height: width * 2,
        padding: EdgeInsets.all(bezel),
        decoration: BoxDecoration(
          color: guideDeviceFrame,
          borderRadius: BorderRadius.circular(width * 0.22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: width * 0.28,
              offset: Offset(0, width * 0.1),
            ),
            if (glow > 0)
              BoxShadow(
                color: colors.primary.withValues(alpha: 0.5 * glow),
                blurRadius: width * 0.6 * glow,
                spreadRadius: width * 0.06 * glow,
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(width * 0.15),
          child: ColoredBox(
            color: colors.surface,
            child: SizedBox.expand(child: child),
          ),
        ),
      ),
    );
  }
}

//=======================참여자==============================
class GuideAvatar extends StatelessWidget {
  const GuideAvatar({
    super.key,
    required this.characterId,
    required this.diameter,
    this.highlighted = false,
  });

  final String characterId;
  final double diameter;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    return Container(
      width: diameter,
      height: diameter,
      padding: EdgeInsets.all(diameter * 0.12),
      decoration: BoxDecoration(
        color: highlighted ? colors.primarySoft : colors.surface,
        shape: BoxShape.circle,
        border: Border.all(
          color: highlighted ? colors.primary : colors.border,
          width: highlighted ? 2.5 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (highlighted ? colors.primary : colors.text).withValues(
              alpha: highlighted ? 0.3 : 0.08,
            ),
            blurRadius: highlighted ? diameter * 0.4 : diameter * 0.16,
            offset: Offset(0, diameter * 0.05),
          ),
        ],
      ),
      child: Image.asset(
        roomCharacterAssetPath(characterId),
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) =>
            Icon(Icons.person, size: diameter * 0.5, color: colors.textMuted),
      ),
    );
  }
}

//=======================빈 자리 표시==============================
class GuideSeat extends StatelessWidget {
  const GuideSeat({super.key, required this.diameter, this.opacity = 1});

  final double diameter;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: CustomPaint(
        size: Size.square(diameter),
        painter: _DashedCirclePainter(color: colors.border),
      ),
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  const _DashedCirclePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final radius = size.shortestSide / 2 - 1;
    final center = Offset(size.width / 2, size.height / 2);
    const dashCount = 16;
    const dashRatio = 0.55;
    for (var index = 0; index < dashCount; index++) {
      final start = (math.pi * 2 / dashCount) * index;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        (math.pi * 2 / dashCount) * dashRatio,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter oldDelegate) =>
      oldDelegate.color != color;
}

//=======================말풍선 문구==============================
class GuideCallout extends StatelessWidget {
  const GuideCallout({
    super.key,
    required this.label,
    required this.fontSize,
    this.icon,
    this.emphasized = false,
  });

  final String label;
  final double fontSize;
  final IconData? icon;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    final foreground = emphasized ? colors.primary : colors.textMuted;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: fontSize * 0.9,
        vertical: fontSize * 0.5,
      ),
      decoration: BoxDecoration(
        color: emphasized ? colors.primarySoft : colors.surface,
        borderRadius: BorderRadius.circular(fontSize * 1.4),
        border: Border.all(
          color: emphasized ? colors.primary : colors.border,
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fontSize * 1.15, color: foreground),
            SizedBox(width: fontSize * 0.35),
          ],
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}
