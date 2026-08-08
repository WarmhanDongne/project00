import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:project00/gen/assets.gen.dart';

/// 받은 카드 덱이 중앙으로 들어온 뒤, 사용자의 탭을 기다렸다가 공개됩니다.
///
/// 진입 중에는 모든 카드를 뒷면으로 유지합니다. 덱을 누르면 중앙에서
/// 먼저 왼쪽에서 오른쪽 방향으로 회전한 뒤 좌상단에서 우하단으로 펼쳐집니다.
class PhoneCardReceiveAnimation extends StatefulWidget {
  const PhoneCardReceiveAnimation({
    super.key,
    required this.frontCardAssets,
    this.backCardAsset,
    this.cardWidth = 169.0,
    this.spreadStepX = 35.0,
    this.spreadStepY = 35.0,
    this.totalDuration = const Duration(milliseconds: 2200),
    this.autoplay = true,
    this.onRevealStarted,
    this.onCompleted,
  }) : assert(frontCardAssets.length > 0),
       assert(cardWidth > 0),
       assert(totalDuration > Duration.zero);

  final List<AssetGenImage> frontCardAssets;
  final AssetGenImage? backCardAsset;
  final double cardWidth;
  final double spreadStepX;
  final double spreadStepY;

  /// 자동 진입과 탭 후 공개 애니메이션을 합친 기준 시간입니다.
  final Duration totalDuration;

  /// true이면 화면이 열릴 때 카드 덱이 자동으로 중앙까지 들어옵니다.
  final bool autoplay;
  final VoidCallback? onRevealStarted;
  final VoidCallback? onCompleted;

  @override
  State<PhoneCardReceiveAnimation> createState() =>
      _PhoneCardReceiveAnimationState();
}

class _PhoneCardReceiveAnimationState extends State<PhoneCardReceiveAnimation>
    with TickerProviderStateMixin {
  late final AnimationController _entryController;
  late final AnimationController _revealController;

  bool _isEntryCompleted = false;
  bool _isRevealStarted = false;

  Duration get _entryDuration => Duration(
    milliseconds: math.max(
      1,
      (widget.totalDuration.inMilliseconds * 0.34).round(),
    ),
  );

  Duration get _revealDuration => Duration(
    milliseconds: math.max(
      1,
      widget.totalDuration.inMilliseconds - _entryDuration.inMilliseconds,
    ),
  );

  bool get _canReveal => _isEntryCompleted && !_isRevealStarted;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: _entryDuration,
    )..addStatusListener(_handleEntryStatus);
    _revealController = AnimationController(
      vsync: this,
      duration: _revealDuration,
    )..addStatusListener(_handleRevealStatus);

    if (widget.autoplay) {
      _entryController.forward();
    }
  }

  @override
  void didUpdateWidget(PhoneCardReceiveAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.totalDuration != widget.totalDuration) {
      _entryController.duration = _entryDuration;
      _revealController.duration = _revealDuration;
    }

    if (!oldWidget.autoplay && widget.autoplay && !_isEntryCompleted) {
      _entryController.forward();
    }
  }

  void _handleEntryStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;

    setState(() {
      _isEntryCompleted = true;
    });
  }

  void _handleRevealStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      widget.onCompleted?.call();
    }
  }

  void _revealCards() {
    if (!_canReveal) return;

    setState(() {
      _isRevealStarted = true;
    });
    widget.onRevealStarted?.call();
    _revealController.forward(from: 0);
  }

  @override
  void dispose() {
    _entryController
      ..removeStatusListener(_handleEntryStatus)
      ..dispose();
    _revealController
      ..removeStatusListener(_handleRevealStatus)
      ..dispose();
    super.dispose();
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
          animation: Listenable.merge([_entryController, _revealController]),
          builder: (context, _) {
            return SizedBox.fromSize(
              size: size,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (
                    var index = 0;
                    index < widget.frontCardAssets.length;
                    index++
                  )
                    _buildAnimatedCard(size: size, cardIndex: index),
                  if (_canReveal) _buildRevealTapTarget(size),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRevealTapTarget(Size size) {
    const cardAspectRatio = 512 / 350;
    final cardHeight = widget.cardWidth * cardAspectRatio;

    return Positioned(
      left: (size.width - widget.cardWidth) / 2,
      top: (size.height - cardHeight) / 2,
      width: widget.cardWidth,
      height: cardHeight,
      child: Semantics(
        button: true,
        label: '카드 확인',
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _revealCards,
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedCard({required Size size, required int cardIndex}) {
    const cardAspectRatio = 512 / 350;
    final cardHeight = widget.cardWidth * cardAspectRatio;
    final cardCount = widget.frontCardAssets.length;
    final center = Offset(size.width / 2, size.height / 2);
    final centeredIndex = cardIndex - (cardCount - 1) / 2;

    // 카드 덱 전체가 위에서 내려와 중앙에 묵직하게 멈춥니다.
    final entryProgress = Curves.easeOutCubic.transform(_entryController.value);
    final entryStart = Offset(center.dx, -cardHeight / 2 - 32);
    final deckOffset = Offset(cardIndex * 0.7, cardIndex * 1.25);
    final deckPosition = center + deckOffset;
    final entryPosition = Offset.lerp(
      entryStart + deckOffset,
      deckPosition,
      entryProgress,
    )!;

    // 1단계: 카드가 겹쳐진 상태에서 덱 전체를 먼저 공개합니다.
    final flipProgress = _intervalProgress(
      _revealController.value,
      0.06,
      0.48,
      Curves.easeInOutCubic,
    );
    final flipLift = math.sin(flipProgress * math.pi);

    // 2단계: 회전이 완전히 끝난 후 좌상단에서 우하단으로 펼칩니다.
    final spreadProgress = _intervalProgress(
      _revealController.value,
      0.52,
      1,
      Curves.easeOutCubic,
    );
    final spreadTarget = Offset(
      center.dx + centeredIndex * widget.spreadStepX,
      center.dy + centeredIndex * widget.spreadStepY,
    );
    var position = Offset.lerp(entryPosition, spreadTarget, spreadProgress)!;
    position += Offset(0, -cardHeight * 0.07 * flipLift);

    final isFrontVisible = flipProgress >= 0.5;
    final yRotation = isFrontVisible
        ? math.pi * (1 - flipProgress)
        : -math.pi * flipProgress;
    final scale = lerpDouble(0.97, 1, entryProgress)! * (1 + flipLift * 0.025);

    return Positioned(
      left: position.dx - widget.cardWidth / 2,
      top: position.dy - cardHeight / 2,
      width: widget.cardWidth,
      height: cardHeight,
      child: IgnorePointer(
        child: Opacity(
          opacity: entryProgress,
          child: Transform.scale(
            scale: scale,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0015)
                ..rotateY(yRotation),
              child: _CardFace(
                asset: isFrontVisible
                    ? widget.frontCardAssets[cardIndex]
                    : widget.backCardAsset ??
                          Assets.games.liarsPoker.images.cards.whiteBack,
                flipLift: flipLift,
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _intervalProgress(
    double value,
    double begin,
    double end,
    Curve curve,
  ) {
    final progress = ((value - begin) / (end - begin)).clamp(0.0, 1.0);
    return curve.transform(progress);
  }
}

class _CardFace extends StatelessWidget {
  const _CardFace({required this.asset, required this.flipLift});

  final AssetGenImage asset;
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
            blurRadius: 7 + flipLift * 8,
            offset: Offset(0, 5 + flipLift * 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: asset.image(
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}
