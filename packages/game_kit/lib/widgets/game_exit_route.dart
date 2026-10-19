import 'package:flutter/material.dart';

/// The game route remains visible while a patterned diagonal wipe covers it.
/// The destination appears under the same wipe as it clears in that direction.
const gameExitTransitionDuration = Duration(milliseconds: 960);

class GameExitMaterialPageRoute<T> extends MaterialPageRoute<T> {
  GameExitMaterialPageRoute({required super.builder, super.settings});

  @override
  Duration get reverseTransitionDuration => gameExitTransitionDuration;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => _GameExitTransition(
    animation: animation,
    regularTransition: super.buildTransitions(
      context,
      animation,
      secondaryAnimation,
      child,
    ),
    child: child,
  );
}

/// Keeps the existing instant handoff from seating to the tablet game.
class GameExitInstantPageRoute<T> extends PageRouteBuilder<T> {
  GameExitInstantPageRoute({required super.pageBuilder})
    : super(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: gameExitTransitionDuration,
        transitionsBuilder: (_, animation, _, child) => _GameExitTransition(
          animation: animation,
          regularTransition: child,
          child: child,
        ),
      );
}

/// 자리 배치 뒤 한지 창호문이 양옆에서 닫혔다가 열리며 게임을 공개합니다.
///
/// 윷놀이 디자인 `입장 연출 4 · 창호문`을 옮겼습니다. 문이 닫히는 동안에는
/// 자리 배치 화면이 비치고, 닫힌 사이에 게임 화면으로 바뀝니다. 나갈 때는
/// 다른 게임과 같은 무늬 덮개를 씁니다.
class GameDoorEntryPageRoute<T> extends PageRouteBuilder<T> {
  GameDoorEntryPageRoute({required super.pageBuilder})
    : super(
        transitionDuration: gameDoorEntryDuration,
        reverseTransitionDuration: gameExitTransitionDuration,
        transitionsBuilder: (_, animation, _, child) => _GameExitTransition(
          animation: animation,
          regularTransition: _DoorEntry(animation: animation, child: child),
          child: child,
        ),
      );
}

/// 닫힘 0.84초 + 닫힌 채 1.08초 + 열림 1.08초입니다.
const gameDoorEntryDuration = Duration(milliseconds: 3000);

class _DoorEntry extends StatelessWidget {
  const _DoorEntry({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: animation,
    builder: (context, _) {
      if (animation.status == AnimationStatus.completed) return child;
      final ms = animation.value * gameDoorEntryDuration.inMilliseconds;
      const curve = Cubic(.6, 0, .3, 1);
      // 0 = 열림(화면 밖), 1 = 닫힘
      final closed = ms < 840
          ? curve.transform(ms / 840)
          : ms < 1920
          ? 1.0
          : 1 - curve.transform(((ms - 1920) / 1080).clamp(0.0, 1.0));
      // 닫힌 사이(시안 41~45%)에 게임 화면으로 바꿉니다.
      final showGame = ms >= 1100;
      return LayoutBuilder(
        builder: (context, box) {
          final half = box.maxWidth / 2;
          return Stack(
            fit: StackFit.expand,
            children: [
              Opacity(opacity: showGame ? 1 : 0, child: child),
              Positioned(
                left: -half * (1 - closed),
                top: 0,
                bottom: 0,
                width: half + 2,
                child: const IgnorePointer(child: _HanjiDoor(left: true)),
              ),
              Positioned(
                left: half + half * (1 - closed),
                top: 0,
                bottom: 0,
                width: half,
                child: const IgnorePointer(child: _HanjiDoor(left: false)),
              ),
            ],
          );
        },
      );
    },
  );
}

/// 한지 창호문 한 짝: 크림 한지, 92px 격자 문살, 진갈색 테두리, 금색 고리.
class _HanjiDoor extends StatelessWidget {
  const _HanjiDoor({required this.left});

  final bool left;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final unit = box.maxHeight / 1024;
      return DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFF4EEDF),
          border: Border.all(color: const Color(0xFF6B3A12), width: 18 * unit),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _LatticePainter(unit: unit, left: left),
            ),
            // 한지 안쪽 그늘
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  radius: 1.1,
                  colors: [Color(0x00785028), Color(0x59785028)],
                ),
              ),
            ),
            Align(
              alignment: Alignment(left ? 1 : -1, 0),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8 * unit),
                child: Container(
                  width: 30 * unit,
                  height: 80 * unit,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15 * unit),
                    border: Border.all(
                      color: const Color(0xFFC9A04A),
                      width: 6 * unit,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _LatticePainter extends CustomPainter {
  const _LatticePainter({required this.unit, required this.left});

  final double unit;
  final bool left;

  @override
  void paint(Canvas canvas, Size size) {
    final bar = Paint()..color = const Color(0xFF8C5A2E);
    final cell = 100 * unit;
    final thick = 8 * unit;
    for (var x = cell - thick; x < size.width; x += cell) {
      canvas.drawRect(Rect.fromLTWH(x, 0, thick, size.height), bar);
    }
    for (var y = cell - thick; y < size.height; y += cell) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, thick), bar);
    }
    final band = Paint()..color = const Color(0xFF7A4A22);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, 18 * unit), band);
    canvas.drawRect(
      Rect.fromLTWH(
        left ? size.width - 18 * unit : 0,
        0,
        18 * unit,
        size.height,
      ),
      band,
    );
  }

  @override
  bool shouldRepaint(_LatticePainter old) =>
      old.unit != unit || old.left != left;
}

/// 게임 퇴장 때 쓰는 마름모 무늬 대각선 덮개를 [coverage](0~1)만큼 그립니다.
///
/// 0이면 아무것도 그리지 않고 1이면 전체를 덮습니다. 전체 화면 전환이 아니라
/// 일부 영역만 같은 연출로 가릴 때 씁니다.
class GameExitPatternLayer extends StatelessWidget {
  const GameExitPatternLayer({
    super.key,
    required this.coverage,
    this.color = _gameExitCoverColor,
    this.diamondColor = _gameExitDiamondColor,
    this.dotColor = _gameExitDotColor,
    this.spacing = _gameExitSpacing,
    this.diamondRadius = _gameExitDiamondRadius,
  });

  final double coverage;

  /// 무늬 사이 간격과 마름모 크기입니다. 기본값은 게임 퇴장 연출의 값입니다.
  final double spacing;
  final double diamondRadius;

  /// 덮개 바탕색입니다. 기본값은 게임 퇴장 연출의 남색입니다.
  final Color color;

  /// 마름모와 점의 색입니다. 기본값은 게임 퇴장 연출의 색입니다.
  final Color diamondColor;
  final Color dotColor;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _GameExitPatternPainter(
      coverage,
      color: color,
      diamondColor: diamondColor,
      dotColor: dotColor,
      spacing: spacing,
      diamondRadius: diamondRadius,
    ),
    child: const SizedBox.expand(),
  );
}

const Color _gameExitCoverColor = Color(0xFF0E0A3D);
const Color _gameExitDiamondColor = Color(0x66F7F4EC);
const Color _gameExitDotColor = Color(0x888A78F8);
const double _gameExitSpacing = 42;
const double _gameExitDiamondRadius = 6;

class _GameExitTransition extends StatelessWidget {
  const _GameExitTransition({
    required this.animation,
    required this.regularTransition,
    required this.child,
  });

  final Animation<double> animation;
  final Widget regularTransition;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: animation,
    builder: (context, _) {
      if (animation.status != AnimationStatus.reverse) {
        return regularTransition;
      }

      final progress = 1 - animation.value;
      final covering = progress < 0.5;
      final phaseProgress = covering ? progress * 2 : (progress - 0.5) * 2;
      final eased = Curves.easeInOutCubic.transform(
        phaseProgress.clamp(0.0, 1.0),
      );
      final coverage = covering ? eased : 1 - eased;

      return Stack(
        fit: StackFit.expand,
        children: [
          // The destination route is behind this one. Swap at full coverage so
          // neither screen changes while the patterned layer is transparent.
          Opacity(
            key: const Key('game-exit-old-screen'),
            opacity: covering ? 1 : 0,
            child: child,
          ),
          IgnorePointer(
            child: CustomPaint(
              key: const Key('game-exit-pattern'),
              painter: _GameExitPatternPainter(coverage),
            ),
          ),
        ],
      );
    },
  );
}

class _GameExitPatternPainter extends CustomPainter {
  const _GameExitPatternPainter(
    this.coverage, {
    this.color = _gameExitCoverColor,
    this.diamondColor = _gameExitDiamondColor,
    this.dotColor = _gameExitDotColor,
    this.spacing = _gameExitSpacing,
    this.diamondRadius = _gameExitDiamondRadius,
  });

  final double coverage;
  final double spacing;
  final double diamondRadius;
  final Color color;
  final Color diamondColor;
  final Color dotColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (coverage <= 0 || size.isEmpty) return;
    canvas.save();
    canvas.clipPath(_coveragePath(size, coverage));
    canvas.drawRect(Offset.zero & size, Paint()..color = color);

    final diamond = Paint()..color = diamondColor;
    final dot = Paint()..color = dotColor;
    var row = 0;
    for (var y = 0.0; y < size.height + spacing; y += spacing) {
      final shift = row.isEven ? 0.0 : spacing / 2;
      for (var x = -spacing + shift; x < size.width + spacing; x += spacing) {
        final center = Offset(x, y);
        final tile = Path()
          ..moveTo(center.dx, center.dy - diamondRadius)
          ..lineTo(center.dx + diamondRadius, center.dy)
          ..lineTo(center.dx, center.dy + diamondRadius)
          ..lineTo(center.dx - diamondRadius, center.dy)
          ..close();
        canvas.drawPath(tile, diamond);
        canvas.drawCircle(
          center + Offset(spacing * .38, spacing * .38),
          1.5,
          dot,
        );
      }
      row += 1;
    }
    canvas.restore();
  }

  Path _coveragePath(Size size, double progress) {
    if (progress >= 1) return Path()..addRect(Offset.zero & size);

    final limit = (size.width + size.height) * progress;
    final corners = <Offset>[
      Offset.zero,
      Offset(size.width, 0),
      Offset(size.width, size.height),
      Offset(0, size.height),
    ];
    final clipped = <Offset>[];
    for (var i = 0; i < corners.length; i++) {
      final start = corners[i];
      final end = corners[(i + 1) % corners.length];
      final startValue = start.dx + size.height - start.dy - limit;
      final endValue = end.dx + size.height - end.dy - limit;
      if (startValue <= 0) clipped.add(start);
      if ((startValue < 0 && endValue > 0) ||
          (startValue > 0 && endValue < 0)) {
        final fraction = startValue / (startValue - endValue);
        clipped.add(Offset.lerp(start, end, fraction)!);
      }
    }
    return Path()..addPolygon(clipped, true);
  }

  @override
  bool shouldRepaint(covariant _GameExitPatternPainter oldDelegate) =>
      oldDelegate.coverage != coverage ||
      oldDelegate.color != color ||
      oldDelegate.diamondColor != diamondColor ||
      oldDelegate.dotColor != dotColor ||
      oldDelegate.spacing != spacing ||
      oldDelegate.diamondRadius != diamondRadius;
}
