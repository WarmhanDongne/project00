import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:game_holdem/shared/models/game_models.dart';
import 'package:game_holdem/shared/widgets/card_view.dart';

/// 라이어스 포커와 같은 순서로 손패가 위에서 내려온 뒤 탭으로 펼쳐집니다.
class HoldemHandReceiveAnimation extends StatefulWidget {
  const HoldemHandReceiveAnimation({
    super.key,
    required this.cards,
    required this.onCompleted,
  }) : assert(cards.length == 2);

  final List<HoldemCardModel> cards;
  final VoidCallback onCompleted;

  @override
  State<HoldemHandReceiveAnimation> createState() =>
      _HoldemHandReceiveAnimationState();
}

class _HoldemHandReceiveAnimationState extends State<HoldemHandReceiveAnimation>
    with TickerProviderStateMixin {
  late final AnimationController _entry = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 760),
  )..addStatusListener(_onEntryStatus);
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..addStatusListener(_onRevealStatus);
  late final AnimationController _spread = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  )..addStatusListener(_onSpreadStatus);
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  late final Listenable _motion = Listenable.merge([
    _entry,
    _reveal,
    _spread,
    _idle,
  ]);
  bool _readyToTap = false;
  bool _revealing = false;

  @override
  void initState() {
    super.initState();
    _entry.forward();
  }

  void _onEntryStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    setState(() => _readyToTap = true);
    _idle.repeat();
  }

  void _onRevealStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      _spread.forward();
    }
  }

  void _onSpreadStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      widget.onCompleted();
    }
  }

  void _revealCards() {
    if (!_readyToTap || _revealing) return;
    _idle.stop();
    setState(() => _revealing = true);
    _reveal.forward();
  }

  @override
  void dispose() {
    _entry
      ..removeStatusListener(_onEntryStatus)
      ..dispose();
    _reveal
      ..removeStatusListener(_onRevealStatus)
      ..dispose();
    _spread
      ..removeStatusListener(_onSpreadStatus)
      ..dispose();
    _idle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      final width = math.min(
        132.0,
        math.min(size.width * .44, size.height / 1.44),
      );
      final height = width * HoldemCardView.aspectRatio;
      final center = size.center(Offset.zero);
      return AnimatedBuilder(
        animation: _motion,
        builder: (context, _) {
          final entry = Curves.easeOutCubic.transform(_entry.value);
          final spread = Curves.easeOutBack.transform(_spread.value);
          final idle = _readyToTap && !_revealing
              ? math.sin(_idle.value * math.pi * 2) * 3
              : 0.0;
          return SizedBox.fromSize(
            size: size,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (var index = 0; index < 2; index++)
                  _card(
                    index: index,
                    center: center,
                    width: width,
                    height: height,
                    entry: entry,
                    spread: spread,
                    idle: idle,
                  ),
                if (_readyToTap && !_revealing)
                  Positioned(
                    left: center.dx - width / 2,
                    top: center.dy - height / 2 - 4 + idle,
                    width: width + 4,
                    height: height + 8,
                    child: Semantics(
                      button: true,
                      label: '카드 확인',
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _revealCards,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      );
    },
  );

  Widget _card({
    required int index,
    required Offset center,
    required double width,
    required double height,
    required double entry,
    required double spread,
    required double idle,
  }) {
    final deck = Offset(center.dx + index * 2, center.dy + index * 3);
    final spreadTarget = center + Offset((index == 0 ? -1 : 1) * width * .4, 0);
    final fromAbove = Offset(deck.dx, -height / 2 - 24);
    final landed = Offset.lerp(fromAbove, deck, entry)!;
    final position =
        Offset.lerp(landed, spreadTarget, spread)! + Offset(0, idle);
    final front = _reveal.value >= .5;
    final flip = front
        ? math.pi * (1 - _reveal.value)
        : math.pi * _reveal.value;
    return Positioned(
      key: ValueKey('holdem-receive-card-$index'),
      left: position.dx - width / 2,
      top: position.dy - height / 2,
      width: width,
      height: height,
      child: IgnorePointer(
        child: Opacity(
          opacity: entry,
          child: Transform.rotate(
            angle: (index == 0 ? -7 : 7) * math.pi / 180 * spread,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, .0015)
                ..rotateY(flip),
              child: HoldemCardView(
                card: front ? widget.cards[index] : null,
                faceDown: !front,
                width: width,
                layout: HoldemCardLayout.hand,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
