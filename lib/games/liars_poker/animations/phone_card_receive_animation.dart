import 'dart:math' as math;
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';

class PhoneCardReceiveAnimation extends StatefulWidget {
  const PhoneCardReceiveAnimation({
    super.key,
    required this.frontCardAssets,
    this.backCardAsset = 'assets/games/liars_poker/images/cards/white back.png',
    this.cardWidth = 169.0,
    this.spreadStepX = 35.0, // 대각선 펼침 X축 간격
    this.spreadStepY = 35.0, // 대각선 펼침 Y축 간격
    this.totalDuration = const Duration(milliseconds: 2200),
    this.autoplay = true,
    this.onCompleted,
  }) : assert(frontCardAssets.length > 0),
       assert(cardWidth > 0);

  final List<String> frontCardAssets;
  final String backCardAsset;
  final double cardWidth;
  final double spreadStepX;
  final double spreadStepY;
  final Duration totalDuration;
  final bool autoplay;
  final VoidCallback? onCompleted;

  @override
  State<PhoneCardReceiveAnimation> createState() =>
      _PhoneCardReceiveAnimationState();
}

class _PhoneCardReceiveAnimationState extends State<PhoneCardReceiveAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: widget.totalDuration)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              widget.onCompleted?.call();
            }
          });

    if (widget.autoplay) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(PhoneCardReceiveAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.totalDuration != widget.totalDuration) {
      _controller.duration = widget.totalDuration;
    }
    if (!oldWidget.autoplay && widget.autoplay && !_controller.isAnimating) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 비선형(Curve) 진행률을 선형적인 Interval 구간 내에서 추출하는 유틸리티 함수
  double _intervalProgress(
    double value,
    double begin,
    double end,
    Curve curve,
  ) {
    final progress = ((value - begin) / (end - begin)).clamp(0.0, 1.0);
    return curve.transform(progress);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(
          constraints.hasBoundedWidth ? constraints.maxWidth : 400,
          constraints.hasBoundedHeight ? constraints.maxHeight : 600,
        );

        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return SizedBox.fromSize(
              size: size,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var i = widget.frontCardAssets.length - 1; i >= 0; i--)
                    _buildAnimatedCard(size: size, cardIndex: i),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAnimatedCard({required Size size, required int cardIndex}) {
    const cardAspectRatio = 512 / 350;
    final cardHeight = widget.cardWidth * cardAspectRatio;
    final cardCount = widget.frontCardAssets.length;

    // 1단계: 패 진입 (Translation) [0.0 ~ 0.3]
    final dropProgress = _intervalProgress(
      _controller.value,
      0.0,
      0.3,
      Curves.easeOutCubic,
    );

    // 2단계: 카드 뒤집기 (3D Rotation Y) [0.35 ~ 0.65]
    final flipProgress = _intervalProgress(
      _controller.value,
      0.35,
      0.65,
      Curves.easeInOutCubic,
    );

    // 3단계: 대각선 펼침 (Offset Spread) [0.7 ~ 1.0]
    final spreadProgress = _intervalProgress(
      _controller.value,
      0.7,
      1.0,
      Curves.easeOutCubic,
    );

    // -- Translation 계산 --
    final startY = -cardHeight - 50; // 화면 위쪽 바깥 좌표
    final centerY = size.height / 2;
    final centerX = size.width / 2;

    final centerPosition = Offset(centerX, centerY);
    final dropPosition = Offset(
      centerX,
      lerpDouble(startY, centerY, dropProgress)!,
    );

    // Spread 시 전체 카드 덱이 화면 중앙에 오도록 인덱스 정규화 (-N ~ +N 형태)
    final centeredIndex = cardIndex - (cardCount - 1) / 2;
    final spreadTargetPosition = Offset(
      centerX + (centeredIndex * widget.spreadStepX),
      centerY + (centeredIndex * widget.spreadStepY),
    );

    Offset currentPosition = dropPosition;
    if (spreadProgress > 0) {
      currentPosition = Offset.lerp(
        centerPosition,
        spreadTargetPosition,
        spreadProgress,
      )!;
    }

    // -- 3D Rotation Y 계산 --
    final isFrontVisible = flipProgress >= 0.5;

    // Y축 기준 회전 각도: π(뒷면) -> 0(앞면)
    final yRotation = isFrontVisible
        ? math.pi * (1 - flipProgress)
        : math.pi * flipProgress;

    // Z축 심도 시뮬레이션: 회전이 일어날 때 카드가 화면 쪽으로 살짝 떠오르는 효과 (Sine Curve)
    final flipLift = math.sin(flipProgress * math.pi);
    currentPosition += Offset(0, -cardHeight * 0.15 * flipLift);

    return Positioned(
      left: currentPosition.dx - widget.cardWidth / 2,
      top: currentPosition.dy - cardHeight / 2,
      width: widget.cardWidth,
      height: cardHeight,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0015) // 원근법(Perspective) 값 할당
          ..rotateY(yRotation),
        child: _CardFace(
          asset: isFrontVisible
              ? widget.frontCardAssets[cardIndex]
              : widget.backCardAsset,
          flipLift: flipLift,
        ),
      ),
    );
  }
}

class _CardFace extends StatelessWidget {
  const _CardFace({required this.asset, required this.flipLift});
  final String asset;
  final double flipLift;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: const Color(0x66000000),
            blurRadius: 7 + flipLift * 10,
            offset: Offset(0, 5 + flipLift * 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.asset(
          asset,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}
