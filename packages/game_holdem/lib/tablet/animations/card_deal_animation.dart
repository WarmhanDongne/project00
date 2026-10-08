import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:game_holdem/shared/widgets/card_view.dart';
import 'package:game_kit/player_layouts/services/player_slot_positions.dart';

/// 라이어스 포커의 중앙 덱 분배 흐름을 홀덤의 기존 타원형 좌석에 맞춥니다.
class HoldemCardDealAnimation extends StatefulWidget {
  const HoldemCardDealAnimation({
    super.key,
    required this.seatCount,
    required this.seatIndexes,
    required this.scale,
    required this.onCompleted,
  }) : assert(seatCount > 0);

  final int seatCount;
  final List<int> seatIndexes;
  final double scale;
  final VoidCallback onCompleted;

  @override
  State<HoldemCardDealAnimation> createState() =>
      _HoldemCardDealAnimationState();
}

class _HoldemCardDealAnimationState extends State<HoldemCardDealAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2950),
  )..addStatusListener(_onStatus);

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      widget.onCompleted();
    }
  }

  @override
  void dispose() {
    _controller
      ..removeStatusListener(_onStatus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final centers = normalizedPlayerCenters(widget.seatCount);
          final seats = widget.seatIndexes
              .where((index) => index >= 0 && index < centers.length)
              .toList(growable: false);
          final count = seats.length * 2;
          final cardWidth = 82 * widget.scale;
          final cardHeight = cardWidth * HoldemCardView.aspectRatio;
          final center = size.center(Offset.zero);
          return Semantics(
            label: '홀덤 카드 분배',
            child: AnimatedBuilder(
              animation: _controller,
              builder: (_, _) {
                final value = _controller.value;
                final deckEntry = Curves.easeOutCubic.transform(
                  (value / .21).clamp(0.0, 1.0),
                );
                final exit = Curves.easeInCubic.transform(
                  ((value - .92) / .08).clamp(0.0, 1.0),
                );
                return SizedBox.fromSize(
                  size: size,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (var reverse = count - 1; reverse >= 0; reverse--)
                        _card(
                          order: reverse,
                          count: count,
                          seats: seats,
                          centers: centers,
                          size: size,
                          center: center,
                          cardWidth: cardWidth,
                          cardHeight: cardHeight,
                          deckEntry: deckEntry,
                          exit: exit,
                          value: value,
                        ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    ),
  );

  Widget _card({
    required int order,
    required int count,
    required List<int> seats,
    required List<Offset> centers,
    required Size size,
    required Offset center,
    required double cardWidth,
    required double cardHeight,
    required double deckEntry,
    required double exit,
    required double value,
  }) {
    final playerIndex = order % seats.length;
    final pass = order ~/ seats.length;
    final seat = centers[seats[playerIndex]];
    final destination = Offset(seat.dx * size.width, seat.dy * size.height);
    final direction = destination - center;
    final tangent = direction.distanceSquared == 0
        ? const Offset(1, 0)
        : Offset(-direction.dy, direction.dx) / direction.distance;
    final target =
        destination + tangent * ((pass == 0 ? -10 : 10) * widget.scale);
    final deck = center + Offset(0, (count - order) * 1.2 * widget.scale);
    final fromAbove = deck - Offset(0, size.height / 2 + cardHeight);
    final landing = Offset.lerp(fromAbove, deck, deckEntry)!;
    final start = .23 + (count == 1 ? 0 : order / (count - 1) * .51);
    final travel = Curves.easeOutCubic.transform(
      ((value - start) / .17).clamp(0.0, 1.0),
    );
    final position =
        Offset.lerp(landing, target, travel)! +
        tangent * (math.sin(math.pi * travel) * 15 * widget.scale);
    final angle = _seatRotation(seat) * travel;
    return Positioned(
      key: ValueKey('holdem-dealt-$order'),
      left: position.dx - cardWidth / 2,
      top: position.dy - cardHeight / 2,
      width: cardWidth,
      height: cardHeight,
      child: Opacity(
        opacity: deckEntry * (1 - exit),
        child: Transform.rotate(
          angle: angle,
          child: HoldemCardView(faceDown: true, width: cardWidth),
        ),
      ),
    );
  }

  double _seatRotation(Offset seat) {
    final direction = seat - const Offset(.5, .5);
    if (direction.dy.abs() >= direction.dx.abs() * .9) {
      return direction.dy < 0 ? math.pi : 0;
    }
    return direction.dx < 0 ? math.pi / 2 : -math.pi / 2;
  }
}
