// [card_deal_animation.dart] 는 태블릿 카드 분배 애니메이션을 관리하는 파일이다.
//
// - [Package] : 게임 공통 기반
// - [Animation] : 카드 더미 등장 → 플레이어별 분배 → 화면 밖 퇴장 흐름을 관리함
//
// 즉, 게임마다 같은 카드 분배 연출을 일관된 순서와 속도로 재생하기 위한 파일이다.

// ========================[ import ]==========================
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:game_kit/core/sound/app_sounds.dart';
import 'package:game_kit/core/sound/sound_effects.dart';
import 'package:game_kit/shared/animations/curve_intervals.dart';
import 'package:game_kit/shared/animations/progress_sound_cue.dart';
import 'package:game_kit/widgets/game_card_face.dart';
import 'package:game_kit/player_layouts/player_slot_positions.dart';
import 'package:game_kit/game_assets.dart';

// ============================================================

typedef DealCardBuilder =
    Widget Function(BuildContext context, int playerIndex, int cardIndex);

/// 중앙 카드 더미에서 각 플레이어에게 카드를 빠르게 분배한 뒤,
/// 플레이어 앞에 놓인 카드 묶음을 화면 밖으로 내보내는 애니메이션입니다.
///
/// [playerCount]와 [cardsPerPlayer]를 기준으로 전체 카드 수와 분배 간격을
/// 자동으로 계산합니다.
///
/// 기본 카드 도착 위치는 `player_layouts`의 2~6인용 `slotPositions`와
/// 동일한 좌석 배치를 사용합니다.
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
    this.beforeDelay = Duration.zero,
    this.afterDelay = Duration.zero,
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
  /// 탈락자가 생겨 [playerCount]가 줄어도 카드 도착 위치는 처음 좌석 배치를
  /// 유지해야 합니다.
  ///
  /// 이 경우 전체 좌석 수는 [boardSeatCount]에,
  /// 현재 생존자의 실제 좌석 번호는 [playerSeatIndexes]에 전달합니다.
  /// 생략하면 [playerCount]와 같은 값으로 처리합니다.
  final int? boardSeatCount;

  /// 플레이어 인덱스별 실제 좌석 번호입니다.
  ///
  /// 예: `[2, 0, 1]`
  /// - 0번 플레이어 → 2번 좌석
  /// - 1번 플레이어 → 0번 좌석
  /// - 2번 플레이어 → 1번 좌석
  final List<int>? playerSeatIndexes;

  /// 플레이어 한 명이 받는 카드 수입니다.
  final int cardsPerPlayer;

  /// [cardBuilder]를 지정하지 않았을 때 표시할 카드 뒷면 에셋입니다.
  final GameImage? cardAsset;

  /// 게임별 카드 UI를 직접 전달할 때 사용합니다.
  final DealCardBuilder? cardBuilder;

  /// 카드 너비입니다. 높이는 실제 카드 비율(350:512)에 맞춰 계산됩니다.
  final double cardWidth;

  /// 카드 분배 시작부터 카드 묶음 퇴장까지의 전체 재생 시간입니다.
  ///
  /// 카드 더미가 화면 위에서 중앙으로 내려오는 시간은
  /// [_deckEntryDuration]으로 별도 관리됩니다.
  final Duration duration;

  /// 시작 탭(또는 autoplay) 뒤 분배를 시작하기 전 대기시간입니다.
  /// 덱 등장 620ms와 별개이며, 첫 라운드의 tapToStart 정책은 바꾸지 않습니다.
  final Duration beforeDelay;

  /// 분배 연출이 끝난 뒤 서버 완료 콜백을 보내기 전 대기시간입니다.
  final Duration afterDelay;

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
  /// 전체 진행도 중 마지막 카드 분배가 끝나는 지점입니다.
  static const double _dealEnd = 0.72;

  /// 분배 전, 카드 더미가 화면 위에서 중앙으로 내려오는 시간입니다.
  static const Duration _deckEntryDuration = Duration(milliseconds: 620);

  late final AnimationController _controller;
  late final Listenable _animation;
  Timer? _startDelayTimer;
  Timer? _completionTimer;
  bool _hasStarted = false;

  /// 현재까지 분배 효과음을 재생한 카드 수입니다.
  int _dealtSoundCount = 0;
  double _lastDealProgress = 0;

  /// 카드 더미의 등장 연출만 담당하는 컨트롤러입니다.
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

    _animation = Listenable.merge([_controller, _deckEntryController]);

    // 1. 카드 더미를 먼저 중앙으로 내려보냅니다.
    // 2. autoplay가 켜져 있으면 등장 연출이 끝난 뒤 카드 분배를 시작합니다.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      await _deckEntryController.forward();

      if (!mounted || !widget.autoplay) return;

      _startDeal(restart: false);
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
      _completionTimer?.cancel();
      if (widget.afterDelay == Duration.zero) {
        widget.onCompleted?.call();
        return;
      }
      _completionTimer = Timer(widget.afterDelay, () {
        if (mounted) widget.onCompleted?.call();
      });
    }
  }

  /// 현재 진행 위치부터 카드 분배를 재생합니다.
  ///
  /// [restart]가 true이면 처음부터 다시 시작합니다.
  /// 카드 더미가 아직 중앙에 도착하지 않았다면, 등장 연출이 끝난 뒤
  /// 분배를 시작합니다.
  void play({bool restart = false}) {
    if (!_deckEntryController.isCompleted) {
      unawaited(
        _deckEntryController.forward().then((_) {
          if (mounted) {
            _startDeal(restart: restart);
          }
        }),
      );
      return;
    }

    _startDeal(restart: restart);
  }

  void _startDeal({required bool restart}) {
    // 서버 완료를 기다리는 중 다시 탭해도 분배를 두 번 재생하지 않습니다.
    if (_hasStarted && !restart) return;
    _hasStarted = true;
    _startDelayTimer?.cancel();
    _completionTimer?.cancel();
    if (widget.beforeDelay == Duration.zero) {
      _controller.forward(from: restart ? 0 : null);
      return;
    }
    _startDelayTimer = Timer(widget.beforeDelay, () {
      if (mounted) _controller.forward(from: restart ? 0 : null);
    });
  }

  @override
  void dispose() {
    _startDelayTimer?.cancel();
    _completionTimer?.cancel();
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
            animation: _animation,
            builder: (context, _) {
              return _buildScene(context, size);
            },
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
    final cardWidth = _effectiveCardWidth(size);
    final cardHeight = cardWidth * kCardAspectRatio;
    final center = size.center(Offset.zero);

    final playerGeometries = _playerGeometries(size: size, center: center);

    final flightLength = _flightLength(totalCards);
    final lastDealStart = math.max(0.0, _dealEnd - flightLength);

    final entryProgress = Curves.easeOutCubic.transform(
      _deckEntryController.value,
    );

    final exitProgress = intervalProgress(
      _controller.value,
      0.84,
      1,
      Curves.easeInCubic,
    );

    final exitDistance = math.max(size.width, size.height) * 0.82;

    // 카드를 역순으로 쌓아 현재 분배 중인 카드가
    // 항상 중앙 카드 더미의 가장 위에 보이도록 합니다.
    final cards = List<Widget>.generate(totalCards, (reverseIndex) {
      final dealIndex = totalCards - reverseIndex - 1;

      return _buildAnimatedCard(
        context,
        size: size,
        dealIndex: dealIndex,
        totalCards: totalCards,
        cardWidth: cardWidth,
        cardHeight: cardHeight,
        center: center,
        playerGeometries: playerGeometries,
        flightLength: flightLength,
        lastDealStart: lastDealStart,
        entryProgress: entryProgress,
        exitProgress: exitProgress,
        exitDistance: exitDistance,
      );
    });

    if (widget.tapToStart && _controller.value == 0) {
      cards.add(
        _buildDeckTapTarget(size, cardWidth: cardWidth, cardHeight: cardHeight),
      );
    }

    return SizedBox.fromSize(
      size: size,
      child: Stack(clipBehavior: Clip.none, children: cards),
    );
  }

  Widget _buildDeckTapTarget(
    Size size, {
    required double cardWidth,
    required double cardHeight,
  }) {
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

  /// 카드 한 장이 중앙에서 플레이어 위치까지 이동하는 진행도 길이입니다.
  ///
  /// 카드 수가 많아져도 마지막 카드가 [_dealEnd] 이전에 도착하도록
  /// 카드 한 장당 비행 구간을 자동으로 압축합니다.
  static double _flightLength(int totalCards) {
    return math.min(0.15, _dealEnd / totalCards * 3.2);
  }

  /// [dealIndex]번째 카드가 출발하는 진행도를 계산합니다.
  static double _dealStartOf(int dealIndex, int totalCards) {
    if (totalCards <= 1) {
      return 0;
    }

    final lastStart = math.max(0.0, _dealEnd - _flightLength(totalCards));

    return lastStart * dealIndex / (totalCards - 1);
  }

  /// 카드가 실제로 플레이어 앞에 내려앉았다고 판단하는 시점입니다.
  ///
  /// 카드 이동에는 [Curves.easeOutCubic]을 사용하므로 초반에 대부분의 거리를
  /// 빠르게 이동하고, 마지막 구간에서는 거의 멈춘 듯 천천히 마무리됩니다.
  ///
  /// 따라서 비행 구간의 끝(1.0)이 아니라 약 69% 지점을 도착 시점으로 사용해
  /// 카드가 보이는 순간과 효과음이 자연스럽게 맞도록 합니다.
  ///
  /// 값을 낮출수록 효과음이 더 일찍 재생됩니다.
  static const double _dealLandingFraction = 0.69;

  /// [dealIndex]번째 카드가 플레이어 앞에 도착하는 진행도를 계산합니다.
  static double _dealLandingOf(int dealIndex, int totalCards) {
    return _dealStartOf(dealIndex, totalCards) +
        _flightLength(totalCards) * _dealLandingFraction;
  }

  /// 카드가 플레이어 앞에 도착할 때마다 분배 효과음을 한 번 재생합니다.
  ///
  /// 화면 애니메이션과 동일한 [_dealStartOf], [_flightLength] 계산을 사용하므로
  /// 전체 재생 시간을 변경해도 카드 움직임과 효과음이 함께 맞춰집니다.
  ///
  /// 애니메이션 진행도가 뒤로 이동한 경우에는 재생 횟수를 초기화하여
  /// 처음부터 다시 효과음을 낼 수 있도록 합니다.
  void _playDealingSounds() {
    if (!mounted) return;

    final totalCards = widget.playerCount * widget.cardsPerPlayer;

    if (totalCards <= 0) return;

    final progress = _controller.value;

    if (progress < _lastDealProgress) {
      _dealtSoundCount = 0;
    }

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
    BuildContext context, {
    required Size size,
    required int dealIndex,
    required int totalCards,
    required double cardWidth,
    required double cardHeight,
    required Offset center,
    required List<_PlayerDealGeometry> playerGeometries,
    required double flightLength,
    required double lastDealStart,
    required double entryProgress,
    required double exitProgress,
    required double exitDistance,
  }) {
    final playerIndex = dealIndex % widget.playerCount;

    final cardIndex = dealIndex ~/ widget.playerCount;

    final playerGeometry = playerGeometries[playerIndex];

    final stackOffset = playerGeometry.tangent * (cardIndex * 1.8);

    final target = playerGeometry.target + stackOffset;

    final dealStart = totalCards <= 1
        ? 0.0
        : lastDealStart * dealIndex / (totalCards - 1);

    final dealProgress = intervalProgress(
      _controller.value,
      dealStart,
      dealStart + flightLength,
      Curves.easeOutCubic,
    );

    // 시작 화면에서는 카드마다 약간의 세로 간격을 주어
    // 중앙에 여러 장이 겹쳐 있는 카드 더미처럼 보이게 합니다.
    final deckLayer = math.min(dealIndex, 7);

    var deckPosition = center + Offset(0, deckLayer * 1.15);

    // 분배 전에는 모든 카드가 같은 진행도로 화면 위에서 내려옵니다.
    // 개별 카드가 따로 움직이지 않기 때문에 하나의 카드 더미처럼 보입니다.
    if (entryProgress < 1) {
      final dropDistance = size.height / 2 + cardHeight;

      deckPosition += Offset(0, -dropDistance * (1 - entryProgress));
    }

    var position = Offset.lerp(deckPosition, target, dealProgress)!;

    // 완전한 직선 이동보다 자연스럽게 보이도록
    // 이동 중 플레이어 방향으로 약한 곡선을 추가합니다.
    final arc = math.sin(dealProgress * math.pi) * cardWidth * 0.16;

    position += playerGeometry.direction * arc;

    final targetRotation = playerGeometry.angle + math.pi / 2;

    final rotation =
        targetRotation * dealProgress +
        playerGeometry.direction.dx * 0.025 * cardIndex * dealProgress;

    // 카드 분배 중에는 회전된 카드의 실제 외곽 크기(AABB)를 기준으로
    // 화면 밖으로 잘리지 않도록 위치를 보정합니다.
    //
    // 단, 카드 더미 등장과 카드 묶음 퇴장 중에는 화면 밖 이동이 필요하므로
    // 이 보정을 적용하지 않습니다.
    if (exitProgress == 0 && entryProgress >= 1) {
      position = _keepCardInside(
        size: size,
        position: position,
        cardWidth: cardWidth,
        cardHeight: cardHeight,
        rotation: rotation,
      );
    }

    // 분배가 끝나면 플레이어별 카드 묶음을
    // 각 좌석 방향으로 화면 밖까지 이동시킵니다.
    position += playerGeometry.direction * exitDistance * exitProgress;

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
    final asset = widget.cardAsset;

    if (asset == null) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF252027),
          borderRadius: BorderRadius.circular(7),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 5,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: widget.cardBuilder?.call(context, playerIndex, cardIndex),
      );
    }

    return GameCardFace(
      asset: asset,
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

    // 회전된 카드가 차지하는 축 정렬 외곽 영역(AABB)의 절반 크기입니다.
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

  List<_PlayerDealGeometry> _playerGeometries({
    required Size size,
    required Offset center,
  }) {
    final centers = playerCentersForBoard(
      playerCount: widget.boardSeatCount ?? widget.playerCount,
      boardSize: size,
    );

    return List<_PlayerDealGeometry>.generate(widget.playerCount, (
      playerIndex,
    ) {
      final seatIndex = widget.playerSeatIndexes?[playerIndex] ?? playerIndex;

      assert(
        seatIndex >= 0 && seatIndex < centers.length,
        'playerSeatIndexes는 좌석판 범위 안에 있어야 합니다.',
      );

      final safeSeatIndex = seatIndex.clamp(0, centers.length - 1);

      final target = centers[safeSeatIndex];

      final targetDelta = target - center;

      final direction = targetDelta.distanceSquared == 0
          ? const Offset(0, -1)
          : targetDelta / targetDelta.distance;

      return _PlayerDealGeometry(
        target: target,
        direction: direction,
        angle: math.atan2(direction.dy, direction.dx),
        tangent: Offset(-direction.dy, direction.dx),
      );
    }, growable: false);
  }
}

@immutable
class _PlayerDealGeometry {
  const _PlayerDealGeometry({
    required this.target,
    required this.direction,
    required this.angle,
    required this.tangent,
  });

  final Offset target;
  final Offset direction;
  final double angle;
  final Offset tangent;
}
