import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:game_holdem/game_theme.dart';
import 'package:game_holdem/shared/models/game_models.dart';
import 'package:game_holdem/shared/widgets/card_view.dart';
import 'package:game_holdem/shared/widgets/table_ui.dart';

/// 휴대폰 상단에서 공개 카드, 팟, 내 남은 칩을 함께 보여 줍니다.
class HoldemBoardSummary extends StatelessWidget {
  const HoldemBoardSummary({
    super.key,
    required this.cards,
    required this.potTotal,
    this.myStack = 0,
  });
  final List<HoldemCardModel> cards;
  final int potTotal;
  final int myStack;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: HoldemColors.panel(.55),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: HoldemColors.line(.14)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var index = 0; index < 5; index++) ...[
              if (index > 0) const SizedBox(width: 7),
              if (index < cards.length)
                HoldemCardView(
                  card: cards[index],
                  width: 40,
                  layout: HoldemCardLayout.mini,
                )
              else
                const HoldemCardSlot(width: 40),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: _BoardChipCount(label: 'POT', amount: potTotal),
              ),
            ),
            Container(width: 1, height: 28, color: HoldemColors.line(.2)),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: _BoardChipCount(label: '내 칩', amount: myStack),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _BoardChipCount extends StatelessWidget {
  const _BoardChipCount({required this.label, required this.amount});
  final String label;
  final int amount;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label ${holdemChips(amount)}',
    excludeSemantics: true,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const HoldemChip(size: 14),
        const SizedBox(width: 4),
        Text(
          label,
          style: HoldemFonts.text(
            size: 12,
            weight: FontWeight.w700,
            color: HoldemColors.muted,
          ),
        ),
        const SizedBox(width: 7),
        Text(holdemChips(amount), style: HoldemFonts.numbers(size: 27)),
      ],
    ),
  );
}

/// 손패 두 장을 부채꼴로 겹쳐 그립니다.
class HoldemHoleCards extends StatelessWidget {
  const HoldemHoleCards({
    super.key,
    required this.cards,
    this.faceDown = false,
    this.width = 132,
    this.dimmed = false,
  });
  final List<HoldemCardModel> cards;
  final bool faceDown;
  final double width;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final shown = faceDown || cards.length < 2;
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < 2; index++)
          Transform.translate(
            offset: Offset(index == 0 ? width * .1 : -width * .1, 0),
            child: Transform.rotate(
              angle: (index == 0 ? -7 : 7) * math.pi / 180,
              child: HoldemCardView(
                card: shown ? null : cards[index],
                faceDown: shown,
                width: width,
                layout: HoldemCardLayout.hand,
              ),
            ),
          ),
      ],
    );
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      opacity: dimmed ? .45 : 1,
      child: row,
    );
  }
}

/// 남은 행동 시간을 원형 게이지로 보여 줍니다.
class HoldemTimerRing extends StatelessWidget {
  const HoldemTimerRing({
    super.key,
    required this.seconds,
    required this.fraction,
  });
  final int seconds;
  final double fraction;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 46,
    child: CustomPaint(
      painter: _RingPainter(fraction.clamp(0, 1)),
      child: Center(
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: HoldemColors.night,
            shape: BoxShape.circle,
          ),
          // 숫자 글꼴의 줄 높이가 원보다 커서 위아래가 잘리지 않게 맞춥니다.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$seconds',
              style: HoldemFonts.numbers(
                size: 22,
                color: seconds <= 5 ? HoldemColors.danger : HoldemColors.ivory,
              ).copyWith(height: 1),
            ),
          ),
        ),
      ),
    ),
  );
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.fraction);
  final double fraction;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas
      ..drawCircle(
        rect.center,
        size.width / 2,
        Paint()..color = HoldemColors.line(.18),
      )
      ..drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * fraction,
        true,
        Paint()..color = HoldemColors.ivory,
      );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      fraction != oldDelegate.fraction;
}
