// [noir_ui.dart] 라이어스 포커 리디자인(보랏빛 카지노·금색)의
// 태블릿·휴대폰이 함께 쓰는 작은 부품을 모아 둔 파일이다.

// ========================[ import ]==========================
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:game_kit/core/constants/room_character.dart';
import 'package:game_liars_poker/game_theme.dart';

// ============================================================

// ---------------------------------------------------------------------------
// 프로필
// ---------------------------------------------------------------------------
/// 둥근 캐릭터 얼굴입니다. [ringColor]가 있으면 안쪽 테두리로 감쌉니다.
class NoirAvatar extends StatelessWidget {
  const NoirAvatar({
    super.key,
    required this.characterId,
    required this.size,
    this.ringColor,
    this.ringWidth = 0,
    this.glowColor,
    this.grayscale = false,
  });

  final String characterId;
  final double size;
  final Color? ringColor;
  final double ringWidth;
  final Color? glowColor;
  final bool grayscale;

  @override
  Widget build(BuildContext context) {
    Widget face = Image.asset(
      roomCharacterAssetPath(characterId),
      fit: BoxFit.cover,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => const ColoredBox(color: LiarsPokerColors.dim),
    );
    if (grayscale) {
      face = ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          .33, .59, .11, 0, 0, //
          .33, .59, .11, 0, 0, //
          .33, .59, .11, 0, 0, //
          0, 0, 0, 1, 0,
        ]),
        child: face,
      );
    }
    final glow = glowColor;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: LiarsPokerColors.night,
        border: ringColor == null
            ? null
            : Border.all(color: ringColor!, width: ringWidth),
        boxShadow: [
          if (glow != null) BoxShadow(color: glow, blurRadius: size * .3),
        ],
      ),
      child: ClipOval(child: face),
    );
  }
}

// ---------------------------------------------------------------------------
// 룰렛 단계 점
// ---------------------------------------------------------------------------
/// 지금까지 버틴 룰렛 수만큼 금색으로 채운 점 세 개입니다.
///
/// 마지막 단계에 들어서면 남은 빈 점이 빨간 테두리로 바뀝니다.
class NoirRouletteDots extends StatelessWidget {
  const NoirRouletteDots({
    super.key,
    required this.penaltyCount,
    this.size = 13,
    this.gap = 4,
  });

  final int penaltyCount;
  final double size;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final danger = liarsPokerIsDanger(penaltyCount);
    final filled = penaltyCount.clamp(0, 3);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < 3; index++) ...[
          if (index > 0) SizedBox(width: gap),
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: index < filled ? LiarsPokerColors.gold : null,
              border: index < filled
                  ? null
                  : Border.all(
                      color: danger
                          ? LiarsPokerColors.red
                          : LiarsPokerColors.dim,
                      width: math.max(1.5, size * .15),
                    ),
            ),
          ),
        ],
      ],
    );
  }
}

/// 룰렛 점과 `다음 5/15` 확률을 한 줄로 보여 줍니다.
class NoirRouletteStatus extends StatelessWidget {
  const NoirRouletteStatus({
    super.key,
    required this.penaltyCount,
    this.dotSize = 13,
    this.fontSize = 13,
    this.prefix = '다음',
  });

  final int penaltyCount;
  final double dotSize;
  final double fontSize;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    final danger = liarsPokerIsDanger(penaltyCount);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        NoirRouletteDots(
          penaltyCount: penaltyCount,
          size: dotSize,
          gap: dotSize * .3,
        ),
        SizedBox(width: dotSize * .45),
        Text(
          '$prefix ${liarsPokerOddsLabel(penaltyCount)}',
          style: LiarsPokerFonts.text(
            size: fontSize,
            weight: danger ? FontWeight.w700 : FontWeight.w500,
            color: danger ? LiarsPokerColors.pink : LiarsPokerColors.muted,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 버튼
// ---------------------------------------------------------------------------
/// 휴대폰 상단의 금색 테두리 둥근 사각 아이콘 버튼입니다.
class NoirIconButton extends StatelessWidget {
  const NoirIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.size = 44,
  });

  final IconData icon;
  final String label;
  final ValueChanged<Offset> onPressed;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: Builder(
      builder: (buttonContext) => Material(
        color: LiarsPokerColors.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(size * .32),
          side: BorderSide(
            color: LiarsPokerColors.gold.withValues(alpha: .55),
            width: 1.5,
          ),
        ),
        elevation: 4,
        shadowColor: Colors.black54,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            final box = buttonContext.findRenderObject() as RenderBox?;
            onPressed(
              box?.localToGlobal(box.size.center(Offset.zero)) ?? Offset.zero,
            );
          },
          child: SizedBox.square(
            dimension: size,
            child: Icon(
              icon,
              size: size * .48,
              color: LiarsPokerColors.goldLight,
            ),
          ),
        ),
      ),
    ),
  );
}

/// 태블릿 모서리의 금색 줄무늬 링 버튼 겉모습입니다(눌림은 부모가 처리).
class NoirRingGlyph extends StatelessWidget {
  const NoirRingGlyph({super.key, required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest.shortestSide;
      return CustomPaint(
        painter: const _StripedRingPainter(),
        child: Center(
          child: Container(
            width: size * .76,
            height: size * .76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: LiarsPokerColors.night,
              border: Border.all(color: LiarsPokerColors.gold, width: 2),
            ),
            child: Icon(
              icon,
              size: size * .38,
              color: LiarsPokerColors.goldLight,
            ),
          ),
        ),
      );
    },
  );
}

class _StripedRingPainter extends CustomPainter {
  const _StripedRingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center.translate(0, 3),
      radius,
      Paint()
        ..color = Colors.black45
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    const segments = 20;
    const sweep = math.pi * 2 / segments;
    for (var index = 0; index < segments; index++) {
      canvas.drawArc(
        rect,
        -math.pi / 2 + index * sweep,
        sweep,
        true,
        Paint()
          ..color = index.isEven
              ? LiarsPokerColors.gold
              : LiarsPokerColors.panelRaised,
      );
    }
  }

  @override
  bool shouldRepaint(_StripedRingPainter oldDelegate) => false;
}

/// `Liar`·`제출`·`Fold` 같은 큰 상아색 퍽 버튼입니다.
class NoirPuck extends StatelessWidget {
  const NoirPuck({
    super.key,
    required this.label,
    required this.ringColor,
    this.size = 128,
    this.western = true,
    this.pressed = false,
    this.enabled = true,
  });

  final String label;
  final Color ringColor;
  final double size;

  /// true면 Rye(라틴), false면 Black Han Sans(한글)로 씁니다.
  final bool western;
  final bool pressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final depth = size * .078;
    final ring = size * .04;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: enabled ? 1 : .4,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        width: size,
        height: size,
        transform: Matrix4.translationValues(0, pressed ? depth * .6 : 0, 0),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: LiarsPokerColors.ivory,
          boxShadow: [
            BoxShadow(color: ringColor, spreadRadius: ring),
            BoxShadow(
              color: ringColor.withValues(alpha: .35),
              blurRadius: size * .32,
              spreadRadius: ring,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: .5),
              blurRadius: size * .22,
              offset: Offset(0, size * .094),
            ),
          ],
        ),
        foregroundDecoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.transparent,
              LiarsPokerColors.ivoryEdge.withValues(alpha: pressed ? .3 : .9),
            ],
            stops: const [0, .9, 1],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.only(bottom: pressed ? 0 : depth * .5),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: western
                  ? LiarsPokerFonts.western(
                      size: size * .28,
                      color: LiarsPokerColors.night,
                    )
                  : LiarsPokerFonts.headline(
                      size: size * .265,
                      color: LiarsPokerColors.night,
                      letterSpacing: size * .016,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 남은 시간 링
// ---------------------------------------------------------------------------
/// 남은 비율만큼 시계 방향으로 채운 원과 가운데 초 표시입니다.
class NoirTimerRing extends StatelessWidget {
  const NoirTimerRing({
    super.key,
    required this.fraction,
    required this.seconds,
    this.size = 128,
  });

  final double fraction;
  final int seconds;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(
          color: LiarsPokerColors.pink.withValues(alpha: .25),
          blurRadius: size * .24,
        ),
      ],
    ),
    child: CustomPaint(
      painter: _RingPainter(
        fraction.clamp(0.0, 1.0),
        LiarsPokerColors.pink,
        LiarsPokerColors.panelRaised,
      ),
      child: Center(
        child: Container(
          width: size * .845,
          height: size * .845,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: LiarsPokerColors.night,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$seconds',
                style: LiarsPokerFonts.headline(size: size * .36),
              ),
              SizedBox(height: size * .015),
              Text(
                '초 남음',
                style: LiarsPokerFonts.text(
                  size: size * .094,
                  weight: FontWeight.w700,
                  color: LiarsPokerColors.pinkLight,
                  letterSpacing: size * .009,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// 원을 [fraction]만큼 채웁니다. 태블릿 차례 프로필 테두리에도 씁니다.
class NoirProgressRing extends StatelessWidget {
  const NoirProgressRing({
    super.key,
    required this.fraction,
    required this.color,
    required this.track,
    required this.child,
  });

  final double fraction;
  final Color color;
  final Color track;
  final Widget child;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _RingPainter(fraction.clamp(0.0, 1.0), color, track),
    child: child,
  );
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.fraction, this.color, this.track);

  final double fraction;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas
      ..drawOval(rect, Paint()..color = track)
      ..drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * fraction,
        true,
        Paint()..color = color,
      );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      fraction != oldDelegate.fraction ||
      color != oldDelegate.color ||
      track != oldDelegate.track;
}

// ---------------------------------------------------------------------------
// 문구
// ---------------------------------------------------------------------------
/// 비스듬히 찍힌 빨간 `LIAR!` 글자입니다.
class NoirLiarMark extends StatelessWidget {
  const NoirLiarMark({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: -4 * math.pi / 180,
    child: Text(
      'LIAR!',
      style: LiarsPokerFonts.western(
        size: size,
        color: LiarsPokerColors.red,
        shadows: [
          Shadow(
            color: LiarsPokerColors.redShadow,
            offset: Offset(0, size * .1),
          ),
        ],
      ),
    ),
  );
}

/// 기준 카드 이름(`ACE'S TABLE`)입니다.
String liarsPokerTableTitle(String cardValue) =>
    switch (cardValue.toUpperCase()) {
      'A' => "ACE'S TABLE",
      'Q' => "QUEEN'S TABLE",
      _ => "KING'S TABLE",
    };

/// 빨간 바탕 흰 글자의 `탈락 4/16` 알약입니다.
class NoirOddsPill extends StatelessWidget {
  const NoirOddsPill({
    super.key,
    required this.penaltyCount,
    this.fontSize = 13,
  });

  final int penaltyCount;
  final double fontSize;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(
      horizontal: fontSize * .7,
      vertical: fontSize * .15,
    ),
    decoration: BoxDecoration(
      color: LiarsPokerColors.red,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      '탈락 ${liarsPokerOddsLabel(penaltyCount)}',
      style: LiarsPokerFonts.text(size: fontSize, weight: FontWeight.w700),
    ),
  );
}

/// 세 단계 룰렛 확률을 나란히 보여 주고 이번 단계를 빨갛게 채웁니다.
class NoirOddsLadder extends StatelessWidget {
  const NoirOddsLadder({
    super.key,
    required this.penaltyCount,
    this.fontSize = 13,
    this.edgeColor = LiarsPokerColors.redEdge,
  });

  final int penaltyCount;
  final double fontSize;
  final Color edgeColor;

  @override
  Widget build(BuildContext context) {
    final current = penaltyCount.clamp(0, 2);
    return Row(
      children: [
        for (var step = 0; step < 3; step++) ...[
          if (step > 0) const SizedBox(width: 6),
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(vertical: fontSize * .3),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: step == current ? LiarsPokerColors.red : null,
                borderRadius: BorderRadius.circular(8),
                border: step == current ? null : Border.all(color: edgeColor),
              ),
              child: Text(
                '${step + 1}회 ${liarsPokerOddsLabel(step)}',
                style: LiarsPokerFonts.text(
                  size: fontSize,
                  weight: step == current ? FontWeight.w700 : FontWeight.w500,
                  color: step == current
                      ? LiarsPokerColors.ivory
                      : LiarsPokerColors.muted,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
