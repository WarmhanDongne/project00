// [game_penalty.dart] 태블릿에 벌칙 룰렛과 자리별 안내를 표시하고,
// 결과를 서버에 반영하는 동안의 입력 차단과 룰렛 결과 화면을 구성하는 파일이다.

// ========================[ import ]==========================
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:game_kit/penalty/roulette.dart';
import 'package:game_kit/player_layouts/services/player_slot_positions.dart';
import 'package:game_liars_poker/tablet/widgets/penalty_panels.dart';
import 'package:game_liars_poker/tablet/widgets/seat_plate.dart';

// ============================================================

/// 벌칙 룰렛과 서버 반영 중 상태, 룰렛 결과를 표시합니다.
///
/// 룰렛은 돌리는 사람 쪽으로 포인터와 레버가 오도록 통째로 돌립니다.
class LiarsPokerTabletGamePenalty extends StatelessWidget {
  const LiarsPokerTabletGamePenalty({
    super.key,
    required this.attemptCount,
    required this.characterId,
    required this.isResolving,
    required this.onPrepareResult,
    required this.onResult,
    this.layout,
    this.result,
  });

  final int attemptCount;
  final String characterId;
  final bool isResolving;
  final Future<RouletteResult?> Function() onPrepareResult;
  final ValueChanged<RouletteResult> onResult;

  /// 자리별 안내와 레버 방향에 쓰는 자리 정보입니다.
  final TabletPenaltyLayout? layout;

  /// 서버가 반영한 룰렛 결과입니다. 있으면 룰렛 대신 결과 화면을 보여 줍니다.
  final RouletteResult? result;

  @override
  Widget build(BuildContext context) {
    final seats = layout;
    final finished = result;
    if (finished != null && seats != null) {
      return TabletRouletteResult(
        key: ValueKey('roulette-result-${seats.targetIndex}'),
        layout: seats,
        eliminated: finished == RouletteResult.eliminated,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final unit = tabletDesignScale(size);
        // 원판(캔버스의 70%)이 시안의 480 크기가 되도록 맞춥니다.
        final wheel = math.min(size.shortestSide * .8, 686 * unit);
        return Stack(
          children: [
            if (seats != null)
              Positioned.fill(child: TabletRouletteNotices(layout: seats)),
            Positioned.fill(
              child: AbsorbPointer(
                absorbing: isResolving,
                child: Center(
                  child: SizedBox.square(
                    dimension: wheel,
                    child: Transform.rotate(
                      angle: seats == null ? 0 : _facingAngle(size, seats),
                      child: PenaltyRoulette(
                        attemptCount: attemptCount,
                        centerCharacterId: characterId,
                        onPrepareResult: onPrepareResult,
                        onResult: onResult,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // 룰렛 결과를 서버에 반영하는 동안에는 위쪽 AbsorbPointer가 입력만
            // 막습니다. 결과가 나온 화면을 로딩 표시로 가리면 연출이 끊겨 보여
            // 별도 스피너나 어두운 막은 그리지 않습니다.
          ],
        );
      },
    );
  }

  /// 룰렛의 위쪽(포인터·레버)이 돌리는 사람 자리를 향하게 하는 각도입니다.
  double _facingAngle(Size size, TabletPenaltyLayout seats) {
    final centers = playerCentersForBoard(
      playerCount: seats.seats.length,
      boardSize: size,
      radiusFactor: defaultPlayerOrbitRadiusFactor,
    );
    final seat = tabletSeatCenter(
      size,
      centers[seats.seatIndexes[seats.targetIndex]],
    );
    final direction = seat - size.center(Offset.zero);
    return math.atan2(direction.dy, direction.dx) + math.pi / 2;
  }
}
