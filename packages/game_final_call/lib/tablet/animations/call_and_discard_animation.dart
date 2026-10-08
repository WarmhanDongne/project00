// [call_and_discard_animation.dart] 는 CALL 선언과 카드 교체·버리기 연출을 구성하는 파일이다.
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
import 'package:game_final_call/tablet/screens/seat_geometry.dart';
import 'package:game_final_call/shared/widgets/card_view.dart';
import 'package:game_kit/player_layouts/services/player_slot_positions.dart';
import 'package:game_final_call/game_copy.dart';
import 'package:game_final_call/game_theme.dart';
import 'package:game_final_call/shared/widgets/party_pop.dart';

// ============================================================

/// CALL 선언부터 최종 제출이 끝날 때까지 테이블 가운데에 CALL 폭발을 띄웁니다.
/// 선언자 자리는 좌석 이름표가 노랗게 바뀌어 함께 알려 줍니다.
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
        final scale = finalCallTabletScale(boardSize);
        final burstSize = Size(260 * scale, 190 * scale);
        final cardHeight =
            finalCallCenterCardWidth(boardSize) * finalCallCardHeightRatio;
        // 가운데 덱·공개 카드 바로 위에서 선언자의 CALL이 터집니다.
        final burstCenter =
            boardSize.center(Offset.zero) +
            Offset(0, -cardHeight / 2 - 20 * scale - burstSize.height / 2);
        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              left: burstCenter.dx - burstSize.width / 2,
              top: burstCenter.dy - burstSize.height / 2,
              width: burstSize.width,
              height: burstSize.height,
              child: IgnorePointer(
                child: TweenAnimationBuilder<double>(
                  key: ValueKey('final-call-burst-$uid'),
                  tween: Tween(begin: 0.4, end: 1),
                  duration: const Duration(milliseconds: 520),
                  curve: Curves.easeOutBack,
                  builder: (context, value, child) =>
                      Transform.scale(scale: value, child: child),
                  child: _CallBurst(callerName: player.nickname, scale: scale),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 시안의 노란 별 폭발 모양입니다.
class _CallBurst extends StatelessWidget {
  const _CallBurst({required this.callerName, required this.scale});

  final String callerName;
  final double scale;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: const _BurstPainter(),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            FinalCallCopy.callerOf(callerName),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: finalCallPopText(18 * scale),
          ),
          Text(
            'CALL!',
            style: finalCallPopText(
              58 * scale,
              color: FinalCallColors.red,
              height: 1,
              shadows: finalCallPopOutline(3 * scale),
            ),
          ),
        ],
      ),
    ),
  );
}

class _BurstPainter extends CustomPainter {
  const _BurstPainter();

  static const _points = <Offset>[
    Offset(.50, .00),
    Offset(.61, .18),
    Offset(.82, .08),
    Offset(.78, .30),
    Offset(1.0, .38),
    Offset(.82, .52),
    Offset(.96, .72),
    Offset(.72, .72),
    Offset(.68, .96),
    Offset(.50, .80),
    Offset(.32, .96),
    Offset(.28, .72),
    Offset(.04, .72),
    Offset(.18, .52),
    Offset(.00, .38),
    Offset(.22, .30),
    Offset(.18, .08),
    Offset(.39, .18),
  ];

  Path _path(Rect rect) {
    final path = Path();
    for (var index = 0; index < _points.length; index++) {
      final point = Offset(
        rect.left + _points[index].dx * rect.width,
        rect.top + _points[index].dy * rect.height,
      );
      index == 0
          ? path.moveTo(point.dx, point.dy)
          : path.lineTo(point.dx, point.dy);
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas
      ..drawPath(_path(rect.inflate(8)), Paint()..color = FinalCallColors.ink)
      ..drawPath(_path(rect), Paint()..color = FinalCallColors.yellow);
  }

  @override
  bool shouldRepaint(_BurstPainter oldDelegate) => false;
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
        final end = finalCallPublicCardCenter(boardSize);
        final cardWidth = finalCallCenterCardWidth(boardSize);
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
                  left: position.dx - cardWidth / 2,
                  top: position.dy - cardWidth * finalCallCardHeightRatio / 2,
                  child: Transform.rotate(
                    angle:
                        startRotation * (1 - progress) +
                        math.sin(progress * math.pi) * 0.16,
                    child: Transform.scale(
                      scale: 0.9 + (0.1 * progress),
                      child: FinalCallCardView(
                        card: widget.event.card,
                        width: cardWidth,
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
