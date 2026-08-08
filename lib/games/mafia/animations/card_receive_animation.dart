import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// 카드 한 장이 위에서 중앙으로 들어와 뒷면에서 앞면으로 뒤집힌 뒤,
/// 앞서 받은 카드의 오른쪽 아래에 겹쳐 정렬되는 애니메이션입니다.
class CardReceiveAnimation extends StatefulWidget {
  const CardReceiveAnimation({
    super.key,
    this.frontCardAssets = const [
      'assets/games/liars_poker/images/cards/white K.png',
      'assets/games/liars_poker/images/cards/white Q.png',
      'assets/games/liars_poker/images/cards/white A.png',
      'assets/games/liars_poker/images/cards/white A.png',
      'assets/games/liars_poker/images/cards/white Joker.png',
    ],
    this.backCardAsset = 'assets/games/liars_poker/images/cards/white back.png',
    this.cardWidth = 145,
    this.cardDuration = const Duration(milliseconds: 1050),
    this.cardStagger = const Duration(milliseconds: 720),
    this.autoplay = true,
    this.loop = false,
    this.onCompleted,
  }) : assert(frontCardAssets.length > 0),
       assert(cardWidth > 0),
       assert(cardDuration > Duration.zero),
       assert(cardStagger >= Duration.zero);

  /// 실제로 받은 카드 앞면 에셋을 받은 순서대로 전달합니다.
  final List<String> frontCardAssets;
  final String backCardAsset;
  final double cardWidth;

  /// 카드 한 장의 진입, 뒤집기, 정렬에 걸리는 시간입니다.
  final Duration cardDuration;

  /// 다음 카드가 들어오기 시작할 때까지의 간격입니다.
  final Duration cardStagger;

  final bool autoplay;
  final bool loop;
  final VoidCallback? onCompleted;

  @override
  CardReceiveAnimationState createState() => CardReceiveAnimationState();
}

class CardReceiveAnimationState extends State<CardReceiveAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  Duration get _totalDuration {
    final lastCardDelay =
        widget.cardStagger.inMilliseconds * (widget.frontCardAssets.length - 1);
    return Duration(
      milliseconds: lastCardDelay + widget.cardDuration.inMilliseconds,
    );
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _totalDuration)
      ..addStatusListener(_onStatusChanged);

    if (widget.autoplay) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(CardReceiveAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.cardDuration != widget.cardDuration ||
        oldWidget.cardStagger != widget.cardStagger ||
        oldWidget.frontCardAssets.length != widget.frontCardAssets.length) {
      _controller.duration = _totalDuration;
    }

    if (!oldWidget.autoplay && widget.autoplay && !_controller.isAnimating) {
      play();
    }
  }

  void _onStatusChanged(AnimationStatus status) {
    if (status != AnimationStatus.completed) {
      return;
    }

    widget.onCompleted?.call();
    if (widget.loop) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _controller.forward(from: 0);
        }
      });
    }
  }

  void play({bool restart = false}) {
    if (restart || _controller.isCompleted) {
      _controller.forward(from: 0);
    } else {
      _controller.forward();
    }
  }

  void pause() => _controller.stop();

  void reset() => _controller.reset();

  @override
  void dispose() {
    _controller
      ..removeStatusListener(_onStatusChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(
          constraints.hasBoundedWidth ? constraints.maxWidth : 420,
          constraints.hasBoundedHeight ? constraints.maxHeight : 520,
        );

        return ClipRect(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return SizedBox.fromSize(
                size: size,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (
                      var cardIndex = 0;
                      cardIndex < widget.frontCardAssets.length;
                      cardIndex++
                    )
                      _buildAnimatedCard(size: size, cardIndex: cardIndex),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildAnimatedCard({required Size size, required int cardIndex}) {
    const cardAspectRatio = 512 / 350;
    const horizontalOverlapStep = 0.23;
    const verticalOverlapStep = 0.13;

    final cardCount = widget.frontCardAssets.length;
    final widthForGroup =
        (size.width - 32) /
        (1 + horizontalOverlapStep * math.max(0, cardCount - 1));
    final widthForHeight =
        (size.height - 32) /
        (cardAspectRatio *
            (1 + verticalOverlapStep * math.max(0, cardCount - 1)));
    final cardWidth = math
        .min(widget.cardWidth, math.min(widthForGroup, widthForHeight))
        .clamp(48.0, widget.cardWidth)
        .toDouble();
    final cardHeight = cardWidth * cardAspectRatio;
    final stepX = cardWidth * horizontalOverlapStep;
    final stepY = cardHeight * verticalOverlapStep;

    final center = Offset(size.width / 2, size.height / 2);
    final centeredIndex = cardIndex - (cardCount - 1) / 2;
    final finalPosition =
        center + Offset(centeredIndex * stepX, centeredIndex * stepY);
    final entryPosition = Offset(center.dx, -cardHeight / 2 - 12);

    final totalMilliseconds = _totalDuration.inMilliseconds;
    final elapsedMilliseconds = _controller.value * totalMilliseconds;
    final cardStartMilliseconds = cardIndex * widget.cardStagger.inMilliseconds;
    final localProgress =
        ((elapsedMilliseconds - cardStartMilliseconds) /
                widget.cardDuration.inMilliseconds)
            .clamp(0.0, 1.0)
            .toDouble();

    final dropProgress = _interval(localProgress, 0, 0.32, Curves.easeOutCubic);
    final flipProgress = _interval(
      localProgress,
      0.32,
      0.64,
      Curves.easeInOutCubic,
    );
    final arrangeProgress = _interval(
      localProgress,
      0.68,
      1,
      Curves.easeOutBack,
    );

    var position = Offset.lerp(entryPosition, center, dropProgress)!;
    position = Offset.lerp(position, finalPosition, arrangeProgress)!;

    final initialTilt = cardIndex.isEven ? -0.055 : 0.055;
    final finalTilt = (cardIndex - (cardCount - 1) / 2) * 0.008;
    final zRotation =
        lerpDouble(initialTilt, 0, dropProgress)! + finalTilt * arrangeProgress;
    final isFrontVisible = flipProgress >= 0.5;
    final yRotation = isFrontVisible
        ? math.pi * (1 - flipProgress)
        : math.pi * flipProgress;
    final landingScale = lerpDouble(0.96, 1, arrangeProgress)!;

    return Positioned(
      left: position.dx - cardWidth / 2,
      top: position.dy - cardHeight / 2,
      width: cardWidth,
      height: cardHeight,
      child: IgnorePointer(
        child: Opacity(
          opacity: localProgress == 0 ? 0 : 1,
          child: Transform.rotate(
            angle: zRotation,
            child: Transform.scale(
              scale: landingScale,
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0014)
                  ..rotateY(yRotation),
                child: _buildCardFace(
                  isFrontVisible
                      ? widget.frontCardAssets[cardIndex]
                      : widget.backCardAsset,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardFace(String asset) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 9,
            offset: Offset(0, 6),
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

  double _interval(double value, double begin, double end, Curve curve) {
    final progress = ((value - begin) / (end - begin)).clamp(0.0, 1.0);
    return curve.transform(progress);
  }
}
