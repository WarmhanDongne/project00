// [card_receive_animation.dart] 는 휴대폰에서 카드를 받는 연출을 관리하는 파일이다.
//
// - [Package] : 게임 공통 기반
// - [Animation] : 게임 화면의 등장·전환·카드 연출 시간을 관리함
//
// 즉, 게임 진행과 화면 연출이 같은 타이밍으로 움직이게 구성하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:game_kit/shared/animations/curve_intervals.dart';
import 'package:game_kit/shared/widgets/game_card_face.dart';
import 'package:game_kit/game_assets.dart';

// ============================================================

/// 받은 카드 덱이 중앙으로 들어온 뒤, 사용자의 탭을 기다렸다가 공개됩니다.
///
/// 진입 중에는 모든 카드를 뒷면으로 유지합니다. 덱을 누르면 중앙에서
/// 먼저 왼쪽에서 오른쪽 방향으로 회전한 뒤 좌상단에서 우하단으로 펼쳐집니다.
class CardReceiveAnimation extends StatefulWidget {
  const CardReceiveAnimation({
    super.key,
    this.frontCardAssets = const [],
    this.backCardAsset,
    this.cardCount,
    this.cardWidth = 169.0,
    this.spreadStepX = 35.0,
    this.spreadStepY = 35.0,
    this.spreadToLeft = false,
    this.entryCenterOffsetX = 0,
    this.entryCenterOffsetY = 0,
    this.spreadCenterOffsetX = 0,
    this.spreadCenterOffsetY = 0,
    this.totalDuration = const Duration(milliseconds: 2200),
    this.onRevealStarted,
    this.onCompleted,
    this.cardBuilder,
  }) : assert(
         cardBuilder == null
             ? frontCardAssets.length > 0 && backCardAsset != null
             : (cardCount ?? frontCardAssets.length) > 0,
         '카드 그림 또는 cardBuilder와 cardCount가 필요합니다.',
       ),
       assert(cardWidth > 0),
       assert(totalDuration > Duration.zero);

  final List<GameImage> frontCardAssets;
  final GameImage? backCardAsset;

  /// [cardBuilder]로 그릴 때의 장 수입니다. 비우면 [frontCardAssets] 길이를 씁니다.
  final int? cardCount;
  final double cardWidth;
  final double spreadStepX;
  final double spreadStepY;

  /// 가로 화면에서 덱을 중앙에 받은 뒤 오른쪽을 기준으로 왼쪽에 펼칩니다.
  final bool spreadToLeft;

  /// 손패 영역과 실제 화면 중앙이 다를 때 최초 덱 위치를 보정합니다.
  final double entryCenterOffsetX;
  final double entryCenterOffsetY;

  /// 펼침이 끝나는 손패 영역의 중심을 화면 중앙에서 보정합니다.
  final double spreadCenterOffsetX;
  final double spreadCenterOffsetY;

  /// 자동 진입과 탭 후 공개 애니메이션을 합친 기준 시간입니다.
  final Duration totalDuration;

  final VoidCallback? onRevealStarted;
  final VoidCallback? onCompleted;

  /// 카드 그림 대신 위젯으로 카드를 그리는 게임이 씁니다.
  ///
  /// 지정하면 카드 그림 대신 이 위젯을 그립니다. 장 수는 [cardCount]로
  /// 넘깁니다. `front`가 true면 앞면입니다.
  final Widget Function(BuildContext context, int cardIndex, bool front)?
  cardBuilder;

  @override
  State<CardReceiveAnimation> createState() => _CardReceiveAnimationState();
}

class _CardReceiveAnimationState extends State<CardReceiveAnimation>
    with TickerProviderStateMixin {
  int get _cardCount => widget.cardCount ?? widget.frontCardAssets.length;

  late final AnimationController _entryController;
  late final AnimationController _revealController;
  late final AnimationController _idleController;
  late final Listenable _animation;

  bool _isEntryCompleted = false;
  bool _isRevealStarted = false;
  double _revealStartIdleOffsetY = 0;

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
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _animation = Listenable.merge([
      _entryController,
      _revealController,
      _idleController,
    ]);

    _entryController.forward();
  }

  @override
  void didUpdateWidget(CardReceiveAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.totalDuration != widget.totalDuration) {
      _entryController.duration = _entryDuration;
      _revealController.duration = _revealDuration;
    }
  }

  void _handleEntryStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;

    setState(() {
      _isEntryCompleted = true;
    });
    //=======================미공개 덱 대기 모션==============================
    // 카드가 중앙에 도착한 뒤 사용자가 누를 때까지 아주 작게 떠다닙니다.
    _idleController.repeat();
  }

  void _handleRevealStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      widget.onCompleted?.call();
    }
  }

  void _revealCards() {
    if (!_canReveal) return;

    _revealStartIdleOffsetY = _currentIdleOffsetY;
    _idleController.stop();
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
    _idleController.dispose();
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
          animation: _animation,
          builder: (context, _) {
            final frame = _frameFor(size);
            return SizedBox.fromSize(
              size: size,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var index = 0; index < _cardCount; index++)
                    _buildAnimatedCard(frame: frame, cardIndex: index),
                  if (_canReveal) _buildRevealTapTarget(frame),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRevealTapTarget(_PhoneCardFrame frame) {
    return Positioned(
      left: frame.entryCenter.dx - widget.cardWidth / 2,
      top: frame.entryCenter.dy - frame.cardHeight / 2 + frame.deckIdleOffsetY,
      width: widget.cardWidth,
      height: frame.cardHeight,
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

  Widget _buildAnimatedCard({
    required _PhoneCardFrame frame,
    required int cardIndex,
  }) {
    // 카드 덱 전체가 위에서 내려와 중앙에 묵직하게 멈춥니다.
    final entryStart = Offset(frame.entryCenter.dx, -frame.cardHeight / 2 - 32);
    final deckOffset = Offset(cardIndex * 0.7, cardIndex * 1.25);
    final deckPosition = frame.entryCenter + deckOffset;
    final entryPosition =
        Offset.lerp(
          entryStart + deckOffset,
          deckPosition,
          frame.entryProgress,
        )! +
        Offset(0, frame.deckIdleOffsetY);

    // 2단계: 회전이 완전히 끝난 후 손패 방향에 맞춰 펼칩니다.
    final position = widget.spreadToLeft
        ? _leftSpreadPosition(
            geometry: frame.leftSpread!,
            entryPosition: entryPosition,
            cardIndex: cardIndex,
            cardCount: frame.cardCount,
          )
        : _diagonalSpreadPosition(
            center: frame.center,
            entryPosition: entryPosition,
            centeredIndex: cardIndex - (frame.cardCount - 1) / 2,
            spreadProgress: frame.diagonalSpreadProgress,
          );
    var liftedPosition = position;
    liftedPosition += Offset(0, -frame.cardHeight * 0.07 * frame.flipLift);

    return Positioned(
      left: liftedPosition.dx - widget.cardWidth / 2,
      top: liftedPosition.dy - frame.cardHeight / 2,
      width: widget.cardWidth,
      height: frame.cardHeight,
      child: IgnorePointer(
        child: Opacity(
          opacity: frame.entryProgress,
          child: Transform.scale(
            scale: frame.scale,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0015)
                ..rotateY(frame.yRotation),
              child: widget.cardBuilder != null
                  ? widget.cardBuilder!(
                      context,
                      cardIndex,
                      frame.isFrontVisible,
                    )
                  : GameCardFace(
                      asset: frame.isFrontVisible
                          ? widget.frontCardAssets[cardIndex]
                          : widget.backCardAsset!,
                      radius: 8,
                      // 뒤집는 동안 떠 있는 만큼 그림자를 넓고 멀게 만듭니다.
                      shadow: BoxShadow(
                        color: const Color(0x66000000),
                        blurRadius: 7 + frame.flipLift * 8,
                        offset: Offset(0, 5 + frame.flipLift * 5),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Offset _diagonalSpreadPosition({
    required Offset center,
    required Offset entryPosition,
    required double centeredIndex,
    required double spreadProgress,
  }) {
    final spreadTarget = Offset(
      center.dx + centeredIndex * widget.spreadStepX,
      center.dy + centeredIndex * widget.spreadStepY,
    );
    return Offset.lerp(entryPosition, spreadTarget, spreadProgress)!;
  }

  /// 중앙의 덱을 오른쪽 기준점으로 옮긴 뒤 가까운 카드부터 왼쪽으로
  /// 순차적으로 밀어내 한 방향으로 펼쳐지는 인상을 만듭니다.
  Offset _leftSpreadPosition({
    required _LeftSpreadGeometry geometry,
    required Offset entryPosition,
    required int cardIndex,
    required int cardCount,
  }) {
    // 회전 완료 직후에는 모든 카드가 한 덱처럼 함께 기준점으로 이동합니다.
    final anchorPosition = Offset.lerp(
      entryPosition,
      geometry.anchor,
      geometry.anchorProgress,
    )!;

    final distanceFromRight = cardCount - 1 - cardIndex;
    if (distanceFromRight == 0) return anchorPosition;

    // 오른쪽 카드와 가까운 카드부터 출발해 왼쪽 끝까지 차례로 펼칩니다.
    final fanBegin = 0.64 + (distanceFromRight - 1) * 0.045;
    final fanEnd = math.min(1.0, 0.91 + (distanceFromRight - 1) * 0.022);
    final fanProgress = intervalProgress(
      _revealController.value,
      fanBegin,
      fanEnd,
      Curves.easeOutCubic,
    );
    return anchorPosition +
        Offset(-distanceFromRight * geometry.spreadStep * fanProgress, 0);
  }

  _PhoneCardFrame _frameFor(Size size) {
    final cardHeight = widget.cardWidth * kCardAspectRatio;
    final cardCount = _cardCount;
    final center = size.center(Offset.zero);
    final entryProgress = Curves.easeOutCubic.transform(_entryController.value);
    final flipProgress = intervalProgress(
      _revealController.value,
      0.06,
      0.48,
      Curves.easeInOutCubic,
    );
    final flipLift = math.sin(flipProgress * math.pi);
    final isFrontVisible = flipProgress >= 0.5;
    return _PhoneCardFrame(
      cardHeight: cardHeight,
      cardCount: cardCount,
      center: center,
      entryCenter:
          center + Offset(widget.entryCenterOffsetX, widget.entryCenterOffsetY),
      entryProgress: entryProgress,
      deckIdleOffsetY: _deckIdleOffsetY,
      flipLift: flipLift,
      isFrontVisible: isFrontVisible,
      yRotation: isFrontVisible
          ? math.pi * (1 - flipProgress)
          : -math.pi * flipProgress,
      scale: lerpDouble(0.97, 1, entryProgress)! * (1 + flipLift * 0.025),
      diagonalSpreadProgress: intervalProgress(
        _revealController.value,
        0.52,
        1,
        Curves.easeOutCubic,
      ),
      leftSpread: widget.spreadToLeft
          ? _leftSpreadGeometry(
              size: size,
              center: center,
              cardCount: cardCount,
            )
          : null,
    );
  }

  _LeftSpreadGeometry _leftSpreadGeometry({
    required Size size,
    required Offset center,
    required int cardCount,
  }) {
    final availableSpread = math.max(0.0, size.width - widget.cardWidth - 16);
    final requestedStep = widget.spreadStepX.abs();
    final spreadStep = cardCount <= 1
        ? 0.0
        : math.min(requestedStep, availableSpread / (cardCount - 1));
    final totalSpread = spreadStep * math.max(0, cardCount - 1);
    final maxAnchorX = math.max(
      widget.cardWidth / 2,
      size.width - widget.cardWidth / 2 - 8,
    );
    final spreadCenter =
        center + Offset(widget.spreadCenterOffsetX, widget.spreadCenterOffsetY);
    final rightAnchorX = math
        .min(spreadCenter.dx + totalSpread / 2, maxAnchorX)
        .clamp(widget.cardWidth / 2, maxAnchorX)
        .toDouble();
    return _LeftSpreadGeometry(
      anchor: Offset(rightAnchorX, spreadCenter.dy),
      anchorProgress: intervalProgress(
        _revealController.value,
        0.50,
        0.68,
        Curves.easeInOutCubic,
      ),
      spreadStep: spreadStep,
    );
  }

  /// 클릭 전에는 덱이 천천히 위아래로 움직이고, 클릭한 순간의 위치에서
  /// 공개 회전 초반에 자연스럽게 중앙으로 복귀합니다.
  double get _deckIdleOffsetY {
    if (!_isEntryCompleted) return 0;
    if (!_isRevealStarted) return _currentIdleOffsetY;

    final settleProgress = Curves.easeOutCubic.transform(
      (_revealController.value / 0.16).clamp(0.0, 1.0),
    );
    return _revealStartIdleOffsetY * (1 - settleProgress);
  }

  double get _currentIdleOffsetY =>
      math.sin(_idleController.value * math.pi * 2) * 4;
}

@immutable
class _PhoneCardFrame {
  const _PhoneCardFrame({
    required this.cardHeight,
    required this.cardCount,
    required this.center,
    required this.entryCenter,
    required this.entryProgress,
    required this.deckIdleOffsetY,
    required this.flipLift,
    required this.isFrontVisible,
    required this.yRotation,
    required this.scale,
    required this.diagonalSpreadProgress,
    required this.leftSpread,
  });

  final double cardHeight;
  final int cardCount;
  final Offset center;
  final Offset entryCenter;
  final double entryProgress;
  final double deckIdleOffsetY;
  final double flipLift;
  final bool isFrontVisible;
  final double yRotation;
  final double scale;
  final double diagonalSpreadProgress;
  final _LeftSpreadGeometry? leftSpread;
}

@immutable
class _LeftSpreadGeometry {
  const _LeftSpreadGeometry({
    required this.anchor,
    required this.anchorProgress,
    required this.spreadStep,
  });

  final Offset anchor;
  final double anchorProgress;
  final double spreadStep;
}
