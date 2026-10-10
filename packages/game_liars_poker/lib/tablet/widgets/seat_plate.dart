// [seat_plate.dart] 태블릿 테이블의 자리판, 기준 카드 원, 주장 칩과
// 차례 화살표를 그리는 파일이다. 모든 부품은 시안(1194×834) 크기로 그리고
// 화면 크기에 맞춰 함께 줄어듭니다.

// ========================[ import ]==========================
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:game_kit/shared/widgets/game_turn_countdown.dart';
import 'package:game_liars_poker/game_assets.dart';
import 'package:game_liars_poker/game_theme.dart';
import 'package:game_liars_poker/gen/assets.gen.dart';
import 'package:game_liars_poker/shared/widgets/noir_ui.dart';

// ============================================================

/// 자리판 한 칸에 필요한 공개 정보입니다.
@immutable
class TabletSeatInfo {
  const TabletSeatInfo({
    required this.nickname,
    required this.characterId,
    required this.penaltyCount,
    required this.remainingCardCount,
    this.eliminated = false,
  });

  final String nickname;
  final String characterId;
  final int penaltyCount;
  final int remainingCardCount;
  final bool eliminated;

  @override
  bool operator ==(Object other) =>
      other is TabletSeatInfo &&
      nickname == other.nickname &&
      characterId == other.characterId &&
      penaltyCount == other.penaltyCount &&
      remainingCardCount == other.remainingCardCount &&
      eliminated == other.eliminated;

  @override
  int get hashCode => Object.hash(
    nickname,
    characterId,
    penaltyCount,
    remainingCardCount,
    eliminated,
  );
}

/// 시안 기준 크기입니다.
const tabletDesignSize = Size(1194, 834);

/// 화면이 시안보다 작거나 클 때 부품을 함께 줄이는 배율입니다.
double tabletDesignScale(Size board) => math.min(
  board.width / tabletDesignSize.width,
  board.height / tabletDesignSize.height,
);

/// 자리판 중심입니다. 기존 자리 배치 방향은 유지하고, 테이블 가운데를
/// 비우도록 그 방향으로 화면 가장자리까지 밀어 둡니다. 돌린 자리판이
/// 화면 밖으로 나가지 않는 가장 먼 지점입니다.
Offset tabletSeatCenter(
  Size board,
  Offset orbitCenter, {
  Size plateSize = TabletSeatPlate.size,
}) {
  final center = board.center(Offset.zero);
  final direction = orbitCenter - center;
  if (direction.distanceSquared == 0) return center;
  final scale = tabletDesignScale(board);
  final angle = math.atan2(direction.dy, direction.dx);
  final rotation = angle - math.pi / 2;
  final halfWidth = plateSize.width * scale / 2;
  final halfHeight = plateSize.height * scale / 2;
  final extentX =
      (math.cos(rotation) * halfWidth).abs() +
      (math.sin(rotation) * halfHeight).abs();
  final extentY =
      (math.sin(rotation) * halfWidth).abs() +
      (math.cos(rotation) * halfHeight).abs();
  final margin = 6 * scale;
  final limitX = board.width / 2 - extentX - margin;
  final limitY = board.height / 2 - extentY - margin;
  final ux = math.cos(angle);
  final uy = math.sin(angle);
  final reach = math.min(
    ux.abs() < 1e-6 ? double.infinity : limitX / ux.abs(),
    uy.abs() < 1e-6 ? double.infinity : limitY / uy.abs(),
  );
  return center + Offset(ux, uy) * math.max(0, reach);
}

/// 자리판의 위쪽이 테이블 가운데를 향하도록 돌리는 각도입니다.
double tabletSeatRotation(Size board, Offset seatCenter) {
  final direction = seatCenter - board.center(Offset.zero);
  if (direction.distanceSquared == 0) return 0;
  return math.atan2(direction.dy, direction.dx) - math.pi / 2;
}

// ---------------------------------------------------------------------------
// 자리판
// ---------------------------------------------------------------------------
/// 이름·룰렛 단계·손패 뒷면·남은 장 수를 보여 주는 자리판(300×110)입니다.
///
/// 차례인 사람은 금색 테두리로 빛나고 얼굴 테두리가 남은 시간만큼 줄어듭니다.
class TabletSeatPlate extends StatelessWidget {
  const TabletSeatPlate({
    super.key,
    required this.seat,
    this.isTurn = false,
    this.turnDeadlineAt,
    this.turnWindow = const Duration(seconds: 30),
  });

  static const Size size = Size(300, 170);

  final TabletSeatInfo seat;
  final bool isTurn;
  final int? turnDeadlineAt;
  final Duration turnWindow;

  @override
  Widget build(BuildContext context) {
    final danger = liarsPokerIsDanger(seat.penaltyCount) && !seat.eliminated;
    final count = seat.remainingCardCount;
    final plate = Container(
      width: 300,
      height: 110,
      decoration: BoxDecoration(
        color: isTurn ? LiarsPokerColors.panelRaised : LiarsPokerColors.panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isTurn ? LiarsPokerColors.gold : LiarsPokerColors.panelEdge,
          width: isTurn ? 3 : 2,
        ),
        boxShadow: isTurn
            ? [
                BoxShadow(
                  color: LiarsPokerColors.gold.withValues(alpha: .15),
                  spreadRadius: 6,
                ),
                BoxShadow(
                  color: LiarsPokerColors.gold.withValues(alpha: .25),
                  blurRadius: 40,
                ),
              ]
            : const [
                BoxShadow(
                  color: Color(0x59000000),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
      ),
    );
    final avatar = isTurn
        ? _TurnAvatar(
            characterId: seat.characterId,
            deadlineAt: turnDeadlineAt,
            window: turnWindow,
          )
        : NoirAvatar(
            characterId: seat.characterId,
            size: 104,
            ringColor: seat.eliminated
                ? LiarsPokerColors.dim
                : danger
                ? LiarsPokerColors.red
                : LiarsPokerColors.ivory,
            ringWidth: 5,
            grayscale: seat.eliminated,
          );
    return SizedBox.fromSize(
      size: size,
      child: Opacity(
        opacity: seat.eliminated ? .5 : 1,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 손패 뒷면 부채꼴과 남은 장 수(테이블 가운데 쪽)입니다.
            if (count > 0)
              Positioned(
                left: 0,
                right: 0,
                top: 20,
                height: 70,
                child: _HandFan(count: count),
              ),
            Positioned(left: 0, top: 60, child: plate),
            Positioned(left: -10, top: 63, child: avatar),
            Positioned(
              left: 106,
              right: 14,
              top: 60,
              height: 110,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    seat.nickname,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LiarsPokerFonts.text(
                      size: 22,
                      weight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (seat.eliminated)
                    Text(
                      '탈락',
                      style: LiarsPokerFonts.text(
                        size: 13,
                        weight: FontWeight.w700,
                        color: LiarsPokerColors.pink,
                      ),
                    )
                  else
                    NoirRouletteStatus(penaltyCount: seat.penaltyCount),
                ],
              ),
            ),
            if (count > 0)
              Positioned(
                left: 150 + count * 7.0,
                top: 10,
                child: _CountBadge(count: count),
              ),
          ],
        ),
      ),
    );
  }
}

class _TurnAvatar extends StatelessWidget {
  const _TurnAvatar({
    required this.characterId,
    required this.deadlineAt,
    required this.window,
  });

  final String characterId;
  final int? deadlineAt;
  final Duration window;

  @override
  Widget build(BuildContext context) {
    Widget ring(double fraction) => Container(
      width: 108,
      height: 108,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: LiarsPokerColors.goldLight.withValues(alpha: .45),
            blurRadius: 22,
          ),
          const BoxShadow(
            color: Color(0x80000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: NoirProgressRing(
        fraction: fraction,
        color: LiarsPokerColors.goldLight,
        track: LiarsPokerColors.panelEdge,
        child: Center(
          child: Container(
            width: 98,
            height: 98,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: LiarsPokerColors.night,
            ),
            child: NoirAvatar(characterId: characterId, size: 90),
          ),
        ),
      ),
    );
    final deadline = deadlineAt;
    if (deadline == null) return ring(1);
    return GameTurnCountdown(
      expiresAt: deadline,
      builder: (context, remaining) => ring(
        remaining == null
            ? 1
            : remaining.inMilliseconds / window.inMilliseconds,
      ),
    );
  }
}

class _HandFan extends StatelessWidget {
  const _HandFan({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final back = Assets.games.liarsPoker.images.cards.whiteBack.game;
    final shown = math.min(count, 6);
    final spread = shown <= 1 ? 0.0 : 18.0 / (shown - 1);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (var index = 0; index < shown; index++)
          Positioned(
            left: 150 - (shown - 1) * 7 + index * 14.0,
            top: 0,
            child: Transform.rotate(
              angle: (-9 + index * spread) * math.pi / 180,
              child: Container(
                width: 46,
                height: 68,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x73000000),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: back.image(fit: BoxFit.cover),
              ),
            ),
          ),
      ],
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 260),
    transitionBuilder: (child, animation) => ScaleTransition(
      scale: animation,
      child: FadeTransition(opacity: animation, child: child),
    ),
    child: Container(
      key: ValueKey(count),
      constraints: const BoxConstraints(minWidth: 26),
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: LiarsPokerColors.ivory,
        borderRadius: BorderRadius.circular(13),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        '$count',
        style: LiarsPokerFonts.text(
          size: 15,
          weight: FontWeight.w700,
          color: LiarsPokerColors.night,
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// 기준 카드 원
// ---------------------------------------------------------------------------
/// 카드 더미 아래의 얇은 원과, 네 방향에서 읽히는 기준 카드 표식입니다.
class TabletTableRing extends StatelessWidget {
  const TabletTableRing({super.key, required this.cardValue});

  final String cardValue;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '테이블 카드 ${cardValue.toUpperCase()}',
    child: CustomPaint(
      size: const Size.square(480),
      painter: _TableRingPainter(cardValue.toUpperCase()),
    ),
  );
}

class _TableRingPainter extends CustomPainter {
  const _TableRingPainter(this.cardValue);

  final String cardValue;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final scale = size.width / 480;
    final gold = LiarsPokerColors.gold;
    canvas
      ..drawCircle(
        center,
        212 * scale,
        Paint()..color = const Color(0x2E0D0912),
      )
      ..drawCircle(
        center,
        212 * scale,
        Paint()
          ..color = gold.withValues(alpha: .35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    final text = TextPainter(
      text: TextSpan(
        text: cardValue,
        style: LiarsPokerFonts.western(size: 24 * scale, color: gold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    for (var quarter = 0; quarter < 4; quarter++) {
      canvas
        ..save()
        ..translate(center.dx, center.dy)
        ..rotate(quarter * math.pi / 2)
        ..translate(0, 212 * scale);
      canvas
        ..drawCircle(
          Offset.zero,
          20 * scale,
          Paint()..color = LiarsPokerColors.panelRaised,
        )
        ..drawCircle(
          Offset.zero,
          20 * scale,
          Paint()
            ..color = gold.withValues(alpha: .6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      text.paint(canvas, Offset(-text.width / 2, -text.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_TableRingPainter oldDelegate) =>
      cardValue != oldDelegate.cardValue;
}

// ---------------------------------------------------------------------------
// 주장 칩과 차례 화살표
// ---------------------------------------------------------------------------
/// `A×2`처럼 직전 사람이 무엇을 몇 장 냈다고 주장했는지 보여 주는 칩입니다.
class TabletClaimChip extends StatelessWidget {
  const TabletClaimChip({
    super.key,
    required this.characterId,
    required this.cardValue,
    required this.count,
  });

  final String characterId;
  final String cardValue;
  final int count;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '${cardValue.toUpperCase()} $count장 주장',
    excludeSemantics: true,
    child: Container(
      padding: const EdgeInsets.fromLTRB(5, 5, 16, 5),
      decoration: BoxDecoration(
        color: LiarsPokerColors.ivory,
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          NoirAvatar(characterId: characterId, size: 34),
          const SizedBox(width: 8),
          Text(
            '${cardValue.toUpperCase()}×$count',
            style: LiarsPokerFonts.western(
              size: 24,
              color: LiarsPokerColors.night,
            ),
          ),
        ],
      ),
    ),
  );
}

/// 다음 차례 쪽을 가리키는 금색 화살표입니다(오른쪽을 향하게 그립니다).
class TabletTurnArrow extends StatelessWidget {
  const TabletTurnArrow({super.key});

  @override
  Widget build(BuildContext context) =>
      const CustomPaint(size: Size.infinite, painter: _ArrowPainter());
}

class _ArrowPainter extends CustomPainter {
  const _ArrowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = LiarsPokerColors.gold;
    final mid = size.height / 2;
    final head = size.height * 1.07;
    canvas
      ..drawRRect(
        RRect.fromLTRBR(
          0,
          mid - size.height * .11,
          size.width - head * .85,
          mid + size.height * .11,
          Radius.circular(size.height * .11),
        ),
        paint,
      )
      ..drawPath(
        Path()
          ..moveTo(size.width - head, 0)
          ..lineTo(size.width, mid)
          ..lineTo(size.width - head, size.height)
          ..close(),
        paint,
      );
  }

  @override
  bool shouldRepaint(_ArrowPainter oldDelegate) => false;
}
