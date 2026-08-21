import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:project00/core/sound/app_sounds.dart';
import 'package:project00/core/sound/sound_effects.dart';
import 'package:project00/games/shared/animations/curve_intervals.dart';
import 'package:project00/games/shared/animations/progress_sound_cue.dart';
import 'package:project00/games/shared/widgets/game_card_face.dart';
import 'package:project00/games/shared/player_layouts/player_slot_positions.dart';
import 'package:project00/gen/assets.gen.dart';
import 'package:project00/core/assets/game_image.dart';

typedef DealCardBuilder =
    Widget Function(BuildContext context, int playerIndex, int cardIndex);

/// 중앙 카드 더미에서 각 플레이어에게 카드를 빠르게 분배한 뒤,
/// 완성된 카드 묶음을 화면 바깥으로 내보내는 애니메이션입니다.
///
/// [playerCount]와 [cardsPerPlayer]만 바꾸면 전체 카드 수와 분배 속도가
/// 자동으로 다시 계산됩니다. 기본 도착 위치는 `player_layouts`의 2~6인
/// `slotPositions`와 동일합니다.
class CardDealAnimation extends StatefulWidget {
  const CardDealAnimation({
    super.key,
    this.playerCount = 4,
    this.boardSeatCount,
    this.playerSeatIndexes,
    this.cardsPerPlayer = 5,
    this.cardAsset,
    this.cardBuilder,
    this.cardWidth = 168,
    this.duration = const Duration(milliseconds: 2800),
    this.autoplay = false,
    this.tapToStart = true,
    this.backgroundColor,
    this.onCompleted,
  }) : assert(playerCount > 0),
       assert(boardSeatCount == null || boardSeatCount > 0),
       assert(
         playerSeatIndexes == null || playerSeatIndexes.length == playerCount,
         'playerSeatIndexes의 개수는 playerCount와 같아야 합니다.',
       ),
       assert(cardsPerPlayer > 0),
       assert(cardWidth > 0);

  /// 카드를 받는 플레이어 수입니다.
  final int playerCount;

  /// 원래 자리 배치에 존재하는 전체 좌석 수입니다.
  ///
  /// 탈락자를 제외해 [playerCount]가 줄어도 카드 도착 위치는 최초 자리 배치를
  /// 유지해야 합니다. 이때 전체 좌석 수를 전달하고, 생존자의 실제 좌석 번호만
  /// [playerSeatIndexes]에 전달합니다. 생략하면 [playerCount]와 같습니다.
  final int? boardSeatCount;

  /// 플레이어 인덱스별 실제 좌석 번호입니다.
  /// 예: `[2, 0, 1]`이면 첫 번째 플레이어는 2번 좌석으로 분배됩니다.
  final List<int>? playerSeatIndexes;

  /// 플레이어 한 명이 받는 카드 수입니다.
  final int cardsPerPlayer;

  /// [cardBuilder]를 지정하지 않았을 때 표시할 카드 뒷면 에셋입니다.
  final GameImage? cardAsset;

  /// 게임별 카드 UI를 직접 전달할 때 사용합니다.
  final DealCardBuilder? cardBuilder;

  /// 카드 너비입니다. 높이는 실제 카드 비율(350:512)에 맞춰 계산됩니다.
  final double cardWidth;

  /// 등장, 분배, 잠시 대기, 퇴장을 모두 포함한 전체 재생 시간입니다.
  final Duration duration;

  /// 위젯이 화면에 나타나면 바로 재생할지 여부입니다.
  final bool autoplay;

  /// 중앙 카드 더미를 눌렀을 때 분배를 시작할지 여부입니다.
  final bool tapToStart;

  /// 지정하지 않으면 아무 배경도 그리지 않아 뒤쪽 게임 화면이 그대로 보입니다.
  final Color? backgroundColor;
  final VoidCallback? onCompleted;

  @override
  CardDealAnimationState createState() => CardDealAnimationState();
}

class CardDealAnimationState extends State<CardDealAnimation>
    with TickerProviderStateMixin {
  /// 마지막 카드가 도착하는 진행도입니다.
  static const double _dealEnd = 0.72;

  /// 분배 전에 카드 더미가 화면 위에서 중앙으로 내려오는 시간입니다.
  static const Duration _deckEntryDuration = Duration(milliseconds: 620);

  late final AnimationController _controller;

  /// 지금까지 효과음을 재생한 카드 수입니다.
  int _dealtSoundCount = 0;
  double _lastDealProgress = 0;

  /// 분배가 시작되기 전에 카드 더미가 화면 위에서 중앙으로 내려오는 연출입니다.
  late final AnimationController _deckEntryController;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener(_onStatusChanged)
      ..addListener(_playDealingSounds);
    _deckEntryController = AnimationController(
      vsync: this,
      duration: _deckEntryDuration,
    );

    // 카드 더미가 자리를 잡은 뒤에 분배가 시작되도록 순서를 지킵니다.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _deckEntryController.forward();
      if (!mounted || !widget.autoplay) return;
      _controller.forward();
    });
  }

  @override
  void didUpdateWidget(CardDealAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }

    if (!oldWidget.autoplay && widget.autoplay && !_controller.isAnimating) {
      play();
    }
  }

  void _onStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      widget.onCompleted?.call();
    }
  }

  /// 현재 위치부터 재생합니다. [restart]가 true면 처음부터 다시 시작합니다.
  ///
  /// 카드 더미가 아직 내려오는 중이면 도착을 기다린 뒤 분배를 시작합니다.
  void play({bool restart = false}) {
    if (!_deckEntryController.isCompleted) {
      unawaited(
        _deckEntryController.forward().then((_) {
          if (mounted) _startDeal(restart: restart);
        }),
      );
      return;
    }
    _startDeal(restart: restart);
  }

  void _startDeal({required bool restart}) {
    if (restart || _controller.isCompleted) {
      _controller.forward(from: 0);
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller
      ..removeStatusListener(_onStatusChanged)
      ..dispose();
    _deckEntryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animation = ClipRect(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(
            constraints.hasBoundedWidth ? constraints.maxWidth : 480,
            constraints.hasBoundedHeight ? constraints.maxHeight : 320,
          );

          return AnimatedBuilder(
            animation: Listenable.merge([_controller, _deckEntryController]),
            builder: (context, _) => _buildScene(context, size),
          );
        },
      ),
    );

    final backgroundColor = widget.backgroundColor;
    if (backgroundColor == null) {
      return animation;
    }

    return ColoredBox(color: backgroundColor, child: animation);
  }

  Widget _buildScene(BuildContext context, Size size) {
    final totalCards = widget.playerCount * widget.cardsPerPlayer;

    // 역순으로 그려서 현재 분배 중인 카드가 중앙 더미의 맨 위에 보입니다.
    final cards = List<Widget>.generate(totalCards, (reverseIndex) {
      final dealIndex = totalCards - reverseIndex - 1;
      return _buildAnimatedCard(context, size, dealIndex, totalCards);
    });

    if (widget.tapToStart && _controller.value == 0) {
      cards.add(_buildDeckTapTarget(size));
    }

    return SizedBox.fromSize(
      size: size,
      child: Stack(clipBehavior: Clip.none, children: cards),
    );
  }

  Widget _buildDeckTapTarget(Size size) {
    final cardWidth = _effectiveCardWidth(size);
    final cardHeight = cardWidth * kCardAspectRatio;

    return Positioned(
      left: (size.width - cardWidth) / 2,
      top: (size.height - cardHeight) / 2,
      width: cardWidth,
      height: cardHeight + 8,
      child: Semantics(
        button: true,
        label: '카드 분배 시작',
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => play(restart: true),
          ),
        ),
      ),
    );
  }

  /// 카드 한 장이 날아가는 데 쓰는 진행도 길이입니다.
  ///
  /// 카드 수가 많아져도 마지막 카드가 [_dealEnd] 전에 도착하도록 압축합니다.
  static double _flightLength(int totalCards) =>
      math.min(0.15, _dealEnd / totalCards * 3.2);

  /// [dealIndex]번째 카드가 출발하는 진행도입니다.
  static double _dealStartOf(int dealIndex, int totalCards) {
    if (totalCards <= 1) return 0;
    final lastStart = math.max(0.0, _dealEnd - _flightLength(totalCards));
    return lastStart * dealIndex / (totalCards - 1);
  }

  /// 카드가 눈에 보이게 내려앉는 지점입니다(비행 구간 안에서의 비율).
  ///
  /// 비행은 [Curves.easeOutCubic]이라 거리의 97%를 앞쪽 69%의 시간에 끝냅니다
  /// (1-(1-t)^3 = 0.97 → t ≈ 0.69). 남은 31%는 거의 멈춘 듯한 마무리라, 구간
  /// 끝(1.0)에 맞추면 카드가 이미 놓인 뒤에 소리가 들립니다.
  ///
  /// 소리를 더 앞당기려면 이 값만 낮추세요(0에 가까울수록 출발 시점).
  static const double _dealLandingFraction = 0.69;

  /// [dealIndex]번째 카드가 플레이어 앞에 내려앉는 진행도입니다.
  static double _dealLandingOf(int dealIndex, int totalCards) =>
      _dealStartOf(dealIndex, totalCards) +
      _flightLength(totalCards) * _dealLandingFraction;

  /// 카드가 한 장 플레이어 앞에 닿을 때마다 분배 효과음을 한 번 재생합니다.
  ///
  /// 출발이 아니라 도착에 맞춥니다. 출발에 재생하면 카드가 아직 날아가는
  /// 중인데 소리가 먼저 나서 한 장의 비행시간만큼(수백 ms) 앞서 들립니다.
  ///
  /// 화면에 그리는 것과 같은 [_dealStartOf], [_flightLength]로 계산하므로
  /// 연출 시간을 바꿔도 소리가 따로 어긋나지 않습니다. 처음부터 다시
  /// 재생해 진행도가 뒤로 갈 때는 다시 세어 재생합니다.
  void _playDealingSounds() {
    if (!mounted) return;
    final totalCards = widget.playerCount * widget.cardsPerPlayer;
    if (totalCards <= 0) return;

    final progress = _controller.value;
    if (progress < _lastDealProgress) _dealtSoundCount = 0;
    _lastDealProgress = progress;

    final totalMilliseconds = widget.duration.inMilliseconds;
    final leadProgress = totalMilliseconds <= 0
        ? 0.0
        : ProgressSoundCue.lead.inMilliseconds / totalMilliseconds;

    while (_dealtSoundCount < totalCards &&
        progress >=
            _dealLandingOf(_dealtSoundCount, totalCards) - leadProgress) {
      _dealtSoundCount += 1;
      SoundEffects.play(context, AppSounds.dealing);
    }
  }

  Widget _buildAnimatedCard(
    BuildContext context,
    Size size,
    int dealIndex,
    int totalCards,
  ) {
    const exitStart = 0.84;

    final cardWidth = _effectiveCardWidth(size);
    final cardHeight = cardWidth * kCardAspectRatio;
    final center = Offset(size.width / 2, size.height / 2);

    final playerIndex = dealIndex % widget.playerCount;
    final cardIndex = dealIndex ~/ widget.playerCount;
    final playerTarget = _playerTarget(size: size, playerIndex: playerIndex);
    final targetDelta = playerTarget - center;
    final direction = targetDelta.distanceSquared == 0
        ? const Offset(0, -1)
        : targetDelta / targetDelta.distance;
    final angle = math.atan2(direction.dy, direction.dx);
    final tangent = Offset(-direction.dy, direction.dx);

    final stackOffset = tangent * (cardIndex * 1.8);
    final target = playerTarget + stackOffset;

    final flightLength = _flightLength(totalCards);
    final dealStart = _dealStartOf(dealIndex, totalCards);
    final dealProgress = intervalProgress(
      _controller.value,
      dealStart,
      dealStart + flightLength,
      Curves.easeOutCubic,
    );
    final exitProgress = intervalProgress(
      _controller.value,
      exitStart,
      1,
      Curves.easeInCubic,
    );

    // 시작 화면에서 여러 장의 아래쪽 테두리가 보여 카드 더미처럼 느껴집니다.
    final deckLayer = math.min(dealIndex, 7);
    var deckPosition = center + Offset(0, deckLayer * 1.15);

    // 분배 전에는 카드 더미가 화면 위에서 중앙으로 내려옵니다. 모든 카드가
    // 같은 진행도를 쓰기 때문에 낱장이 흩어지지 않고 하나의 더미로 들어옵니다.
    final entryProgress = Curves.easeOutCubic.transform(
      _deckEntryController.value,
    );
    if (entryProgress < 1) {
      final dropDistance = size.height / 2 + cardHeight;
      deckPosition += Offset(0, -dropDistance * (1 - entryProgress));
    }

    var position = Offset.lerp(deckPosition, target, dealProgress)!;

    // 직선보다 생동감 있게 보이도록 이동 중 바깥 방향으로 살짝 휘게 합니다.
    final arc = math.sin(dealProgress * math.pi) * cardWidth * 0.16;
    position += direction * arc;

    final targetRotation = angle + math.pi / 2;
    final rotation =
        targetRotation * dealProgress +
        direction.dx * 0.025 * cardIndex * dealProgress;

    // 분배 구간에는 현재 회전된 카드의 외곽 크기를 기준으로 화면 안에 유지합니다.
    // 등장·퇴장 구간에는 보정을 해제해야 카드 더미가 화면 위에서 내려오고,
    // 분배된 묶음이 정상적으로 밖으로 빠집니다.
    if (exitProgress == 0 && entryProgress >= 1) {
      position = _keepCardInside(
        size: size,
        position: position,
        cardWidth: cardWidth,
        cardHeight: cardHeight,
        rotation: rotation,
      );
    }

    // 분배된 묶음 전체가 각 플레이어 방향의 화면 바깥으로 빠집니다.
    final exitDistance = math.max(size.width, size.height) * 0.82;
    position += direction * exitDistance * exitProgress;

    final opacity =
        1 -
        Curves.easeIn.transform(((exitProgress - 0.68) / 0.32).clamp(0.0, 1.0));

    return Positioned(
      left: position.dx - cardWidth / 2,
      top: position.dy - cardHeight / 2,
      width: cardWidth,
      height: cardHeight,
      child: IgnorePointer(
        child: Opacity(
          opacity: opacity,
          child: Transform.rotate(
            angle: rotation,
            child: _buildCard(context, playerIndex, cardIndex),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, int playerIndex, int cardIndex) {
    return GameCardFace(
      asset:
          widget.cardAsset ?? Assets.games.liarsPoker.images.cards.whiteBack.game,
      radius: 7,
      backgroundColor: null,
      shadow: const BoxShadow(
        color: Color(0x66000000),
        blurRadius: 5,
        offset: Offset(0, 3),
      ),
      child: widget.cardBuilder?.call(context, playerIndex, cardIndex),
    );
  }

  double _effectiveCardWidth(Size size) {
    return math
        .min(widget.cardWidth, math.max(76, size.shortestSide * 0.58))
        .toDouble();
  }

  Offset _keepCardInside({
    required Size size,
    required Offset position,
    required double cardWidth,
    required double cardHeight,
    required double rotation,
  }) {
    const safePadding = 12.0;
    final cosine = math.cos(rotation).abs();
    final sine = math.sin(rotation).abs();

    // 회전된 사각형의 축 정렬 외곽 영역(AABB) 절반 크기입니다.
    final halfBoundsWidth = (cardWidth * cosine + cardHeight * sine) / 2;
    final halfBoundsHeight = (cardWidth * sine + cardHeight * cosine) / 2;

    return Offset(
      _safeCoordinate(
        value: position.dx,
        minimum: halfBoundsWidth + safePadding,
        maximum: size.width - halfBoundsWidth - safePadding,
        fallback: size.width / 2,
      ),
      _safeCoordinate(
        value: position.dy,
        minimum: halfBoundsHeight + safePadding,
        maximum: size.height - halfBoundsHeight - safePadding,
        fallback: size.height / 2,
      ),
    );
  }

  double _safeCoordinate({
    required double value,
    required double minimum,
    required double maximum,
    required double fallback,
  }) {
    if (minimum > maximum) {
      return fallback;
    }

    return value.clamp(minimum, maximum).toDouble();
  }

  Offset _playerTarget({required Size size, required int playerIndex}) {
    final centers = playerCentersForBoard(
      playerCount: widget.boardSeatCount ?? widget.playerCount,
      boardSize: size,
    );
    final seatIndex = widget.playerSeatIndexes?[playerIndex] ?? playerIndex;
    assert(
      seatIndex >= 0 && seatIndex < centers.length,
      'playerSeatIndexes는 좌석판 범위 안에 있어야 합니다.',
    );
    final safeSeatIndex = seatIndex.clamp(0, centers.length - 1);
    return centers[safeSeatIndex];
  }
}
