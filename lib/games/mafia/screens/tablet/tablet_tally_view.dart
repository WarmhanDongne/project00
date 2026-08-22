import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:project00/core/assets/game_image.dart';
import 'package:project00/core/sound/sound_effects.dart';
import 'package:project00/games/mafia/animations/ballot_animations.dart';
import 'package:project00/games/mafia/models/mafia_player.dart';
import 'package:project00/games/mafia/models/mafia_state_models.dart';
import 'package:project00/games/mafia/screens/tablet/tablet_game_layout.dart';
import 'package:project00/games/mafia/sound/mafia_sounds.dart';
import 'package:project00/games/mafia/widgets/phone/player_select_grid.dart';
import 'package:project00/gen/assets.gen.dart';

//=======================태블릿 개표 화면==============================
/// 표를 세는 화면입니다(시안 `tablet-p7 개표`).
///
/// 확정 흐름(2026-08): 개표는 **투표함이 투표 시간의 자리에서 개표 자리로
/// 이동한 뒤**, 그 함에서 투표지가 한 장씩 나와 각 사람 칸으로 날아가며
/// 득표수가 올라갑니다. 그래서 이 화면은 정지 화면이 아니라 연출입니다.
///
///   투표함 이동(0.8초) → 표가 한 장씩 나와 착지(장마다 0.14초 간격)
///
/// 시안은 흰 개표판과 투표함, 그리고 아래쪽 프로필 네 칸만 그려져 있고 문구가
/// 없습니다. 득표 숫자를 어떻게 보여 줄지는 시안에 없어, **표를 받은 사람만
/// 왼쪽부터 늘어놓습니다.**
///
/// 득표수는 숫자로 적지 않습니다. **그 사람의 프로필 블럭이 받은 표만큼 위로
/// 쌓입니다**(확정 2026-08). 표가 한 장 날아와 닿으면 블럭이 한 칸 올라가므로,
/// 숫자를 읽지 않아도 누가 앞서는지 한눈에 보입니다.
///
/// 비밀 투표라 **누가 찍었는지는 절대 보여 주지 않습니다.** 서버도 보내지 않습니다.
class MafiaTabletTallyView extends StatefulWidget {
  const MafiaTabletTallyView({
    super.key,
    required this.result,
    required this.players,
  });

  final MafiaVoteResult? result;
  final Map<String, MafiaPlayer> players;

  /// 시안 개표판 테두리 색입니다.
  static const Color boardBorder = Color(0xFFAF7F3F);

  @override
  State<MafiaTabletTallyView> createState() => _MafiaTabletTallyViewState();
}

class _MafiaTabletTallyViewState extends State<MafiaTabletTallyView>
    with TickerProviderStateMixin {
  //=======================시안 기준 좌표==============================
  static const Rect _board = Rect.fromLTWH(37, 50, 822, 748);

  //=======================프로필 블럭 (반응형)==============================
  // 확정(2026-08): 표를 받은 사람이 적으면 프로필을 **크게** 보여 주고, 사람이
  // 늘거나 탑이 높아질수록 부드럽게 줄어들며 자리를 나눠 갖습니다.
  // 시안(136 × 136 · 160 간격 · top 595)은 네 명이 한 표씩 받았을 때의 모습입니다.

  /// 블럭이 놓이는 띠입니다. 개표판(37~859) 안쪽으로 여백을 둡니다.
  static const double _slotsLeft = 77;
  static const double _slotsRight = 819;

  /// 탑이 자랄 수 있는 위쪽 한계입니다(개표판 안쪽).
  static const double _slotsTop = 96;

  /// 블럭 묶음의 아래 끝입니다. 탑은 여기서 위로 자랍니다.
  static const double _slotsBottom = 777;

  /// 칸 사이 여백과 프로필 한 변의 최대 크기입니다.
  static const double _slotGap = 26;
  static const double _slotMaxSize = 258;

  /// 프로필 아래 닉네임이 차지하는 높이입니다(프로필 크기에 비례).
  static const double _nicknameRatio = 36 / 136;
  static const double _slotLabelRatio = _nicknameRatio;

  /// 쌓인 블럭 사이의 틈입니다(블럭 한 변에 대한 비율).
  ///
  /// 딱 붙여 놓으면 몇 장 쌓였는지 세기 어렵습니다. 아주 조금 띄웁니다.
  static const double _blockGapRatio = 0.06;

  /// 블럭 한 칸이 올라앉는 데 걸리는 시간입니다.
  static const Duration _blockPop = Duration(milliseconds: 260);

  /// 칸 수·탑 높이가 바뀔 때 새 배치로 옮겨가는 시간입니다.
  static const Duration _layoutShift = Duration(milliseconds: 420);

  //=======================날아오는 표==============================
  /// 표 한 장의 폭입니다(프로필 크기에 비례). 날아오는 동안만 보입니다.
  static const double _paperWidthRatio = 0.5;

  /// 표 종이의 가로:세로 비율입니다(투표 중 날아가는 종이와 같은 46 : 34).
  static const double _paperAspectRatio = 34 / 46;

  //=======================연출 시간==============================
  /// 투표함이 투표 시간 자리에서 개표 자리로 이동하는 시간입니다.
  static const Duration _boxTravel = Duration(milliseconds: 800);

  /// 표가 한 장 날아가는 시간과 장 사이 간격입니다.
  static const Duration _ballotFlight = Duration(milliseconds: 420);
  static const Duration _ballotGap = Duration(milliseconds: 140);

  late final AnimationController _controller;

  /// 날아갈 표의 순서입니다. 값은 '몇 번째 사람 칸으로 갈 표인지'입니다.
  late final List<int> _ballotOrder;

  /// 표를 받은 사람 목록입니다(득표수 내림차순).
  late final List<({String uid, int count})> _ranked;

  /// 지금까지 착지 소리를 낸 표 수입니다.
  int _landedSoundCount = 0;

  /// 배치가 바뀔 때 옛 배치에서 새 배치로 옮겨가는 연출입니다.
  late final AnimationController _layout;

  /// 배치 계산에 쓰는 칸 수와 가장 높은 탑입니다.
  ///
  /// 소수를 허용해 블럭 크기가 부드럽게 변합니다.
  double _fromCount = 1;
  int _toCount = 1;
  double _fromTallest = 1;
  int _toTallest = 1;

  @override
  void initState() {
    super.initState();
    _ranked = widget.result?.ranked ?? const <({String uid, int count})>[];
    // 여러 사람이 표를 받았으면 번갈아 한 장씩 세어, 마지막에 승자가
    // 드러나도록 합니다(한 사람씩 몰아 세면 결과가 미리 보입니다).
    _ballotOrder = _buildRoundRobinOrder();
    final total =
        _boxTravel +
        _ballotGap * (_ballotOrder.isEmpty ? 0 : _ballotOrder.length - 1) +
        _ballotFlight;
    _layout = AnimationController(
      vsync: this,
      duration: _layoutShift,
      value: 1,
    );
    _controller = AnimationController(vsync: this, duration: total)
      ..addListener(_handleTick);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.forward();
    });
  }

  List<int> _buildRoundRobinOrder() {
    final counts = [for (final entry in _ranked) entry.count];
    final order = <int>[];
    var remaining = counts.fold<int>(0, (sum, count) => sum + count);
    while (remaining > 0) {
      for (var index = 0; index < counts.length; index += 1) {
        if (counts[index] <= 0) continue;
        counts[index] -= 1;
        remaining -= 1;
        order.add(index);
      }
    }
    return order;
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleTick)
      ..dispose();
    _layout.dispose();
    super.dispose();
  }

  /// 매 프레임 하는 일입니다: 착지 소리, 그리고 배치가 바뀌었는지 확인.
  void _handleTick() {
    if (!mounted) return;
    _playLandingSounds();
    _syncLayout();
  }

  /// 칸이 늘거나 탑이 높아지면 새 배치로 부드럽게 옮겨갑니다.
  void _syncLayout() {
    final count = _visibleCount;
    final tallest = _tallestStack;
    if (count == _toCount && tallest == _toTallest) return;
    // 지금 화면에 보이는 값(소수)에서 새 값으로 이어 갑니다.
    _fromCount = _layoutCount;
    _fromTallest = _layoutTallest;
    _toCount = count;
    _toTallest = tallest;
    _layout.forward(from: 0);
  }

  /// 표가 한 장이라도 착지한 사람 수입니다.
  int get _visibleCount {
    var count = 0;
    for (var index = 0; index < _ranked.length; index += 1) {
      if (_landedCountOf(index) > 0) count += 1;
    }
    return count;
  }

  /// 지금 가장 높이 쌓인 탑의 블럭 수입니다.
  int get _tallestStack {
    var tallest = 1;
    for (var index = 0; index < _ranked.length; index += 1) {
      final landed = _landedCountOf(index);
      if (landed > tallest) tallest = landed;
    }
    return tallest;
  }

  double get _layoutEased => Curves.easeOutCubic.transform(_layout.value);

  /// 배치에 쓰는 칸 수입니다(옮겨가는 중에는 소수입니다).
  double get _layoutCount =>
      _fromCount + (_toCount - _fromCount) * _layoutEased;

  /// 배치에 쓰는 탑 높이입니다(옮겨가는 중에는 소수입니다).
  double get _layoutTallest =>
      _fromTallest + (_toTallest - _fromTallest) * _layoutEased;

  /// 표가 개표판에 닿는 순간마다 소리를 냅니다.
  void _playLandingSounds() {
    if (!mounted) return;
    var landed = 0;
    for (var index = 0; index < _ballotOrder.length; index += 1) {
      if (_ballotProgress(index) >= 1) landed += 1;
    }
    while (_landedSoundCount < landed) {
      _landedSoundCount += 1;
      SoundEffects.play(context, MafiaSounds.vote);
    }
  }

  //=======================진행도==============================
  double get _elapsedMs =>
      _controller.value * _controller.duration!.inMilliseconds;

  /// 투표함 이동 진행도입니다.
  double get _boxProgress =>
      (_elapsedMs / _boxTravel.inMilliseconds).clamp(0.0, 1.0);

  /// [index]번째 표가 착지하는 시각입니다(연출 시작 기준 밀리초).
  double _ballotLandMs(int index) =>
      (_boxTravel.inMilliseconds +
              _ballotGap.inMilliseconds * index +
              _ballotFlight.inMilliseconds)
          .toDouble();

  /// [index]번째 표의 진행도입니다(0 = 함 안, 1 = 착지).
  double _ballotProgress(int index) {
    final startMs =
        _boxTravel.inMilliseconds + _ballotGap.inMilliseconds * index;
    return ((_elapsedMs - startMs) / _ballotFlight.inMilliseconds).clamp(
      0.0,
      1.0,
    );
  }

  /// [rankIndex]번째 사람이 지금까지 받은(착지한) 표 수입니다.
  int _landedCountOf(int rankIndex) {
    var count = 0;
    for (var index = 0; index < _ballotOrder.length; index += 1) {
      if (_ballotOrder[index] == rankIndex && _ballotProgress(index) >= 1) {
        count += 1;
      }
    }
    return count;
  }

  /// [rankIndex]번째 사람의 [blockIndex]번째 블럭이 올라앉은 정도입니다.
  ///
  /// 표가 닿는 순간 0에서 시작해 [_blockPop] 동안 1이 됩니다. 그래서 블럭이
  /// 툭 나타나지 않고 살짝 눌리며 자리를 잡습니다.
  double _blockPopProgress(int rankIndex, int blockIndex) {
    var seen = 0;
    for (var index = 0; index < _ballotOrder.length; index += 1) {
      if (_ballotOrder[index] != rankIndex) continue;
      if (seen == blockIndex) {
        final since = _elapsedMs - _ballotLandMs(index);
        return (since / _blockPop.inMilliseconds).clamp(0.0, 1.0);
      }
      seen += 1;
    }
    return 1;
  }

  //=======================배치 계산==============================
  /// 지금 배치에서 프로필 블럭 한 변의 크기입니다.
  ///
  /// 가로(칸 수)와 세로(가장 높은 탑) 중 **더 빡빡한 쪽**을 따릅니다. 세로를
  /// 보지 않으면 표를 많이 받은 사람의 탑이 개표판을 뚫고 올라갑니다.
  double get _slotSize {
    final count = _layoutCount.clamp(1.0, 12.0);
    final band = _slotsRight - _slotsLeft;
    final byWidth = (band - _slotGap * (count - 1)) / count;

    final tallest = _layoutTallest.clamp(1.0, 12.0);
    final column = _slotsBottom - _slotsTop;
    final byHeight =
        column / (tallest + _blockGapRatio * (tallest - 1) + _slotLabelRatio);

    return math.min(byWidth, byHeight).clamp(0.0, _slotMaxSize);
  }

  /// 블럭 사이의 틈입니다.
  double get _blockGap => _slotSize * _blockGapRatio;

  /// [rankIndex]번째 사람 탑의 가로 가운데입니다.
  double _slotCenterX(int rankIndex) {
    final size = _slotSize;
    final count = _layoutCount.clamp(1.0, 12.0);
    final step = size + _slotGap;
    // 묶음 전체 폭을 띠 가운데에 맞춥니다.
    final groupWidth = step * count - _slotGap;
    final bandCenter = (_slotsLeft + _slotsRight) / 2;
    final first = bandCenter - groupWidth / 2;
    return first + step * rankIndex + size / 2;
  }

  /// 탑의 아래 끝입니다. 닉네임 한 줄을 아래에 남깁니다.
  double get _towerBottom => _slotsBottom - _slotSize * _slotLabelRatio;

  /// [rankIndex]번째 사람의 [blockIndex]번째 블럭 자리입니다(0 = 맨 아래).
  Rect _blockRect(int rankIndex, int blockIndex) {
    final size = _slotSize;
    final top = _towerBottom - size * (blockIndex + 1) - _blockGap * blockIndex;
    return Rect.fromLTWH(_slotCenterX(rankIndex) - size / 2, top, size, size);
  }

  /// 닉네임 한 줄이 놓이는 자리입니다.
  Rect _nicknameRect(int rankIndex) {
    final size = _slotSize;
    final height = size * _slotLabelRatio;
    return Rect.fromLTWH(
      _slotCenterX(rankIndex) - size / 2,
      _towerBottom,
      size,
      height,
    );
  }

  /// 날아오는 표 한 장의 크기입니다.
  Size get _paperSize {
    final width = _slotSize * _paperWidthRatio;
    return Size(width, width * _paperAspectRatio);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_controller, _layout]),
      builder: (context, _) {
        final boxProgress = Curves.easeInOut.transform(_boxProgress);
        final boxRect = Rect.lerp(
          MafiaBallotBoxRects.voting,
          MafiaBallotBoxRects.tally,
          boxProgress,
        )!;

        return Stack(
          fit: StackFit.expand,
          children: [
            // 개표판은 투표함이 도착하는 동안 서서히 나타납니다.
            MafiaTabletBox(
              rect: _board,
              child: Opacity(
                opacity: boxProgress,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: MafiaTabletTallyView.boardBorder),
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ),
            // 투표 시간의 그 투표함이 그대로 개표 자리로 이동합니다.
            MafiaTabletBox(
              rect: boxRect,
              child: Assets.games.mafia.images.other.voteBox.game.image(
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
            // 표를 받은 사람의 탑입니다. 표가 닿을 때마다 한 칸 올라갑니다.
            for (var rank = 0; rank < _ranked.length; rank += 1)
              if (_landedCountOf(rank) > 0) ..._buildTower(rank),
            // 함에서 나와 각 탑으로 날아가는 표들입니다.
            ..._buildFlyingBallots(),
          ],
        );
      },
    );
  }

  /// 프로필 블럭 탑과 그 아래 닉네임입니다.
  List<Widget> _buildTower(int rankIndex) {
    final entry = _ranked[rankIndex];
    final player = widget.players[entry.uid];
    final landed = _landedCountOf(rankIndex);
    final size = _slotSize;

    return [
      // 아래 블럭부터 그립니다. 위 블럭이 그림자를 덮어 탑처럼 보입니다.
      for (var block = 0; block < landed; block += 1)
        MafiaTabletBox(
          rect: _blockRect(rankIndex, block),
          child: _buildBlock(player, size, _blockPopProgress(rankIndex, block)),
        ),
      MafiaTabletBox(
        rect: _nicknameRect(rankIndex),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            player?.nickname ?? '플레이어',
            maxLines: 1,
            style: const TextStyle(
              color: Color(0xFF444444),
              fontSize: 26,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    ];
  }

  /// 탑을 이루는 프로필 블럭 한 칸입니다.
  Widget _buildBlock(MafiaPlayer? player, double size, double pop) {
    // 표가 닿는 순간 위에서 살짝 내려앉습니다.
    final eased = Curves.easeOutBack.transform(pop.clamp(0.0, 1.0));
    final drop = (1 - Curves.easeOutCubic.transform(pop)) * size * 0.35;

    return Transform.translate(
      offset: Offset(0, -drop),
      child: Opacity(
        opacity: pop.clamp(0.0, 1.0),
        child: Transform.scale(
          // 0.94 → 1로 눌리며 자리를 잡습니다.
          scale: 0.94 + 0.06 * eased.clamp(0.0, 1.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // 화면 배율이 달라도 테두리·모서리가 같은 비율로 보입니다.
              final side = constraints.biggest.shortestSide;
              return DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(side * 10 / 136),
                  border: Border.all(
                    color: Colors.white,
                    width: side * 3 / 136,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0x33000000),
                      blurRadius: side * 8 / 136,
                      offset: Offset(0, side * 3 / 136),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(side * 10 / 136),
                  child: SizedBox.expand(
                    child: MafiaProfileImage(
                      url: player?.profileImageUrl ?? '',
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _buildFlyingBallots() {
    final flying = <Widget>[];
    // 같은 사람에게 가는 표가 몇 번째인지 세어, 그 표가 올려놓을 블럭 자리로
    // 정확히 내려앉게 합니다. 착지점과 블럭 자리가 어긋나면 표가 순간이동해
    // 보입니다.
    final placed = List<int>.filled(_ranked.length, 0);
    for (var index = 0; index < _ballotOrder.length; index += 1) {
      final rank = _ballotOrder[index];
      final blockIndex = placed[rank];
      placed[rank] += 1;
      final progress = _ballotProgress(index);
      if (progress <= 0 || progress >= 1) continue;
      flying.add(
        _FlyingBallot(
          from: MafiaBallotBoxRects.tallyCenter,
          to: _blockRect(rank, blockIndex).center,
          progress: progress,
          size: _paperSize,
        ),
      );
    }
    return flying;
  }
}

/// 투표함에서 나와 사람 탑으로 날아가는 표 한 장입니다.
///
/// 표는 블럭 자리에 닿는 순간 사라지고, 그 자리에 프로필 블럭이 올라앉습니다.
class _FlyingBallot extends StatelessWidget {
  const _FlyingBallot({
    required this.from,
    required this.to,
    required this.progress,
    required this.size,
  });

  final Offset from;
  final Offset to;
  final double progress;

  /// 종이 크기입니다(설계 좌표).
  final Size size;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final projection = MafiaTabletProjection.of(constraints);
        final eased = Curves.easeOut.transform(progress);
        final design = Offset.lerp(from, to, eased)!;
        // 함에서 튀어나오듯 살짝 솟았다가 내려앉습니다.
        final lift = -70 * (1 - (2 * eased - 1).abs());
        final position = projection.toScreen(design + Offset(0, lift));
        final width = size.width * projection.scale;
        final height = size.height * projection.scale;

        // [MafiaTabletBox]와 같은 방식입니다 — Positioned는 자기 Stack 안에
        // 있어야 합니다(LayoutBuilder 바로 아래에 두면 부모가 Stack이 아닙니다).
        return Stack(
          children: [
            Positioned(
              left: position.dx - width / 2,
              top: position.dy - height / 2,
              width: width,
              height: height,
              child: IgnorePointer(
                child: MafiaBallotPaper(width: width, height: height),
              ),
            ),
          ],
        );
      },
    );
  }
}
