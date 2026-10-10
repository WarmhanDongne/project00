// [round_start_reveal.dart] 라운드 시작 시 태블릿에
// 기준 카드 원·자리판·주장 칩·차례 화살표를 등장시키는 파일이다.

// ========================[ import ]==========================
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:game_kit/tablet/animations/board_element_entrance.dart';
import 'package:game_kit/player_layouts/services/player_slot_positions.dart';
import 'package:game_liars_poker/tablet/widgets/seat_plate.dart';

// ============================================================

/// 라운드 시작 시 테이블과 자리판을 함께 띄우고, 진행 중 차례·주장을 보여 줍니다.
class RoundStartReveal extends StatefulWidget {
  const RoundStartReveal({
    super.key,
    required this.tableCardValue,
    required this.playerCount,
    required this.seats,
    this.activePlayerIndex,
    this.playerSeatIndexes,
    this.turnDeadlineAt,
    this.turnWindow = const Duration(seconds: 30),
    this.claimPlayerIndex,
    this.claimCount = 0,
    this.duration = const Duration(milliseconds: 980),
    this.onCompleted,
  }) : assert(playerCount > 0),
       assert(seats.length == playerCount),
       assert(
         activePlayerIndex == null ||
             (activePlayerIndex >= 0 && activePlayerIndex < playerCount),
         'activePlayerIndex는 플레이어 범위 안이어야 합니다.',
       ),
       assert(
         playerSeatIndexes == null || playerSeatIndexes.length == playerCount,
         'playerSeatIndexes의 개수는 playerCount와 같아야 합니다.',
       );

  final String tableCardValue;
  final int playerCount;

  /// 자리 배치 순서대로 각 자리의 공개 정보입니다.
  final List<TabletSeatInfo> seats;
  final int? activePlayerIndex;
  final List<int>? playerSeatIndexes;

  /// 차례인 사람의 얼굴 테두리가 줄어드는 기준인 서버 마감 시각입니다.
  final int? turnDeadlineAt;
  final Duration turnWindow;

  /// 직전에 카드를 낸 사람과 장 수입니다. 주장 칩을 그 사람 쪽에 둡니다.
  final int? claimPlayerIndex;
  final int claimCount;

  final Duration duration;

  final VoidCallback? onCompleted;

  @override
  State<RoundStartReveal> createState() => _RoundStartRevealState();
}

class _RoundStartRevealState extends State<RoundStartReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener(_onStatusChanged)
      ..forward();
  }

  void _onStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      widget.onCompleted?.call();
    }
  }

  @override
  void didUpdateWidget(RoundStartReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
  }

  @override
  void dispose() {
    _controller
      ..removeStatusListener(_onStatusChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          final unit = tabletDesignScale(size);

          return AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final progress = _controller.value;
              final opacity = BoardEntranceCurves.opacityFor(progress);
              // 등장 곡선은 다른 게임 보드와 공유합니다. (BoardEntranceCurves)
              final scale = BoardEntranceCurves.depthScale.transform(progress);
              final activePlayerIndex = widget.activePlayerIndex;
              final claimIndex = widget.claimPlayerIndex;

              Widget entrance(Widget child) => Opacity(
                opacity: opacity,
                child: Transform.scale(scale: scale, child: child),
              );

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Center(
                    child: entrance(
                      SizedBox.square(
                        dimension: 480 * unit,
                        child: FittedBox(
                          child: TabletTableRing(
                            cardValue: widget.tableCardValue,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (activePlayerIndex != null)
                    _buildTurnArrow(size, unit, activePlayerIndex, opacity),
                  for (
                    var playerIndex = 0;
                    playerIndex < widget.playerCount;
                    playerIndex++
                  )
                    _buildSeat(
                      size: size,
                      unit: unit,
                      playerIndex: playerIndex,
                      child: entrance(
                        TabletSeatPlate(
                          key: ValueKey('seat-$playerIndex'),
                          seat: widget.seats[playerIndex],
                          isTurn: activePlayerIndex == playerIndex,
                          turnDeadlineAt: activePlayerIndex == playerIndex
                              ? widget.turnDeadlineAt
                              : null,
                          turnWindow: widget.turnWindow,
                        ),
                      ),
                    ),
                  if (claimIndex != null && widget.claimCount > 0)
                    _buildClaim(size, unit, claimIndex, opacity),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSeat({
    required Size size,
    required double unit,
    required int playerIndex,
    required Widget child,
  }) {
    final anchor = tabletSeatCenter(size, _orbitCenter(size, playerIndex));
    const plate = TabletSeatPlate.size;
    final rotation = tabletSeatRotation(size, anchor);
    return Positioned(
      left: anchor.dx - plate.width * unit / 2,
      top: anchor.dy - plate.height * unit / 2,
      width: plate.width * unit,
      height: plate.height * unit,
      child: Transform.rotate(
        angle: rotation,
        child: FittedBox(child: child),
      ),
    );
  }

  Widget _buildTurnArrow(
    Size size,
    double unit,
    int playerIndex,
    double opacity,
  ) {
    final board = size.center(Offset.zero);
    final seat = tabletSeatCenter(size, _orbitCenter(size, playerIndex));
    final direction = seat - board;
    final angle = math.atan2(direction.dy, direction.dx);
    final unitVector = Offset(math.cos(angle), math.sin(angle));
    // 더미 가장자리에서 출발해 자리판 바로 앞까지 자리 쪽을 가리킵니다.
    final start = board + unitVector * (190 * unit);
    final length = (direction.distance - 190 * unit - 105 * unit).clamp(
      48 * unit,
      140 * unit,
    );
    final height = 28 * unit;
    return Positioned(
      left: start.dx,
      top: start.dy - height / 2,
      width: length,
      height: height,
      child: Opacity(
        opacity: opacity,
        child: Transform.rotate(
          angle: angle,
          alignment: Alignment.centerLeft,
          child: const TabletTurnArrow(),
        ),
      ),
    );
  }

  Widget _buildClaim(Size size, double unit, int playerIndex, double opacity) {
    final board = size.center(Offset.zero);
    final seat = tabletSeatCenter(size, _orbitCenter(size, playerIndex));
    final rotation = tabletSeatRotation(size, seat);
    final direction = seat - board;
    final distance = direction.distance;
    final towardSeat = distance == 0 ? Offset.zero : direction / distance;
    final side = Offset(-towardSeat.dy, towardSeat.dx);
    // 카드 더미 옆, 주장한 사람 쪽에 그 사람을 향해 둡니다.
    final center = board + towardSeat * (230 * unit) - side * (150 * unit);
    const chip = Size(150, 46);
    return Positioned(
      left: center.dx - chip.width * unit / 2,
      top: center.dy - chip.height * unit / 2,
      width: chip.width * unit,
      height: chip.height * unit,
      child: Opacity(
        opacity: opacity,
        child: Transform.rotate(
          angle: rotation,
          child: FittedBox(
            child: TabletClaimChip(
              characterId: widget.seats[playerIndex].characterId,
              cardValue: widget.tableCardValue,
              count: widget.claimCount,
            ),
          ),
        ),
      ),
    );
  }

  Offset _orbitCenter(Size size, int playerIndex) {
    final centers = playerCentersForBoard(
      playerCount: widget.playerCount,
      boardSize: size,
      radiusFactor: defaultPlayerOrbitRadiusFactor,
    );
    final seatIndex = widget.playerSeatIndexes?[playerIndex] ?? playerIndex;
    return centers[seatIndex];
  }
}
