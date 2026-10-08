import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:game_holdem/game_theme.dart';

/// 세라믹 중심과 밝은 에지 인서트가 있는 클래식 카지노 칩입니다.
class HoldemChip extends StatelessWidget {
  const HoldemChip({super.key, this.size = 22});
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size.square(size + 4),
      painter: _ChipPainter(size),
    ),
  );
}

class _ChipPainter extends CustomPainter {
  const _ChipPainter(this.diameter);
  final double diameter;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = diameter / 2;
    const rim = Color(0xFF09271E);
    const clay = Color(0xFF14523D);
    const inset = Color(0xFFF5EAD2);
    const gold = Color(0xFFD8AF69);
    canvas
      ..drawCircle(
        center.translate(0, math.max(2, diameter * .11)),
        radius + 1.5,
        Paint()..color = Colors.black.withValues(alpha: .48),
      )
      ..drawCircle(center, radius + 1, Paint()..color = rim)
      ..drawCircle(
        center,
        radius - 1,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-.28, -.32),
            colors: [clay, rim],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    final inserts = Paint()
      ..color = inset
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2, diameter * .17)
      ..strokeCap = StrokeCap.butt;
    const sweep = math.pi / 4;
    for (var index = 0; index < 8; index++) {
      canvas.drawArc(
        Rect.fromCircle(
          center: center,
          radius: radius - inserts.strokeWidth / 2,
        ),
        index * sweep - .18,
        .36,
        false,
        inserts,
      );
    }
    canvas
      ..drawCircle(center, radius * .64, Paint()..color = rim)
      ..drawCircle(center, radius * .57, Paint()..color = inset)
      ..drawCircle(center, radius * .48, Paint()..color = clay)
      ..drawCircle(
        center,
        radius * .39,
        Paint()
          ..color = gold
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1, diameter * .045),
      );
    final star = Path()
      ..moveTo(center.dx, center.dy - radius * .3)
      ..lineTo(center.dx + radius * .1, center.dy - radius * .1)
      ..lineTo(center.dx + radius * .3, center.dy)
      ..lineTo(center.dx + radius * .1, center.dy + radius * .1)
      ..lineTo(center.dx, center.dy + radius * .3)
      ..lineTo(center.dx - radius * .1, center.dy + radius * .1)
      ..lineTo(center.dx - radius * .3, center.dy)
      ..lineTo(center.dx - radius * .1, center.dy - radius * .1)
      ..close();
    canvas.drawPath(star, Paint()..color = inset);
  }

  @override
  bool shouldRepaint(_ChipPainter oldDelegate) =>
      diameter != oldDelegate.diameter;
}

/// 칩 아이콘과 금액을 한 줄로 보여 줍니다.
class HoldemChipAmount extends StatelessWidget {
  const HoldemChipAmount({
    super.key,
    required this.amount,
    this.chipSize = 16,
    this.fontSize = 28,
    this.color = HoldemColors.ivory,
    this.gap = 7,
    this.prefix = '',
  });
  final int amount;
  final double chipSize;
  final double fontSize;
  final Color color;
  final double gap;
  final String prefix;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      HoldemChip(size: chipSize),
      SizedBox(width: gap),
      Flexible(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '$prefix${holdemChips(amount)}',
            style: HoldemFonts.numbers(size: fontSize, color: color),
          ),
        ),
      ),
    ],
  );
}

/// 시안의 둥근 퍽 버튼입니다. 흰 퍽은 주요 행동, 어두운 퍽은 포기 행동입니다.
class HoldemPuckButton extends StatefulWidget {
  const HoldemPuckButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.amount,
    this.size = 100,
    this.dark = false,
    this.busy = false,
    this.semanticLabel,
  });
  final String label;
  final String? amount;
  final VoidCallback? onPressed;
  final double size;
  final bool dark;
  final bool busy;
  final String? semanticLabel;

  @override
  State<HoldemPuckButton> createState() => _HoldemPuckButtonState();
}

class _HoldemPuckButtonState extends State<HoldemPuckButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final size = widget.size;
    final depth = size * .05;
    final foreground = widget.dark
        ? HoldemColors.ivory
        : HoldemColors.cardBlack;
    // 서버 응답을 기다리는 동안 선택한 퍽을 누른 상태로 유지합니다.
    // 회전 로딩 표시보다 이미 선택한 행동을 그대로 보여 주는 편이 자연스럽습니다.
    final pressed = (_pressed && enabled) || widget.busy;
    final puck = AnimatedContainer(
      duration: const Duration(milliseconds: 90),
      width: size,
      height: size,
      transform: Matrix4.translationValues(0, pressed ? depth * .8 : 0, 0),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(0, -.36),
          radius: .7,
          colors: widget.dark
              ? const [
                  HoldemColors.puckDarkTop,
                  HoldemColors.puckDarkMid,
                  HoldemColors.puckDarkBottom,
                ]
              : const [Colors.white, Color(0xFFF2F6F3), Color(0xFFD3DCD6)],
          stops: const [0, .58, 1],
        ),
        border: widget.dark
            ? Border.all(color: HoldemColors.line(.25), width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: widget.dark
                ? const Color(0xFF040A07)
                : HoldemColors.puckEdge,
            offset: Offset(0, pressed ? depth * .2 : depth),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: .45),
            blurRadius: size * .18,
            offset: Offset(0, size * .1),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            widget.label,
            style: HoldemFonts.title(size: size * .26, color: foreground),
          ),
          if (widget.amount case final amount?)
            Padding(
              padding: EdgeInsets.only(top: size * .02),
              child: Text(
                amount,
                style: HoldemFonts.numbers(
                  size: size * .2,
                  color: widget.dark ? HoldemColors.muted : HoldemColors.accent,
                ),
              ),
            ),
        ],
      ),
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.busy
          ? '${widget.semanticLabel ?? widget.label} 선택됨'
          : widget.semanticLabel ?? [widget.label, ?widget.amount].join(' '),
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onPressed,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: enabled || widget.busy ? 1 : .38,
          child: puck,
        ),
      ),
    );
  }
}

/// 펠트 위 반투명 원형 아이콘 버튼입니다.
class HoldemCircleIconButton extends StatelessWidget {
  const HoldemCircleIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.size = 44,
  });
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: Material(
      color: HoldemColors.panel(.5),
      shape: CircleBorder(side: BorderSide(color: HoldemColors.line(.22))),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox.square(
          dimension: size,
          child: Icon(icon, color: HoldemColors.ivory, size: size * .46),
        ),
      ),
    ),
  );
}

/// 흰 바탕 짙은 글자의 둥근 라벨입니다. 족보 이름에 씁니다.
class HoldemPill extends StatelessWidget {
  const HoldemPill({
    super.key,
    required this.label,
    this.light = true,
    this.fontSize = 14,
  });
  final String label;
  final bool light;
  final double fontSize;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(
      horizontal: fontSize * 1.1,
      vertical: fontSize * .36,
    ),
    decoration: BoxDecoration(
      color: light ? HoldemColors.ivory : HoldemColors.panel(.75),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: HoldemFonts.text(
        size: fontSize,
        weight: FontWeight.w700,
        color: light ? HoldemColors.ink : HoldemColors.ivory,
      ),
    ),
  );
}
