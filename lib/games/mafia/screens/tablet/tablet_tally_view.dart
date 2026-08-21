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
/// 왼쪽부터 늘어놓고 득표수를 프로필 아래에 적습니다.**
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

  //=======================프로필 칸 (반응형)==============================
  // 확정(2026-08): 표를 받은 사람이 적으면 프로필·닉네임을 **크게** 보여 주고,
  // 표를 받은 사람이 늘어날수록 부드럽게 줄어들며 자리를 나눠 갖습니다.
  // 시안(136 × 136 · 160 간격 · top 595)은 네 명일 때의 모습입니다.

  /// 칸이 놓이는 띠입니다. 개표판(37~859) 안쪽으로 여백을 둡니다.
  static const double _slotsLeft = 77;
  static const double _slotsRight = 819;

  /// 칸 묶음의 아래 끝입니다. 크기가 커지면 위로 자랍니다.
  static const double _slotsBottom = 777;

  /// 칸 사이 여백과 프로필 한 변의 최대 크기입니다.
  static const double _slotGap = 26;
  static const double _slotMaxSize = 258;

  /// 닉네임·득표수가 차지하는 높이입니다(프로필 크기에 비례합니다).
  static const double _slotLabelRatio = 46 / 136;

  /// 칸 수가 바뀔 때 새 배치로 옮겨가는 시간입니다.
  static const Duration _layoutShift = Duration(milliseconds: 420);

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

  /// 칸 수가 바뀔 때 옛 배치에서 새 배치로 옮겨가는 연출입니다.
  late final AnimationController _layout;

  /// 배치 계산에 쓰는 칸 수입니다. 소수를 허용해 크기가 부드럽게 변합니다.
  double _layoutFrom = 1;
  int _layoutTo = 1;

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

  /// 매 프레임 하는 일입니다: 착지 소리, 그리고 칸 수가 늘었는지 확인.
  void _handleTick() {
    if (!mounted) return;
    _playLandingSounds();
    _syncLayoutCount();
  }

  /// 표를 받은 사람이 늘면 새 배치로 부드럽게 옮겨갑니다.
  void _syncLayoutCount() {
    final visible = _visibleCount;
    if (visible == _layoutTo) return;
    // 지금 화면에 보이는 칸 수(소수)에서 새 칸 수로 이어 갑니다.
    _layoutFrom = _layoutCount;
    _layoutTo = visible;
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

  /// 배치에 쓰는 칸 수입니다(옮겨가는 중에는 소수입니다).
  double get _layoutCount {
    final eased = Curves.easeOutCubic.transform(_layout.value);
    return _layoutFrom + (_layoutTo - _layoutFrom) * eased;
  }

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

  /// 지금 배치에서 프로필 한 변의 크기입니다.
  ///
  /// 칸이 적으면 크게, 많아지면 띠 안에 나눠 담기게 줄어듭니다.
  double get _slotSize {
    final count = _layoutCount.clamp(1.0, 12.0);
    final band = _slotsRight - _slotsLeft;
    final size = (band - _slotGap * (count - 1)) / count;
    return size.clamp(0.0, _slotMaxSize);
  }

  /// [rankIndex]번째 사람 칸의 사각형입니다. 묶음은 늘 가운데에 옵니다.
  Rect _slotRect(int rankIndex) {
    final size = _slotSize;
    final count = _layoutCount.clamp(1.0, 12.0);
    final step = size + _slotGap;
    // 묶음 전체 폭을 띠 가운데에 맞춥니다.
    final groupWidth = step * count - _slotGap;
    final bandCenter = (_slotsLeft + _slotsRight) / 2;
    final first = bandCenter - groupWidth / 2;
    final labelHeight = size * _slotLabelRatio;
    return Rect.fromLTWH(
      first + step * rankIndex,
      // 아래를 고정하고 위로 자랍니다(개표판을 넘지 않습니다).
      _slotsBottom - size - labelHeight,
      size,
      size + labelHeight,
    );
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
            // 표를 받은 사람 칸입니다. 첫 표가 착지할 때 함께 나타납니다.
            for (var index = 0; index < _ranked.length; index += 1)
              if (_landedCountOf(index) > 0)
                _buildTallyEntry(index, _landedCountOf(index)),
            // 함에서 나와 각 칸으로 날아가는 표들입니다.
            ..._buildFlyingBallots(),
          ],
        );
      },
    );
  }

  List<Widget> _buildFlyingBallots() {
    final flying = <Widget>[];
    for (var index = 0; index < _ballotOrder.length; index += 1) {
      final progress = _ballotProgress(index);
      if (progress <= 0 || progress >= 1) continue;
      final slot = _slotRect(_ballotOrder[index]);
      flying.add(
        _FlyingBallot(
          from: MafiaBallotBoxRects.tallyCenter,
          to: slot.center,
          progress: progress,
        ),
      );
    }
    return flying;
  }

  Widget _buildTallyEntry(int rankIndex, int landedCount) {
    final entry = _ranked[rankIndex];
    final player = widget.players[entry.uid];

    return MafiaTabletBox(
      rect: _slotRect(rankIndex),
      child: Column(
        children: [
          // 사진과 득표수를 위아래로 나눕니다. 득표수는 남는 공간 안에서만
          // 그려지므로 화면 배율이 어떻게 바뀌어도 칸을 넘치지 않습니다.
          Expanded(
            flex: 136,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox.expand(
                child: MafiaProfileImage(url: player?.profileImageUrl ?? ''),
              ),
            ),
          ),
          // 지금까지 착지한 표 수입니다. 누가 찍었는지는 담지 않습니다.
          Expanded(
            flex: 46,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$landedCount표',
                maxLines: 1,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 투표함에서 나와 사람 칸으로 날아가는 표 한 장입니다.
class _FlyingBallot extends StatelessWidget {
  const _FlyingBallot({
    required this.from,
    required this.to,
    required this.progress,
  });

  final Offset from;
  final Offset to;
  final double progress;

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
        final width = 46 * projection.scale;
        final height = 34 * projection.scale;

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
