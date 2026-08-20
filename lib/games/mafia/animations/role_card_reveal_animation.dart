import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:project00/core/assets/game_image.dart';

/// 역할 카드의 최초 확인부터 하단 보관, 재확인까지 모두 관리합니다.
///
/// 최초 배분 때는 뒷면 카드가 화면 중앙에서 대기합니다. 카드를 누르면
/// 앞면을 3초간 공개한 뒤 다시 뒤집어 화면 아래에 1/5만 보이도록 보관합니다.
/// 이후에는 하단의 카드를 누를 때마다 중앙으로 올라와 같은 동작을 반복합니다.
class RoleCardRevealAnimation extends StatefulWidget {
  const RoleCardRevealAnimation({
    super.key,
    required this.backCardAsset,
    required this.frontCardAsset,
    this.revealedMessage = '당신은 시민입니다',
    this.cardWidth = 200,
    this.flipDuration = const Duration(milliseconds: 860),
    this.moveDuration = const Duration(milliseconds: 720),
    this.revealHoldDuration = const Duration(seconds: 3),
    this.storedVisibleFraction = 0.2,
    this.sparkleCount = 11,
    this.initiallyViewed = false,
    this.onRevealed,
  }) : assert(cardWidth > 0),
       assert(flipDuration > Duration.zero),
       assert(moveDuration > Duration.zero),
       assert(revealHoldDuration > Duration.zero),
       assert(storedVisibleFraction > 0 && storedVisibleFraction < 1),
       assert(sparkleCount > 0);

  final GameImage backCardAsset;
  final GameImage frontCardAsset;
  final String revealedMessage;
  final double cardWidth;
  final Duration flipDuration;
  final Duration moveDuration;
  final Duration revealHoldDuration;
  final double storedVisibleFraction;
  final int sparkleCount;

  /// 재접속처럼 이미 역할을 확인한 상태로 진입할 때 true를 전달합니다.
  final bool initiallyViewed;
  final VoidCallback? onRevealed;

  @override
  State<RoleCardRevealAnimation> createState() =>
      _RoleCardRevealAnimationState();
}

class _RoleCardRevealAnimationState extends State<RoleCardRevealAnimation>
    with TickerProviderStateMixin {
  static const double _cardAspectRatio = 700 / 1026;

  late final AnimationController _sparkleController;
  late final AnimationController _flipController;
  late final AnimationController _positionController;
  late List<_SparkleSpec> _sparkles;

  Timer? _autoStoreTimer;
  late bool _hasBeenViewed;
  bool _isTransitioning = false;

  @override
  void initState() {
    super.initState();
    _hasBeenViewed = widget.initiallyViewed;
    _sparkles = _createSparkles(widget.sparkleCount);
    _sparkleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
    _flipController = AnimationController(
      vsync: this,
      duration: widget.flipDuration,
    );
    _positionController = AnimationController(
      vsync: this,
      duration: widget.moveDuration,
      value: widget.initiallyViewed ? 1 : 0,
    );
  }

  @override
  void didUpdateWidget(RoleCardRevealAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.flipDuration != widget.flipDuration) {
      _flipController.duration = widget.flipDuration;
    }
    if (oldWidget.moveDuration != widget.moveDuration) {
      _positionController.duration = widget.moveDuration;
    }
    if (oldWidget.sparkleCount != widget.sparkleCount) {
      _sparkles = _createSparkles(widget.sparkleCount);
    }
  }

  Future<void> _showRole() async {
    if (_isTransitioning || _flipController.value != 0) return;

    setState(() {
      _isTransitioning = true;
    });

    // 이미 확인한 카드는 먼저 하단 보관 위치에서 중앙으로 올립니다.
    if (_hasBeenViewed) {
      await _positionController.reverse();
      if (!mounted) return;
    }

    await _flipController.forward();
    if (!mounted) return;

    _hasBeenViewed = true;
    widget.onRevealed?.call();
    _autoStoreTimer?.cancel();
    _autoStoreTimer = Timer(widget.revealHoldDuration, () {
      unawaited(_hideAndStoreRole());
    });
  }

  Future<void> _hideAndStoreRole() async {
    if (!mounted) return;

    await _flipController.reverse();
    if (!mounted) return;
    await _positionController.forward();
    if (!mounted) return;

    setState(() {
      _isTransitioning = false;
    });
  }

  List<_SparkleSpec> _createSparkles(int count) {
    final random = math.Random();

    return List.generate(
      count,
      (_) => _SparkleSpec(
        position: Offset(
          0.08 + random.nextDouble() * 0.84,
          0.06 + random.nextDouble() * 0.88,
        ),
        radius: 2.2 + random.nextDouble() * 3.8,
        phase: random.nextDouble(),
        pulseLength: 0.13 + random.nextDouble() * 0.12,
        cycles: 0.8 + random.nextDouble() * 0.9,
      ),
    );
  }

  @override
  void dispose() {
    _autoStoreTimer?.cancel();
    _sparkleController.dispose();
    _flipController.dispose();
    _positionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportSize = Size(
          constraints.hasBoundedWidth ? constraints.maxWidth : 400,
          constraints.hasBoundedHeight ? constraints.maxHeight : 800,
        );

        return AnimatedBuilder(
          animation: Listenable.merge([
            _sparkleController,
            _flipController,
            _positionController,
          ]),
          builder: (context, _) => _buildScene(viewportSize),
        );
      },
    );
  }

  Widget _buildScene(Size viewportSize) {
    final cardWidth = math.min(widget.cardWidth, viewportSize.width * 0.72);
    final cardHeight = cardWidth / _cardAspectRatio;
    final centeredTop = (viewportSize.height - cardHeight) / 2;
    final storedTop =
        viewportSize.height - cardHeight * widget.storedVisibleFraction;
    final positionProgress = Curves.easeInOutCubic.transform(
      _positionController.value,
    );
    final cardTop = Offset.lerp(
      Offset(0, centeredTop),
      Offset(0, storedTop),
      positionProgress,
    )!.dy;

    final flipProgress = Curves.easeInOutCubic.transform(_flipController.value);
    final isFrontVisible = flipProgress >= 0.5;
    final rotationY = isFrontVisible
        ? math.pi * (1 - flipProgress)
        : -math.pi * flipProgress;
    final flipLift = math.sin(flipProgress * math.pi);
    final messageOpacity = isFrontVisible
        ? ((_flipController.value - 0.5) / 0.22).clamp(0.0, 1.0)
        : 0.0;

    return SizedBox.fromSize(
      size: viewportSize,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            left: (viewportSize.width - cardWidth) / 2,
            top: cardTop - 6 * flipLift,
            width: cardWidth,
            height: cardHeight,
            child: Semantics(
              button: !_isTransitioning,
              label: isFrontVisible
                  ? widget.revealedMessage
                  : _hasBeenViewed
                  ? '보관된 역할 카드 다시 확인'
                  : '역할 카드 확인',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _isTransitioning ? null : _showRole,
                child: Transform.scale(
                  scale: 1 + 0.035 * flipLift,
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.0016)
                      ..rotateY(rotationY),
                    child: _RoleCardFace(
                      asset: isFrontVisible
                          ? widget.frontCardAsset
                          : widget.backCardAsset,
                      sparkleProgress: _sparkleController.value,
                      sparkles: _sparkles,
                      flipLift: flipLift,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (messageOpacity > 0)
            Positioned(
              top: (cardTop + cardHeight + 18).clamp(
                0,
                viewportSize.height - 42,
              ),
              left: 20,
              right: 20,
              child: IgnorePointer(
                child: Opacity(
                  opacity: messageOpacity,
                  child: Text(
                    widget.revealedMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFF1E6CC),
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                      shadows: [
                        Shadow(
                          color: Color(0x99000000),
                          blurRadius: 10,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RoleCardFace extends StatelessWidget {
  const _RoleCardFace({
    required this.asset,
    required this.sparkleProgress,
    required this.sparkles,
    required this.flipLift,
  });

  final GameImage asset;
  final double sparkleProgress;
  final List<_SparkleSpec> sparkles;
  final double flipLift;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.38 + 0.18 * flipLift),
            blurRadius: 12 + 15 * flipLift,
            offset: Offset(0, 8 + 8 * flipLift),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Stack(
          fit: StackFit.expand,
          children: [
            asset.image(fit: BoxFit.cover, filterQuality: FilterQuality.high),
            RepaintBoundary(
              child: CustomPaint(
                painter: _SparklePainter(
                  progress: sparkleProgress,
                  sparkles: sparkles,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SparkleSpec {
  const _SparkleSpec({
    required this.position,
    required this.radius,
    required this.phase,
    required this.pulseLength,
    required this.cycles,
  });

  final Offset position;
  final double radius;
  final double phase;
  final double pulseLength;
  final double cycles;
}

class _SparklePainter extends CustomPainter {
  const _SparklePainter({required this.progress, required this.sparkles});

  final double progress;
  final List<_SparkleSpec> sparkles;

  @override
  void paint(Canvas canvas, Size size) {
    for (final sparkle in sparkles) {
      final cycle = (progress * sparkle.cycles + sparkle.phase) % 1;
      if (cycle > sparkle.pulseLength) continue;

      final pulse = math.sin(cycle / sparkle.pulseLength * math.pi);
      final center = Offset(
        sparkle.position.dx * size.width,
        sparkle.position.dy * size.height,
      );
      final radius = sparkle.radius * (0.72 + pulse * 0.42);

      final glowPaint = Paint()
        ..color = Color.fromRGBO(232, 193, 112, pulse * 0.42)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 1.15);
      canvas.drawCircle(center, radius * 1.35, glowPaint);

      final sparklePaint = Paint()
        ..color = Color.fromRGBO(255, 239, 198, pulse * 0.92)
        ..strokeWidth = math.max(0.8, radius * 0.34)
        ..strokeCap = StrokeCap.round;
      canvas
        ..drawLine(
          center - Offset(radius * 1.7, 0),
          center + Offset(radius * 1.7, 0),
          sparklePaint,
        )
        ..drawLine(
          center - Offset(0, radius * 1.7),
          center + Offset(0, radius * 1.7),
          sparklePaint,
        )
        ..drawCircle(center, radius * 0.34, sparklePaint);
    }
  }

  @override
  bool shouldRepaint(_SparklePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.sparkles != sparkles;
  }
}
