import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:project00/core/sound/sound_effects.dart';
import 'package:project00/games/mafia/screens/tablet/tablet_game_layout.dart';
import 'package:project00/games/mafia/sound/mafia_sounds.dart';
import 'package:project00/games/shared/player_layouts/player_slot_positions.dart';

//=======================투표지 연출 공용==============================
// 투표 중(좌석 → 투표함)과 개표(투표함 → 개표판) 두 연출이 같은 투표지
// 그림과 같은 좌표 규약을 씁니다. 좌표는 모두 **시안(1194 × 834) 기준**이고,
// 화면에 놓을 때만 [MafiaTabletDesign]의 배율·여백으로 변환합니다.

/// 투표함의 자리입니다. 투표 중에는 화면 가운데, 개표에는 오른쪽 아래입니다.
///
/// 확정(2026-08): 개표는 **투표함이 그 자리에서 이동해** 시작합니다. 그래서
/// 두 좌표를 한곳에 두고 두 화면이 함께 참조합니다.
abstract final class MafiaBallotBoxRects {
  /// 투표 시간의 투표함입니다.
  ///
  /// 확정(2026-08): 토론 삽화가 **크기를 유지한 채** 그대로 있고, 그 삽화의
  /// 가운데에서 투표함이 떠오릅니다. 삽화는 Rect(126, 0, 943, 943)이라
  /// 가운데가 (597.5, 471.5)입니다. 시안(544, 322)에서 그 자리로 옮겼고,
  /// 그 뒤 지시대로 조금 키웠습니다(1.3배).
  ///
  /// 높이는 삽화 속 **모자를 가리지 않는 선**까지 올렸습니다(2026-08).
  /// 모자 자리는 `MafiaTabletDayView.hatRegion`에 적어 두었고,
  /// `test/mafia_ballot_animation_test.dart`가 겹치지 않는지 확인합니다.
  static const Rect voting = Rect.fromLTWH(516.6, 296, 161.8, 158.6);

  /// 개표(시안 `tablet-p7 개표`)의 투표함입니다.
  static const Rect tally = Rect.fromLTWH(886, 528, 277, 270);

  static Offset get votingCenter => voting.center;
  static Offset get tallyCenter => tally.center;
}

/// 투표지 한 장입니다.
///
/// ⚠️ 투표지 전용 이미지가 아직 없어 흰 종이로 그립니다(테두리는 개표판과
/// 같은 `#AF7F3F`). 시안 이미지가 들어오면 이 위젯만 바꾸면 됩니다.
class MafiaBallotPaper extends StatelessWidget {
  const MafiaBallotPaper({super.key, this.width = 46, this.height = 34});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFAF7F3F), width: 1.5),
        borderRadius: BorderRadius.circular(3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: SizedBox(width: width, height: height),
    );
  }
}

/// 시안 좌표의 점을 실제 화면 좌표로 옮기는 변환입니다.
///
/// [MafiaTabletBox]와 같은 규약(가운데 정렬 레터박스)을 씁니다.
class MafiaTabletProjection {
  const MafiaTabletProjection({required this.scale, required this.offset});

  factory MafiaTabletProjection.of(BoxConstraints constraints) {
    final size = MafiaTabletDesign.resolve(constraints);
    final scale = MafiaTabletDesign.scaleOf(size);
    return MafiaTabletProjection(
      scale: scale,
      offset: Offset(
        (size.width - MafiaTabletDesign.size.width * scale) / 2,
        (size.height - MafiaTabletDesign.size.height * scale) / 2,
      ),
    );
  }

  final double scale;
  final Offset offset;

  Offset toScreen(Offset design) => offset + design * scale;
}

/// 좌석 번호의 시안 좌표 중심입니다.
Offset mafiaSeatDesignCenter(int seatIndex, int boardSeatCount) {
  final centers = normalizedPlayerCenters(boardSeatCount);
  final normalized = centers[seatIndex.clamp(0, centers.length - 1)];
  return Offset(
    normalized.dx * MafiaTabletDesign.size.width,
    normalized.dy * MafiaTabletDesign.size.height,
  );
}

//=======================투표 중: 좌석 → 투표함==============================
/// 투표한 사람의 좌석에서 투표지가 날아와 투표함에 들어가며 사라집니다.
///
/// 확정(2026-08). 누가 투표했는지는 실제 게임에서도 모두가 보므로 공개해도
/// 무해합니다. **어디에 투표했는지는 서버가 보내지 않습니다.**
class MafiaBallotTossLayer extends StatefulWidget {
  const MafiaBallotTossLayer({
    super.key,
    required this.submittedUids,
    required this.seatIndexes,
    required this.boardSeatCount,
  });

  /// 투표를 마친 사람들입니다. 이 목록이 늘어날 때마다 한 장이 날아갑니다.
  final List<String> submittedUids;

  /// `uid → 좌석 번호`입니다.
  final Map<String, int> seatIndexes;

  final int boardSeatCount;

  @override
  State<MafiaBallotTossLayer> createState() => _MafiaBallotTossLayerState();
}

class _MafiaBallotTossLayerState extends State<MafiaBallotTossLayer>
    with TickerProviderStateMixin {
  /// 투표지 한 장이 날아가는 시간입니다.
  static const Duration _flight = Duration(milliseconds: 720);

  /// 이미 연출을 보여 준 사람들입니다. 재접속·재빌드로 다시 날지 않게 합니다.
  late Set<String> _seen;
  final List<_BallotFlight> _flights = [];

  @override
  void initState() {
    super.initState();
    // 화면에 처음 붙는 순간 이미 낸 사람들은 연출 없이 넘깁니다.
    _seen = widget.submittedUids.toSet();
  }

  @override
  void didUpdateWidget(MafiaBallotTossLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    for (final uid in widget.submittedUids) {
      if (_seen.contains(uid)) continue;
      _seen.add(uid);
      _launch(uid);
    }
  }

  void _launch(String uid) {
    final seat = widget.seatIndexes[uid];
    if (seat == null) return;
    final controller = AnimationController(vsync: this, duration: _flight);
    final flight = _BallotFlight(
      from: mafiaSeatDesignCenter(seat, widget.boardSeatCount),
      controller: controller,
    );
    _flights.add(flight);
    controller.addStatusListener((status) {
      if (status != AnimationStatus.completed) return;
      // 투표함에 들어가는 순간 소리를 냅니다.
      if (mounted) SoundEffects.play(context, MafiaSounds.vote);
      controller.dispose();
      if (!mounted) return;
      setState(() => _flights.remove(flight));
    });
    setState(() {});
    controller.forward();
  }

  @override
  void dispose() {
    for (final flight in _flights) {
      flight.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_flights.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final projection = MafiaTabletProjection.of(constraints);
        return Stack(
          fit: StackFit.expand,
          children: [
            for (final flight in _flights)
              _BallotFlightView(
                flight: flight,
                target: MafiaBallotBoxRects.votingCenter,
                projection: projection,
              ),
          ],
        );
      },
    );
  }
}

class _BallotFlight {
  _BallotFlight({required this.from, required this.controller});
  final Offset from;
  final AnimationController controller;
}

/// 한 장이 좌석에서 투표함으로 날아가 작아지며 사라지는 모습입니다.
class _BallotFlightView extends StatelessWidget {
  const _BallotFlightView({
    required this.flight,
    required this.target,
    required this.projection,
  });

  final _BallotFlight flight;
  final Offset target;
  final MafiaTabletProjection projection;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: flight.controller,
      builder: (context, _) {
        final raw = flight.controller.value;
        final progress = Curves.easeInOut.transform(raw);
        final design = Offset.lerp(flight.from, target, progress)!;
        // 투표함에 닿는 마지막 구간에서 접혀 들어가듯 작아집니다.
        final shrink = raw < 0.8 ? 1.0 : 1 - (raw - 0.8) / 0.2;
        final position = projection.toScreen(design);
        final width = 46 * projection.scale * shrink;
        final height = 34 * projection.scale * shrink;

        return Positioned(
          left: position.dx - width / 2,
          top: position.dy - height / 2,
          width: math.max(width, 0.1),
          height: math.max(height, 0.1),
          child: IgnorePointer(
            child: Opacity(
              opacity: shrink.clamp(0.0, 1.0),
              // 날아가는 동안 한 바퀴 이상 돌아 종이가 펄럭이는 느낌을 줍니다.
              child: Transform.rotate(
                angle: progress * math.pi * 1.5,
                child: MafiaBallotPaper(width: width, height: height),
              ),
            ),
          ),
        );
      },
    );
  }
}
