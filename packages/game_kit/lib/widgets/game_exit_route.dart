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
  const _GameExitPatternPainter(this.coverage);

  final double coverage;

  @override
  void paint(Canvas canvas, Size size) {
    if (coverage <= 0 || size.isEmpty) return;
    canvas.save();
    canvas.clipPath(_coveragePath(size, coverage));
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF0E0A3D),
    );

    const spacing = 42.0;
    final diamond = Paint()..color = const Color(0x66F7F4EC);
    final dot = Paint()..color = const Color(0x888A78F8);
    var row = 0;
    for (var y = 0.0; y < size.height + spacing; y += spacing) {
      final shift = row.isEven ? 0.0 : spacing / 2;
      for (var x = -spacing + shift; x < size.width + spacing; x += spacing) {
        final center = Offset(x, y);
        final tile = Path()
          ..moveTo(center.dx, center.dy - 6)
          ..lineTo(center.dx + 6, center.dy)
          ..lineTo(center.dx, center.dy + 6)
          ..lineTo(center.dx - 6, center.dy)
          ..close();
        canvas.drawPath(tile, diamond);
        canvas.drawCircle(center + const Offset(16, 16), 1.5, dot);
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
      oldDelegate.coverage != coverage;
}
