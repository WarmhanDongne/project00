import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:game_kit/game_assets.dart';

class LiarsPokerPreviewArtwork extends StatelessWidget {
  const LiarsPokerPreviewArtwork({super.key, required this.cards});

  final List<GameImage> cards;

  @override
  Widget build(BuildContext context) {
    return _PreviewCanvas(
      key: const Key('liars-poker-preview-artwork'),
      background: const LinearGradient(
        colors: [Color(0xFF26142F), Color(0xFF6E2A82)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Stack(
        children: [
          const Positioned(
            right: 22,
            top: 30,
            width: 112,
            height: 112,
            child: CustomPaint(painter: _MiniRoulettePainter()),
          ),
          for (var index = 0; index < cards.length; index++)
            Positioned(
              left: 34 + index * 27,
              bottom: 25 + (index.isOdd ? 7 : 0),
              width: 70,
              height: 100,
              child: Transform.rotate(
                angle: (-16 + index * 8) * math.pi / 180,
                child: cards[index].image(fit: BoxFit.contain),
              ),
            ),
        ],
      ),
    );
  }
}

class FinalCallPreviewArtwork extends StatelessWidget {
  const FinalCallPreviewArtwork({
    super.key,
    required this.cards,
    required this.redHeart,
    required this.blueHeart,
  });

  final List<GameImage> cards;
  final GameImage redHeart;
  final GameImage blueHeart;

  @override
  Widget build(BuildContext context) {
    return _PreviewCanvas(
      key: const Key('final-call-preview-artwork'),
      background: const LinearGradient(
        colors: [Color(0xFFFFF9E9), Color(0xFFF3E4C5)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      child: Stack(
        children: [
          for (var index = 0; index < cards.length; index++)
            Positioned(
              left: 33 + index * 51,
              top: 42 + (index.isOdd ? 15 : 0),
              width: 76,
              height: 113,
              child: Transform.rotate(
                angle: (-9 + index * 6) * math.pi / 180,
                child: cards[index].image(fit: BoxFit.contain),
              ),
            ),
          Positioned(
            left: 92,
            bottom: 18,
            width: 42,
            height: 42,
            child: redHeart.image(fit: BoxFit.contain),
          ),
          Positioned(
            right: 92,
            bottom: 18,
            width: 42,
            height: 42,
            child: blueHeart.image(fit: BoxFit.contain),
          ),
        ],
      ),
    );
  }
}

class MafiaPreviewArtwork extends StatelessWidget {
  const MafiaPreviewArtwork({
    super.key,
    required this.roles,
    required this.voteBox,
  });

  final List<GameImage> roles;
  final GameImage voteBox;

  @override
  Widget build(BuildContext context) {
    return _PreviewCanvas(
      key: const Key('mafia-preview-artwork'),
      background: const LinearGradient(
        colors: [Color(0xFFF5EBD4), Color(0xFFDCC9A7)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Stack(
        children: [
          for (var index = 0; index < roles.length; index++)
            Positioned(
              left: 20 + index * 49,
              top: 25 + (index.isOdd ? 12 : 0),
              width: 70,
              height: 104,
              child: Transform.rotate(
                angle: (-7 + index * 4) * math.pi / 180,
                child: roles[index].image(fit: BoxFit.contain),
              ),
            ),
          Positioned(
            right: 24,
            bottom: 17,
            width: 90,
            height: 78,
            child: voteBox.image(fit: BoxFit.contain),
          ),
        ],
      ),
    );
  }
}

class _PreviewCanvas extends StatelessWidget {
  const _PreviewCanvas({
    super.key,
    required this.background,
    required this.child,
  });

  final Gradient background;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: ColoredBox(
        color: Colors.transparent,
        child: FittedBox(
          fit: BoxFit.contain,
          child: IgnorePointer(
            child: Container(
              width: 300,
              height: 225,
              decoration: BoxDecoration(gradient: background),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniRoulettePainter extends CustomPainter {
  const _MiniRoulettePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()..style = PaintingStyle.fill;
    const sections = 12;
    for (var index = 0; index < sections; index++) {
      paint.color = index == 2 || index == 7
          ? const Color(0xFFC93445)
          : const Color(0xFF252027);
      canvas.drawArc(
        rect,
        -math.pi / 2 + index * math.pi * 2 / sections,
        math.pi * 2 / sections,
        true,
        paint,
      );
    }
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    canvas.drawCircle(
      center,
      radius * 0.18,
      Paint()..color = const Color(0xFFE5D3A4),
    );
    final marker = Path()
      ..moveTo(center.dx, -5)
      ..lineTo(center.dx - 7, 12)
      ..lineTo(center.dx + 7, 12)
      ..close();
    canvas.drawPath(marker, Paint()..color = const Color(0xFFFFD257));
  }

  @override
  bool shouldRepaint(covariant _MiniRoulettePainter oldDelegate) => false;
}
