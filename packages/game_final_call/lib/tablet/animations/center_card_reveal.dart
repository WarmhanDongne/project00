// [tablet_center_card_reveal.dart] 는 파이널콜에서 사용하는 화면 전환과 게임 연출의 진행 시간을 관리하는 파일이다.
//
// - [Package] : 파이널콜
// - [Animation] : 화면 전환과 게임 연출의 진행 시간을 관리함
//
// 즉, 같은 연출을 예측 가능한 순서와 속도로 재생하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:game_final_call/game_theme.dart';
import 'package:game_final_call/shared/models/game_models.dart';
import 'package:game_final_call/shared/widgets/card_view.dart';

// ============================================================

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
    this.gap = 10,
    this.showRevealedCard = true,
  });

  final FinalCallCard? card;
  final double cardWidth;

  /// 덱과 공개 카드 사이 간격입니다.
  final double gap;
  final bool showRevealedCard;

  @override
  State<FinalCallCenterCardReveal> createState() =>
      _FinalCallCenterCardRevealState();
}

class _FinalCallCenterCardRevealState extends State<FinalCallCenterCardReveal> {
  static const Duration _startDelay = Duration(milliseconds: 400);
  static const Duration _duration = Duration(milliseconds: 680);

  Timer? startTimer;
  bool started = false;

  double get cardHeight => widget.cardWidth * finalCallCardHeightRatio;
  double get travelDistance => widget.cardWidth + widget.gap;

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
      width: widget.cardWidth * 2 + widget.gap,
      height: cardHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 애니메이션이 끝난 뒤에도 왼쪽에 그대로 남는 카드 더미입니다.
          // 두 겹 그림자로 쌓인 덱처럼 보이게 합니다(시안).
          Positioned(
            left: 0,
            top: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.cardWidth * 14 / 92),
                boxShadow: [
                  BoxShadow(
                    color: FinalCallColors.violetDeep,
                    offset: Offset(
                      widget.cardWidth * 8 / 92,
                      widget.cardWidth * 8 / 92,
                    ),
                  ),
                  BoxShadow(
                    color: FinalCallColors.ink,
                    offset: Offset(
                      widget.cardWidth * 4 / 92,
                      widget.cardWidth * 4 / 92,
                    ),
                  ),
                ],
              ),
              child: FinalCallCardView(faceDown: true, width: widget.cardWidth),
            ),
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
