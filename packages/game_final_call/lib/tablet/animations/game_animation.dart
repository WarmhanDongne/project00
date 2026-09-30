// [game_animation.dart] 는 파이널콜에서 사용하는 태블릿 게임의 세부 진행 화면을 구성하는 파일이다.
//
// - [Package] : 파이널콜
// - [TabletScreen] : 태블릿 게임의 세부 진행 화면을 구성함
//
// 즉, 전체 참가자가 게임 단계와 결과를 함께 확인하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:game_final_call/shared/models/game_models.dart';
import 'package:game_final_call/shared/providers/game_controller.dart';
import 'package:game_final_call/tablet/screens/game_helper.dart';
import 'package:game_final_call/shared/widgets/card_view.dart';
import 'package:game_kit/player_layouts/player_slot_positions.dart';
import 'package:game_final_call/gen/assets.gen.dart';
import 'package:game_final_call/game_assets.dart';
// ============================================================

/// CALL 선언 위치에서 최종 교체 과정이 끝날 때까지 말풍선을 유지합니다.
class FinalCallTabletCallAnimation extends StatelessWidget {
  const FinalCallTabletCallAnimation({
    super.key,
    required this.controller,
    required this.playerCount,
  });
  final FinalCallController controller;
  final int playerCount;

  @override
  Widget build(BuildContext context) {
    final uid = controller.callerUid;
    final callInProgress =
        controller.phase == 'callerSubmit' ||
        controller.phase == 'finalTurns' ||
        controller.phase == 'finalSubmit';
    final player = controller.players[uid];
    if (!callInProgress || uid == null || player == null) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final boardSize = constraints.biggest;
        final center = playerCentersForBoard(
          playerCount: playerCount,
          boardSize: boardSize,
        )[player.seatIndex];
        final boardCenter = boardSize.center(Offset.zero);
        final inward = boardCenter - center;
        final bubbleCenter = inward.distanceSquared == 0
            ? center
            : center + inward / inward.distance * 78;
        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              left: bubbleCenter.dx,
              top: bubbleCenter.dy,
              child: FractionalTranslation(
                translation: const Offset(-0.5, -0.5),
                child: Transform.rotate(
                  angle: finalCallSeatRotationForCenter(
                    center: center,
                    boardSize: boardSize,
                  ),
                  child: Assets
                      .games
                      .finalCall
                      .images
                      .modal
                      .modalMessageCall
                      .game
                      .image(
                        width: 142,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                      ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 교체 완료 후 버려진 카드가 해당 플레이어 자리에서 중앙 공개 카드 위치로
/// 포물선을 그리며 던져지는 애니메이션입니다.
class FinalCallTabletDiscardAnimation extends StatefulWidget {
  const FinalCallTabletDiscardAnimation({
    super.key,
    required this.controller,
    required this.event,
    required this.playerCount,
  });

  final FinalCallController controller;
  final FinalCallDiscardEvent event;
  final int playerCount;

  @override
  State<FinalCallTabletDiscardAnimation> createState() =>
      _FinalCallTabletDiscardAnimationState();
}

class _FinalCallTabletDiscardAnimationState
    extends State<FinalCallTabletDiscardAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;

  @override
  void initState() {
    super.initState();
    _animation =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 760),
          )
          ..addStatusListener(_handleStatus)
          ..forward();
  }

  void _handleStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      widget.controller.acknowledgeDiscardEvent(widget.event.version);
    }
  }

  @override
  void dispose() {
    _animation
      ..removeStatusListener(_handleStatus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.controller.players[widget.event.playerUid];
    if (player == null) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final boardSize = constraints.biggest;
        final start = playerCentersForBoard(
          playerCount: widget.playerCount,
          boardSize: boardSize,
        )[player.seatIndex];
        final end = Offset(
          constraints.maxWidth / 2 + 66,
          constraints.maxHeight / 2,
        );
        final startRotation = finalCallSeatRotationForCenter(
          center: start,
          boardSize: boardSize,
        );
        return Stack(
          fit: StackFit.expand,
          children: [
            AnimatedBuilder(
              animation: _animation,
              builder: (context, _) {
                final progress = Curves.easeOutCubic.transform(
                  _animation.value,
                );
                final position =
                    Offset.lerp(start, end, progress)! +
                    Offset(0, -math.sin(progress * math.pi) * 64);
                return Positioned(
                  left: position.dx - 53,
                  top: position.dy - 78,
                  child: Transform.rotate(
                    angle:
                        startRotation * (1 - progress) +
                        math.sin(progress * math.pi) * 0.16,
                    child: Transform.scale(
                      scale: 0.9 + (0.1 * progress),
                      child: FinalCallCardView(
                        card: widget.event.card,
                        width: 106,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
