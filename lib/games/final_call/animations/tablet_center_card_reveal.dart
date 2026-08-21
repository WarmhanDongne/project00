import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:project00/games/final_call/models/final_call_models.dart';
import 'package:project00/games/final_call/widgets/final_call_card_view.dart';

/// 중앙 덱에서 한 장이 뒤집히며 오른쪽 공개 카드 자리로 이동합니다.
///
/// 왼쪽의 덱 카드는 고정된 채 남고, 이동 카드는 90도 지점에서 앞면으로
/// 교체됩니다. [AnimatedSwitcher]를 사용하지 않아 이미지 전환 시 페이드가
/// 섞이지 않습니다.
class FinalCallCenterCardReveal extends StatefulWidget {
  const FinalCallCenterCardReveal({
    super.key,
    required this.card,
    this.cardWidth = 92,
    this.showRevealedCard = true,
  });

  final FinalCallCard? card;
  final double cardWidth;
  final bool showRevealedCard;

  @override
  State<FinalCallCenterCardReveal> createState() =>
      _FinalCallCenterCardRevealState();
}

class _FinalCallCenterCardRevealState extends State<FinalCallCenterCardReveal> {
  static const Duration _startDelay = Duration(milliseconds: 400);
  static const Duration _duration = Duration(milliseconds: 680);
  static const double _gap = 10;

  Timer? startTimer;
  bool started = false;

  double get cardHeight => widget.cardWidth * 1518 / 1036;
  double get travelDistance => widget.cardWidth + _gap;

  @override
  void initState() {
    super.initState();
    startTimer = Timer(_startDelay, () {
      if (mounted) setState(() => started = true);
    });
  }

  @override
  void dispose() {
    startTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.cardWidth * 2 + _gap,
      height: cardHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 애니메이션이 끝난 뒤에도 왼쪽에 그대로 남는 카드 더미입니다.
          Positioned(
            left: 0,
            top: 0,
            child: FinalCallCardView(faceDown: true, width: widget.cardWidth),
          ),
          Positioned(
            left: 0,
            top: 0,
            child: AnimatedOpacity(
              opacity: widget.showRevealedCard ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: started ? 1 : 0),
                duration: _duration,
                curve: Curves.easeInOutCubic,
                builder: (context, progress, _) {
                  final showFront = progress >= 0.5;

                  // 앞뒷면이 바뀌는 90도 지점을 기준으로 각도를 다시 펴 줍니다.
                  final rotationY = showFront
                      ? (progress - 1) * math.pi
                      : progress * math.pi;

                  return Transform.translate(
                    offset: Offset(travelDistance * progress, 0),
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.0016)
                        ..rotateY(rotationY),
                      child: FinalCallCardView(
                        card: widget.card,
                        faceDown: !showFront,
                        width: widget.cardWidth,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
