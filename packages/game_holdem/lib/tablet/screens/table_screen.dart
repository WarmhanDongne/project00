import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:game_holdem/game_assets.dart';
import 'package:game_holdem/game_copy.dart';
import 'package:game_holdem/game_sounds.dart';
import 'package:game_holdem/game_theme.dart';
import 'package:game_holdem/shared/models/game_models.dart';
import 'package:game_holdem/shared/models/game_state.dart';
import 'package:game_holdem/shared/models/presentation_timing.dart';
import 'package:game_holdem/shared/widgets/card_view.dart';
import 'package:game_holdem/shared/widgets/table_ui.dart';
import 'package:game_holdem/tablet/animations/action_motion.dart';
import 'package:game_holdem/tablet/animations/card_deal_animation.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:game_kit/player_layouts/models/player_layout.dart';
import 'package:game_kit/player_layouts/services/player_slot_positions.dart';
import 'package:game_kit/shared/animations/progress_sound_cue.dart';
import 'package:game_kit/shared/widgets/game_turn_countdown.dart';
import 'package:game_kit/shared/widgets/game_turn_countdown_face.dart';
import 'package:game_kit/sound/game_background_music.dart';

/// 시안 기준 태블릿 크기입니다. 실제 화면은 짧은 쪽 비율로 맞춥니다.
const _designSize = Size(1366, 1024);
const _actionWindow = Duration(seconds: 20);

/// 모두가 함께 보는 공용 홀덤 테이블입니다.
///
/// 좌석 중심은 기존 자리 배치 좌표([normalizedPlayerCenters])를 그대로 쓰고,
/// 각 좌석의 글자만 그 자리에 앉은 사람 쪽을 향하도록 90° 단위로 돌립니다.
class HoldemTableScreen extends StatefulWidget {
  const HoldemTableScreen({
    super.key,
    required this.game,
    required this.playerLayout,
  });
  final HoldemGameState game;
  final PlayerLayoutModel playerLayout;

  @override
  State<HoldemTableScreen> createState() => _HoldemTableScreenState();
}

class _HoldemTableScreenState extends State<HoldemTableScreen>
    with TickerProviderStateMixin {
  /// 이번 스트리트에서 좌석별로 마지막에 한 행동입니다.
  ///
  /// 서버는 마지막 공개 행동 하나만 내려 주므로 태블릿이 스트리트 동안
  /// 관찰한 행동을 모아 좌석 라벨로 씁니다. 재실행 직후에는 비어 있고 금액만
  /// 표시합니다.
  final Map<String, String> _streetActions = {};
  (int, String)? _street;
  late final AnimationController _actionController;
  final ProgressSoundCue _chipLandingCue = ProgressSoundCue();
  final ProgressSoundCue _actionCue = ProgressSoundCue();
  final ProgressSoundCue _awardCue = ProgressSoundCue();
  final GameBackgroundMusic _backgroundMusic = GameBackgroundMusic();
  late final AnimationController _awardController;
  late final AnimationController _resultHoldController;
  final List<_TableActionEvent> _actionQueue = [];
  _TableActionEvent? _activeAction;
  String? _observedActionKey;
  int? _observedBlindHand;
  String? _observedResultKey;
  Map<String, int> _awardStartStacks = const {};
  Timer? _actionGapTimer;
  Timer? _awardStartTimer;
  int? _dealCompletedHand;

  @override
  void initState() {
    super.initState();
    _actionController =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 1450),
          )
          ..addListener(_playActionSounds)
          ..addStatusListener(_onActionStatus);
    _awardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1450),
    )..addListener(_playAwardSound);
    _resultHoldController = AnimationController(vsync: this);
    _observedActionKey = _actionKey(widget.game);
    _observeForcedBlinds();
    _observeResult(HoldemGameState.initial());
    // 결과 화면 복원 때 이미 지급된 팟 소리를 반복하지 않습니다.
    _awardCue.markPlayed();
    _syncStreetActions();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _backgroundMusic.attach(context);
    _scheduleBackgroundMusic();
  }

  @override
  void didUpdateWidget(covariant HoldemTableScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _observeForcedBlinds();
    _observeAction();
    _observeResult(oldWidget.game);
    _syncStreetActions();
    _scheduleBackgroundMusic();
  }

  @override
  void dispose() {
    _backgroundMusic.stop();
    _actionGapTimer?.cancel();
    _awardStartTimer?.cancel();
    _actionController
      ..removeListener(_playActionSounds)
      ..removeStatusListener(_onActionStatus)
      ..dispose();
    _awardController.dispose();
    _resultHoldController.dispose();
    super.dispose();
  }

  void _scheduleBackgroundMusic() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!widget.game.loading && widget.game.status == 'playing') {
        _backgroundMusic.start(HoldemSounds.background);
      } else {
        _backgroundMusic.stop();
      }
    });
  }

  void _observeResult(HoldemGameState previous) {
    final key = _resultKey(widget.game);
    if (key == null) {
      _observedResultKey = null;
      _awardStartTimer?.cancel();
      _awardStartStacks = const {};
      _awardController.reset();
      _resultHoldController.reset();
      return;
    }
    if (key == _observedResultKey) return;
    _observedResultKey = key;
    _awardCue.reset();
    final result = widget.game.result!;
    _resultHoldController
      ..duration = HoldemTiming.handResult(result.reason)
      ..forward(from: 0);
    _awardStartStacks = {
      for (final uid in result.winnerUids)
        uid:
            previous.players[uid]?.stack ??
            ((widget.game.players[uid]?.stack ?? 0) - (result.awards[uid] ?? 0))
                .clamp(0, 1 << 31)
                .toInt(),
    };
    _awardController.reset();
    _awardStartTimer?.cancel();
    final delay = result.reason == 'fold'
        ? const Duration(milliseconds: 1050)
        : const Duration(seconds: 8);
    _awardStartTimer = Timer(delay, () {
      if (mounted && _resultKey(widget.game) == key) {
        _awardController.forward(from: 0);
      }
    });
  }

  String? _resultKey(HoldemGameState game) {
    final result = game.result;
    if (game.phase != 'handResult' || result == null) return null;
    final awards = result.awards.entries.toList()
      ..sort((left, right) => left.key.compareTo(right.key));
    return '${game.handNumber}:${result.reason}:'
        '${awards.map((entry) => '${entry.key}-${entry.value}').join(',')}';
  }

  void _observeAction() {
    final key = _actionKey(widget.game);
    if (key == null || key == _observedActionKey) return;
    _observedActionKey = key;
    final action = widget.game.lastAction!;
    if (!const {
      'fold',
      'check',
      'bet',
      'call',
      'raise',
      'allIn',
    }.contains(action.kind)) {
      return;
    }
    _actionQueue.add(
      _TableActionEvent(
        key: key,
        uid: action.uid,
        kind: action.kind,
        amount: action.amount,
      ),
    );
    _startNextAction();
  }

  void _observeForcedBlinds() {
    final game = widget.game;
    if (_observedBlindHand == game.handNumber ||
        game.phase != 'preflop' ||
        game.lastAction != null) {
      return;
    }
    final small = game.players[game.smallBlindUid]?.streetContribution ?? 0;
    final big = game.players[game.bigBlindUid]?.streetContribution ?? 0;
    if (small <= 0 || big <= 0 || game.smallBlindUid == game.bigBlindUid) {
      return;
    }
    _observedBlindHand = game.handNumber;
    for (final (uid, amount) in [
      (game.smallBlindUid, math.min(small, game.smallBlind)),
      (game.bigBlindUid, math.min(big, game.bigBlind)),
    ]) {
      _actionQueue.add(
        _TableActionEvent(
          key: 'blind:${game.handNumber}:$uid',
          uid: uid,
          kind: 'blind',
          amount: amount,
        ),
      );
    }
    _startNextAction();
  }

  String? _actionKey(HoldemGameState game) {
    final action = game.lastAction;
    if (action == null) return null;
    return '${game.handNumber}:${action.createdAt}:${action.uid}:'
        '${action.kind}:${action.amount}';
  }

  void _startNextAction() {
    if (_activeAction != null || _actionQueue.isEmpty) return;
    _activeAction = _actionQueue.removeAt(0);
    _chipLandingCue.reset();
    _actionCue.reset();
    _actionController.duration = switch (_activeAction!.kind) {
      'blind' => const Duration(milliseconds: 1150),
      'fold' => const Duration(milliseconds: 1050),
      'check' => const Duration(milliseconds: 1100),
      _ => const Duration(milliseconds: 1450),
    };
    _actionController.forward(from: 0);
  }

  void _playAwardSound() {
    if (!mounted || _awardStartStacks.isEmpty) return;
    // 팟 칩이 중앙에서 출발하는 .2 지점에 맞춰 한 번만 재생합니다.
    _awardCue.maybePlay(
      context,
      HoldemSounds.potAward,
      value: _awardController.value,
      threshold:
          .2 -
          ProgressSoundCue.lead.inMilliseconds /
              _awardController.duration!.inMilliseconds,
    );
  }

  void _playActionSounds() {
    if (!mounted || _activeAction == null) return;
    final kind = _activeAction!.kind;
    final duration = _actionController.duration!.inMilliseconds;
    final asset = switch (kind) {
      'check' => HoldemSounds.check,
      'fold' => HoldemSounds.cardTable,
      'allIn' => HoldemSounds.allIn,
      _ => null,
    };
    if (asset != null) {
      // 폴드는 라이어스 포커처럼 착지 시점에, 체크는 퍽 도착에 맞춥니다.
      // 올인은 행동 연출 시작과 함께 강조하고 칩 착지음은 별도로 유지합니다.
      final threshold = switch (kind) {
        'fold' => .73,
        'check' => .7 - ProgressSoundCue.lead.inMilliseconds / duration,
        _ => 0.0,
      };
      _actionCue.maybePlay(
        context,
        asset,
        value: _actionController.value,
        threshold: threshold,
      );
    }
    _playChipLandingSound();
  }

  void _playChipLandingSound() {
    if (!mounted ||
        !const {
          'blind',
          'bet',
          'call',
          'raise',
          'allIn',
        }.contains(_activeAction?.kind)) {
      return;
    }
    final durationMs = _actionController.duration?.inMilliseconds ?? 0;
    if (durationMs <= 0) return;
    // 첫 칩이 중앙에 닿는 진행도는 action_motion.dart의 travel 끝점 .61입니다.
    // 기기 출력 지연만큼 먼저 요청해 실제 소리가 착지에 맞게 들리도록 합니다.
    final threshold = .61 - ProgressSoundCue.lead.inMilliseconds / durationMs;
    _chipLandingCue.maybePlay(
      context,
      HoldemSounds.chipLanding,
      value: _actionController.value,
      threshold: threshold,
    );
  }

  void _onActionStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    setState(() => _activeAction = null);
    if (_actionQueue.isEmpty) return;
    // 완료 status listener와 같은 프레임에서 controller를 재시작하면 큰 frame
    // interval을 다음 행동이 물려받아 첫 장면이 건너뛰어질 수 있습니다. 아주 짧은
    // 숨을 둔 뒤 큐를 넘겨 빠른 연속 행동도 처음부터 확실히 보이게 합니다.
    _actionGapTimer?.cancel();
    _actionGapTimer = Timer(const Duration(milliseconds: 40), () {
      if (!mounted) return;
      setState(_startNextAction);
    });
  }

  void _syncStreetActions() {
    final game = widget.game;
    final street = (game.handNumber, game.phase);
    if (_street != street) {
      _street = street;
      _streetActions.clear();
    }
    final last = game.lastAction;
    if (last != null) _streetActions[last.uid] = last.kind;
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final scale = math.min(
          size.width / _designSize.width,
          size.height / _designSize.height,
        );
        final centers = normalizedPlayerCenters(
          widget.playerLayout.playerCount,
        );
        final dealSeats = widget.playerLayout.players
            .where((player) => game.players[player.uid]?.status == 'alive')
            .map((player) => player.seatIndex)
            .toList(growable: false);
        final seatSize = const Size(240, 170) * scale;
        final showdown = game.phase == 'handResult' ? game.result : null;
        final tableCenter = size.center(Offset.zero);
        // 칩은 커뮤니티 카드의 정중앙에 먼저 떨어진 뒤, 카드 아래쪽의 중앙
        // 팟으로 짧게 흘러 모입니다. 좌우 어느 자리에서도 같은 중앙을 봅니다.
        final potTarget = tableCenter + Offset(0, 216 * scale);
        return Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: HoldemColors.felt),
            HoldemAssets.tabletBackground.image(
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
            Center(
              child: Container(
                width: 840 * scale,
                height: 530 * scale,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(265 * scale),
                  border: Border.all(color: HoldemColors.line(.16), width: 2),
                ),
              ),
            ),
            if (game.phase != 'dealing')
              Center(
                child: AnimatedBuilder(
                  key: const Key('holdem-table-center'),
                  animation: _awardController,
                  builder: (_, child) => Opacity(
                    key: const Key('holdem-center-opacity'),
                    opacity: showdown == null
                        ? 1
                        : (1 - _awardController.value / .18).clamp(0.0, 1.0),
                    child: child,
                  ),
                  child: _TableCenter(
                    game: game,
                    result: showdown,
                    scale: scale,
                  ),
                ),
              ),
            if (game.phase != 'dealing')
              AnimatedBuilder(
                animation: _awardController,
                child: HoldemPotChipStack(amount: game.potTotal, scale: scale),
                builder: (_, child) {
                  final gather = showdown == null
                      ? 0.0
                      : Curves.easeOutCubic.transform(
                          (_awardController.value / .2).clamp(0.0, 1.0),
                        );
                  final position = Offset.lerp(potTarget, tableCenter, gather)!;
                  final opacity = showdown == null
                      ? 1.0
                      : ((.44 - _awardController.value) / .22).clamp(0.0, 1.0);
                  return Positioned(
                    left: position.dx - 62 * scale,
                    top: position.dy - 26 * scale,
                    width: 124 * scale,
                    height: 52 * scale,
                    child: Opacity(opacity: opacity, child: child),
                  );
                },
              ),
            for (final layoutPlayer in widget.playerLayout.players)
              if (layoutPlayer.seatIndex >= 0 &&
                  layoutPlayer.seatIndex < centers.length)
                Positioned(
                  left:
                      centers[layoutPlayer.seatIndex].dx * size.width -
                      seatSize.width / 2,
                  top:
                      centers[layoutPlayer.seatIndex].dy * size.height -
                      seatSize.height / 2,
                  width: seatSize.width,
                  height: seatSize.height,
                  child: Transform.rotate(
                    angle: _seatRotation(centers[layoutPlayer.seatIndex]),
                    child: FittedBox(
                      child: SizedBox(
                        width: 240,
                        height: 170,
                        child: _Seat(
                          game: game,
                          uid: layoutPlayer.uid,
                          result: showdown,
                          streetAction: _streetActions[layoutPlayer.uid],
                          stackStart: _awardStartStacks[layoutPlayer.uid],
                          stackAnimation: _awardController,
                          showCards:
                              game.phase != 'dealing' ||
                              _dealCompletedHand == game.handNumber,
                        ),
                      ),
                    ),
                  ),
                ),
            if (_activeAction case final action?)
              Positioned.fill(
                child: HoldemTableActionMotion(
                  key: ValueKey(action.key),
                  progress: _actionController,
                  kind: action.kind,
                  amount: action.amount,
                  source: _actionSource(
                    uid: action.uid,
                    centers: centers,
                    boardSize: size,
                    tableCenter: tableCenter,
                    scale: scale,
                  ),
                  potTarget: potTarget,
                  tableCenter: tableCenter,
                  scale: scale,
                ),
              ),
            if (showdown != null && _awardStartStacks.isNotEmpty)
              for (final (index, uid) in showdown.winnerUids.indexed)
                if ((showdown.awards[uid] ?? 0) > 0)
                  Positioned.fill(
                    child: HoldemPotAwardMotion(
                      progress: _awardController,
                      amount: showdown.awards[uid]!,
                      source: tableCenter,
                      target: _actionSource(
                        uid: uid,
                        centers: centers,
                        boardSize: size,
                        tableCenter: tableCenter,
                        scale: scale,
                      ),
                      scale: scale,
                      delay: index * .08,
                    ),
                  ),
            if (showdown?.reason == 'showdown')
              Positioned(
                top: 36 * scale,
                left: 0,
                right: 0,
                child: Center(
                  child: AnimatedBuilder(
                    animation: _resultHoldController,
                    builder: (_, _) {
                      final remaining =
                          _resultHoldController.duration! *
                          (1 - _resultHoldController.value);
                      final seconds = math.max(
                        0,
                        (remaining.inMilliseconds / 1000).ceil(),
                      );
                      return HoldemPill(
                        key: const Key('holdem-showdown-countdown'),
                        label: '공개 카드 확인 · $seconds초',
                        fontSize: 16 * scale,
                      );
                    },
                  ),
                ),
              ),
            if (game.phase == 'dealing' && dealSeats.isNotEmpty)
              HoldemCardDealAnimation(
                key: ValueKey('holdem-deal-${game.handNumber}'),
                seatCount: widget.playerLayout.playerCount,
                seatIndexes: dealSeats,
                scale: scale,
                onCompleted: () {
                  if (mounted && widget.game.handNumber == game.handNumber) {
                    setState(() => _dealCompletedHand = game.handNumber);
                  }
                },
              ),
          ],
        );
      },
    );
  }

  /// 좌석이 테이블 중심을 기준으로 어느 변에 있는지에 따라 글자를 돌립니다.
  double _seatRotation(Offset normalizedCenter) {
    final direction = normalizedCenter - const Offset(.5, .5);
    if (direction.dy.abs() >= direction.dx.abs() * .9) {
      return direction.dy < 0 ? math.pi : 0;
    }
    return direction.dx < 0 ? math.pi / 2 : -math.pi / 2;
  }

  Offset _actionSource({
    required String uid,
    required List<Offset> centers,
    required Size boardSize,
    required Offset tableCenter,
    required double scale,
  }) {
    final layoutPlayer = widget.playerLayout.players
        .where((player) => player.uid == uid)
        .firstOrNull;
    final seatIndex = layoutPlayer?.seatIndex;
    if (seatIndex == null || seatIndex < 0 || seatIndex >= centers.length) {
      return tableCenter;
    }
    final center = Offset(
      centers[seatIndex].dx * boardSize.width,
      centers[seatIndex].dy * boardSize.height,
    );
    final direction = tableCenter - center;
    if (direction.distanceSquared == 0) return center;
    return center + direction / direction.distance * (72 * scale);
  }
}

class _TableActionEvent {
  const _TableActionEvent({
    required this.key,
    required this.uid,
    required this.kind,
    required this.amount,
  });

  final String key;
  final String uid;
  final String kind;
  final int amount;
}

class _TableCenter extends StatelessWidget {
  const _TableCenter({
    required this.game,
    required this.result,
    required this.scale,
  });
  final HoldemGameState game;
  final HoldemHandResultModel? result;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final winning = _winningCardIds(result);
    final block = result == null
        ? _PotBlock(game: game, scale: scale)
        : _ResultBlock(game: game, result: result!, scale: scale);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RotatedBox(quarterTurns: 2, child: block),
        SizedBox(height: 26 * scale),
        TweenAnimationBuilder<double>(
          tween: Tween(
            begin: 128 * scale,
            end: result?.reason == 'showdown' ? 142 * scale : 128 * scale,
          ),
          duration: const Duration(milliseconds: 580),
          curve: Curves.easeOutBack,
          builder: (_, cardWidth, _) => _CommunityCards(
            handNumber: game.handNumber,
            phase: game.phase,
            cards: game.communityCards,
            width: cardWidth,
            gap: 10 * scale,
            winning: winning,
          ),
        ),
        SizedBox(height: 26 * scale),
        block,
      ],
    );
  }
}

/// 새로 공개된 카드만 뒤집습니다. 최초 snapshot은 복원으로 보고 조용히 표시합니다.
class _CommunityCards extends StatefulWidget {
  const _CommunityCards({
    required this.handNumber,
    required this.phase,
    required this.cards,
    required this.width,
    required this.gap,
    required this.winning,
  });

  final int handNumber;
  final String phase;
  final List<HoldemCardModel> cards;
  final double width;
  final double gap;
  final Set<String>? winning;

  @override
  State<_CommunityCards> createState() => _CommunityCardsState();
}

class _CommunityCardsState extends State<_CommunityCards>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flip = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    value: 1,
  )..addListener(_playLanding);
  final ProgressSoundCue _cue = ProgressSoundCue();
  late int _revealedCount = widget.cards.length;

  void _playLanding() {
    if (!mounted) return;
    // 라이어스 포커의 첫 카드 뒤집기 종료(.16 + .56)에 맞춰 묶음당 1회.
    _cue.maybePlay(
      context,
      HoldemSounds.cardTable,
      value: _flip.value,
      threshold: .72,
    );
  }

  @override
  void initState() {
    super.initState();
    _cue.markPlayed();
  }

  @override
  void didUpdateWidget(covariant _CommunityCards oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.handNumber != widget.handNumber ||
        widget.cards.length < oldWidget.cards.length) {
      _cue.markPlayed();
      _revealedCount = widget.cards.length;
      _flip.value = 1;
    } else if (widget.cards.length > oldWidget.cards.length) {
      _revealedCount = oldWidget.cards.length;
      _cue.reset();
      _flip.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _flip.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    key: ValueKey('board-${widget.handNumber}-${widget.phase}'),
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 520),
    curve: Curves.easeOutCubic,
    builder: (_, reveal, child) => Opacity(
      opacity: .01 + .99 * reveal,
      alwaysIncludeSemantics: true,
      child: Transform.scale(scale: .97 + .03 * reveal, child: child),
    ),
    child: AnimatedBuilder(
      animation: _flip,
      builder: (_, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < 5; index++) ...[
            if (index > 0) SizedBox(width: widget.gap),
            if (index < widget.cards.length)
              _card(index)
            else
              HoldemCardSlot(width: widget.width),
          ],
        ],
      ),
    ),
  );

  Widget _card(int index) {
    final start = .16 + (index - _revealedCount) * .055;
    final end = math.min(.92, start + .56);
    final progress = index < _revealedCount
        ? 1.0
        : Curves.easeInOutCubic.transform(
            ((_flip.value - start) / (end - start)).clamp(0.0, 1.0),
          );
    final lift = math.sin(progress * math.pi);
    final front = progress >= .5;
    return Transform.translate(
      offset: Offset(
        0,
        -widget.width * HoldemCardView.aspectRatio * .09 * lift,
      ),
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, .001)
          ..rotateY(math.pi * (front ? 1 - progress : progress)),
        child: HoldemCardView(
          card: widget.cards[index],
          width: widget.width,
          faceDown: !front,
          emphasis: _emphasis(widget.cards[index], widget.winning),
        ),
      ),
    );
  }
}

/// 쇼다운 승자의 최종 5장에 든 카드 id입니다. 쇼다운이 아니면 null입니다.
Set<String>? _winningCardIds(HoldemHandResultModel? result) {
  if (result == null || result.reason != 'showdown') return null;
  final ids = <String>{
    for (final uid in result.winnerUids)
      for (final card in result.bestCards[uid] ?? const <HoldemCardModel>[])
        card.id,
  };
  return ids.isEmpty ? null : ids;
}

HoldemCardEmphasis _emphasis(HoldemCardModel card, Set<String>? winning) {
  if (winning == null) return HoldemCardEmphasis.none;
  return winning.contains(card.id)
      ? HoldemCardEmphasis.win
      : HoldemCardEmphasis.lose;
}

class _PotBlock extends StatelessWidget {
  const _PotBlock({required this.game, required this.scale});
  final HoldemGameState game;
  final double scale;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 420 * scale,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HoldemChip(size: 22 * scale),
            SizedBox(width: 10 * scale),
            Text(
              'POT ${holdemChips(game.potTotal)}',
              style: HoldemFonts.numbers(size: 40 * scale),
            ),
          ],
        ),
        SizedBox(height: 4 * scale),
        Text(
          HoldemCopy.phase(game.phase),
          style: HoldemFonts.text(
            size: 13 * scale,
            weight: FontWeight.w700,
            color: HoldemColors.muted,
            letterSpacing: 3 * scale,
          ),
        ),
      ],
    ),
  );
}

class _ResultBlock extends StatelessWidget {
  const _ResultBlock({
    required this.game,
    required this.result,
    required this.scale,
  });
  final HoldemGameState game;
  final HoldemHandResultModel result;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final names = result.winnerUids
        .map((uid) => game.players[uid]?.nickname ?? '플레이어')
        .join(', ');
    final total = result.winnerUids.fold<int>(
      0,
      (sum, uid) => sum + (result.awards[uid] ?? 0),
    );
    final split = result.winnerUids.length > 1;
    return SizedBox(
      width: 520 * scale,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (result.reason == 'fold') ...[
            HoldemPill(label: '상대가 모두 폴드했어요', fontSize: 14 * scale),
            SizedBox(height: 8 * scale),
          ],
          // 이긴 사람 이름이 길거나 여럿이어도 자르지 않고 줄 전체를 줄입니다.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  split ? '$names 나눠 가짐' : '$names 승리',
                  maxLines: 1,
                  style: HoldemFonts.text(
                    size: 36 * scale,
                    weight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                SizedBox(width: 12 * scale),
                Text(
                  '+${holdemChips(total)}',
                  style: HoldemFonts.numbers(size: 32 * scale),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Seat extends StatelessWidget {
  const _Seat({
    required this.game,
    required this.uid,
    required this.result,
    required this.streetAction,
    required this.stackStart,
    required this.stackAnimation,
    required this.showCards,
  });
  final HoldemGameState game;
  final String uid;
  final HoldemHandResultModel? result;
  final String? streetAction;
  final int? stackStart;
  final Animation<double> stackAnimation;
  final bool showCards;

  @override
  Widget build(BuildContext context) {
    final player = game.players[uid];
    if (player == null) return const SizedBox.shrink();
    final turn = game.turnUid == uid && result == null;
    final winner = result?.winnerUids.contains(uid) ?? false;
    final highlighted = turn || winner;
    final folded = player.handStatus == 'folded';
    final eliminated = player.status == 'eliminated';
    final revealed = result?.revealedHands[uid];
    final showLargeHand =
        result?.reason == 'showdown' &&
        revealed != null &&
        revealed.length == 2;
    final winningCards = winner
        ? {
            for (final card
                in result?.bestCards[uid] ?? const <HoldemCardModel>[])
              card.id,
          }
        : null;
    final tag = game.smallBlindUid == uid
        ? 'SB'
        : game.bigBlindUid == uid
        ? 'BB'
        : null;
    final foreground = highlighted ? HoldemColors.ink : HoldemColors.ivory;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // 딜러 표시와 베팅 금액이 좌석 폭보다 길면 넘치지 않게 줄입니다.
        SizedBox(
          height: 40,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (game.dealerUid == uid) ...[
                  const _DealerPuck(),
                  const SizedBox(width: 10),
                ],
                ..._statusRow(player, turn),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Opacity(
          opacity: (folded || eliminated) && !winner ? .45 : 1,
          child: Container(
            width: 240,
            height: 100,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: highlighted ? HoldemColors.ivory : HoldemColors.panel(),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: HoldemColors.line()),
              boxShadow: highlighted
                  ? [
                      const BoxShadow(
                        color: HoldemColors.accent,
                        spreadRadius: 3,
                      ),
                      BoxShadow(
                        color: HoldemColors.ivory.withValues(alpha: .55),
                        blurRadius: 30,
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Row(
                  children: [
                    const SizedBox(width: 42),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 닉네임(최대 8자)은 자르지 않고 칸에 맞춰 줄입니다.
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              player.nickname,
                              maxLines: 1,
                              style: HoldemFonts.text(
                                size: 17,
                                weight: FontWeight.w700,
                                color: foreground,
                                height: 1.3,
                              ),
                            ),
                          ),
                          _AnimatedStackAmount(
                            start: stackStart,
                            end: player.stack,
                            animation: stackAnimation,
                            color: foreground,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: revealed != null ? 84 : 66,
                      height: 64,
                      child: showCards && !showLargeHand
                          ? _SeatCards(
                              revealed: revealed,
                              folded: folded || eliminated,
                              winning: winningCards,
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
                Positioned(
                  key: Key('holdem-profile-$uid'),
                  left: -42,
                  top: 9,
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x99000000),
                          blurRadius: 18,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: MosiFace(
                      characterId: player.characterId,
                      size: 82,
                      ring: true,
                    ),
                  ),
                ),
                if (showLargeHand)
                  Positioned(
                    key: Key('holdem-showdown-hand-$uid'),
                    left: -11,
                    top: -105,
                    child: TweenAnimationBuilder<double>(
                      key: ValueKey('showdown-${game.handNumber}-$uid'),
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 540),
                      curve: Curves.easeOutBack,
                      builder: (_, progress, child) => Opacity(
                        opacity: progress.clamp(0.0, 1.0),
                        alwaysIncludeSemantics: true,
                        child: Transform.scale(
                          scale: .72 + .28 * progress,
                          child: child,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final (index, card) in revealed.indexed) ...[
                            if (index > 0) const SizedBox(width: 10),
                            HoldemCardView(
                              key: Key('holdem-showdown-card-$uid-$index'),
                              card: card,
                              width: 126,
                              emphasis: winningCards == null
                                  ? HoldemCardEmphasis.none
                                  : winningCards.contains(card.id)
                                  ? HoldemCardEmphasis.win
                                  : HoldemCardEmphasis.lose,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                if (tag != null && result == null)
                  Positioned(right: -4, top: -11, child: _SeatTag(tag)),
                if (winner)
                  const Positioned(right: -32, top: -22, child: _WinStamp()),
                if (turn)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 9,
                    child: _TurnBar(expiresAt: game.turnDeadlineAt),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _statusRow(HoldemPlayerModel player, bool turn) {
    if (result != null) return const [];
    if (player.status == 'eliminated') {
      return [_note('탈락')];
    }
    if (player.handStatus == 'folded') return [_note('폴드')];
    if (turn) {
      return [
        GameTurnCountdownFace(
          expiresAt: game.turnDeadlineAt,
          builder: (_, remaining) =>
              _note('고민 중 · ${remaining?.inSeconds ?? 0}초', strong: true),
        ),
      ];
    }
    final bet = player.streetContribution;
    if (bet > 0) {
      final label = player.handStatus == 'allIn'
          ? '올인'
          : HoldemCopy.action(streetAction ?? '');
      return [_BetPill(label: label, amount: bet)];
    }
    if (player.handStatus == 'allIn') return [_note('올인', strong: true)];
    if (streetAction == 'check') return [_note('체크')];
    return const [];
  }

  Widget _note(String text, {bool strong = false}) => Text(
    text,
    style: HoldemFonts.text(
      size: 14,
      weight: FontWeight.w700,
      color: strong ? HoldemColors.ivory : HoldemColors.muted,
    ),
  );
}

class _AnimatedStackAmount extends StatelessWidget {
  const _AnimatedStackAmount({
    required this.start,
    required this.end,
    required this.animation,
    required this.color,
  });

  final int? start;
  final int end;
  final Animation<double> animation;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final initial = start;
    if (initial == null || initial == end) {
      return HoldemChipAmount(amount: end, color: color);
    }
    return AnimatedBuilder(
      animation: animation,
      builder: (_, _) {
        final raw = ((animation.value - .42) / .46).clamp(0.0, 1.0);
        final progress = Curves.easeOutCubic.transform(raw);
        final amount = (initial + (end - initial) * progress).round();
        return Semantics(
          label: '보유 칩 ${holdemChips(amount)}',
          excludeSemantics: true,
          child: HoldemChipAmount(amount: amount, color: color),
        );
      },
    );
  }
}

class _SeatCards extends StatelessWidget {
  const _SeatCards({
    required this.revealed,
    required this.folded,
    required this.winning,
  });
  final List<HoldemCardModel>? revealed;
  final bool folded;
  final Set<String>? winning;

  @override
  Widget build(BuildContext context) {
    final cards = revealed;
    if (cards != null && cards.isNotEmpty) {
      return Row(
        children: [
          for (final (index, card) in cards.indexed) ...[
            if (index > 0) const SizedBox(width: 4),
            HoldemCardView(
              card: card,
              width: 40,
              layout: HoldemCardLayout.mini,
              emphasis: winning == null
                  ? HoldemCardEmphasis.none
                  : winning!.contains(card.id)
                  ? HoldemCardEmphasis.win
                  : HoldemCardEmphasis.lose,
            ),
          ],
        ],
      );
    }
    if (folded) {
      return Center(
        child: CustomPaint(
          size: const Size(40, 58),
          painter: HoldemDashedRectPainter(
            color: HoldemColors.line(.5),
            radius: 5,
          ),
        ),
      );
    }
    return Stack(
      children: [
        Positioned(
          left: 2,
          top: 3,
          child: Transform.rotate(
            angle: -8 * math.pi / 180,
            child: const HoldemCardView(width: 40, faceDown: true),
          ),
        ),
        Positioned(
          left: 24,
          top: 3,
          child: Transform.rotate(
            angle: 7 * math.pi / 180,
            child: const HoldemCardView(width: 40, faceDown: true),
          ),
        ),
      ],
    );
  }
}

class _BetPill extends StatelessWidget {
  const _BetPill({required this.label, required this.amount});
  final String label;
  final int amount;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(7, 5, 12, 5),
    decoration: BoxDecoration(
      color: HoldemColors.panel(.72),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const HoldemChip(),
        const SizedBox(width: 8),
        if (label.isNotEmpty) ...[
          Text(
            label,
            style: HoldemFonts.text(
              size: 13,
              weight: FontWeight.w700,
              color: HoldemColors.muted,
            ),
          ),
          const SizedBox(width: 8),
        ],
        Text(holdemChips(amount), style: HoldemFonts.numbers(size: 24)),
      ],
    ),
  );
}

class _DealerPuck extends StatelessWidget {
  const _DealerPuck();

  @override
  Widget build(BuildContext context) => Semantics(
    label: '딜러',
    child: Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: Alignment(0, -.36),
          radius: .7,
          colors: [Colors.white, Color(0xFFF2F6F3), Color(0xFFD3DCD6)],
          stops: [0, .55, 1],
        ),
        boxShadow: [
          BoxShadow(color: HoldemColors.puckEdge, offset: Offset(0, 4)),
          BoxShadow(
            color: Color(0x73000000),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Text(
        'D',
        style: HoldemFonts.title(size: 17, color: HoldemColors.cardBlack),
      ),
    ),
  );
}

class _SeatTag extends StatelessWidget {
  const _SeatTag(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
    decoration: BoxDecoration(
      color: HoldemColors.accent,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: HoldemColors.line(.35)),
    ),
    child: Text(
      label,
      style: HoldemFonts.text(
        size: 11,
        weight: FontWeight.w900,
        letterSpacing: 1,
      ),
    ),
  );
}

class _WinStamp extends StatelessWidget {
  const _WinStamp();

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: 12 * math.pi / 180,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: HoldemColors.ivory,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: HoldemColors.accent, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        'WIN',
        style: HoldemFonts.title(size: 22, color: HoldemColors.accent),
      ),
    ),
  );
}

class _TurnBar extends StatelessWidget {
  const _TurnBar({required this.expiresAt});
  final int? expiresAt;

  @override
  Widget build(BuildContext context) => GameTurnCountdown(
    expiresAt: expiresAt,
    builder: (_, remaining) {
      final fraction = remaining == null
          ? 0.0
          : (remaining.inMilliseconds / _actionWindow.inMilliseconds).clamp(
              0.0,
              1.0,
            );
      return Container(
        height: 4,
        decoration: BoxDecoration(
          color: HoldemColors.ink.withValues(alpha: .15),
          borderRadius: BorderRadius.circular(999),
        ),
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: fraction,
          child: Container(
            decoration: BoxDecoration(
              color: HoldemColors.accent,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      );
    },
  );
}
