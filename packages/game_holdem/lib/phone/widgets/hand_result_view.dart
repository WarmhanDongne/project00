import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:game_holdem/game_copy.dart';
import 'package:game_holdem/game_theme.dart';
import 'package:game_holdem/shared/models/game_models.dart';
import 'package:game_holdem/shared/models/game_state.dart';
import 'package:game_holdem/shared/models/presentation_timing.dart';
import 'package:game_holdem/shared/widgets/card_view.dart';
import 'package:game_holdem/shared/widgets/table_ui.dart';

/// 휴대폰의 한 판 결과 화면입니다.
class HoldemHandResultView extends StatefulWidget {
  const HoldemHandResultView({
    super.key,
    required this.game,
    required this.uid,
  });
  final HoldemGameState game;
  final String uid;

  @override
  State<HoldemHandResultView> createState() => _HoldemHandResultViewState();
}

class _HoldemHandResultViewState extends State<HoldemHandResultView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progress = AnimationController(
    vsync: this,
    duration: HoldemTiming.handResult(widget.game.result?.reason),
  )..forward();
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final result = game.result;
    final me = game.players[widget.uid];
    final winners = result?.winnerUids ?? const <String>[];
    final won = winners.contains(widget.uid);
    final split = won && winners.length > 1;
    final showdown = result?.reason == 'showdown';
    final focusUid = won ? widget.uid : winners.firstOrNull;
    final focusName = game.players[focusUid]?.nickname ?? '플레이어';
    final best = focusUid == null
        ? const <HoldemCardModel>[]
        : result?.bestCards[focusUid] ?? const <HoldemCardModel>[];
    final resultMessage = split
        ? '팟을 나눠 가졌어요'
        : won
        ? showdown
              ? '팟을 가져왔어요'
              : '상대가 모두 폴드했어요'
        : '$focusName 님 승리';
    final amount = won
        ? result?.awards[widget.uid] ?? 0
        : -(me?.totalContribution ?? 0);
    final myHand = {for (final card in game.hand) card.id};
    final focusHand = {
      for (final card in result?.revealedHands[focusUid] ?? const []) card.id,
    };
    final remaining = _progress.duration! * (1 - _progress.value);
    return Column(
      children: [
        const Spacer(flex: 2),
        _ResultStamp(
          label: split
              ? 'SPLIT'
              : won
              ? 'WIN'
              : 'LOSE',
          strong: won,
        ),
        const SizedBox(height: 28),
        if (amount != 0)
          HoldemChipAmount(
            amount: amount.abs(),
            prefix: amount > 0 ? '+' : '-',
            chipSize: 26,
            fontSize: 64,
            gap: 10,
          ),
        const SizedBox(height: 18),
        Text(
          resultMessage,
          textAlign: TextAlign.center,
          style: HoldemFonts.text(size: 18, weight: FontWeight.w900),
        ),
        if (best.isNotEmpty) ...[
          const SizedBox(height: 34),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: .82, end: 1),
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeOutBack,
            builder: (_, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: FittedBox(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (index, card) in best.indexed) ...[
                    if (index > 0) const SizedBox(width: 8),
                    _LabeledCard(
                      card: card,
                      label: myHand.contains(card.id)
                          ? '내 카드'
                          : focusHand.contains(card.id)
                          ? '$focusName 카드'
                          : '테이블',
                      mine: myHand.contains(card.id),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 26),
        if (me != null)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const HoldemChip(size: 18),
              const SizedBox(width: 8),
              Text('내 칩', style: HoldemFonts.text(color: HoldemColors.muted)),
              const SizedBox(width: 8),
              Text(holdemChips(me.stack), style: HoldemFonts.numbers(size: 26)),
              const SizedBox(width: 6),
              Text(
                '· ${_rank(game, me)}위',
                style: HoldemFonts.text(size: 13, color: HoldemColors.muted),
              ),
            ],
          ),
        const Spacer(flex: 3),
        Row(
          children: [
            Text(
              HoldemCopy.nextHand,
              style: HoldemFonts.text(size: 13, color: HoldemColors.muted),
            ),
            const Spacer(),
            Text(
              '${math.max(0, remaining.inMilliseconds / 1000).ceil()}초',
              style: HoldemFonts.text(size: 13, color: HoldemColors.muted),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: AnimatedBuilder(
            animation: _progress,
            builder: (_, _) => LinearProgressIndicator(
              value: _progress.value,
              minHeight: 6,
              color: HoldemColors.ivory,
              backgroundColor: HoldemColors.line(.18),
            ),
          ),
        ),
      ],
    );
  }

  int _rank(HoldemGameState game, HoldemPlayerModel me) =>
      1 + game.players.values.where((player) => player.stack > me.stack).length;
}

class _ResultStamp extends StatelessWidget {
  const _ResultStamp({required this.label, required this.strong});
  final String label;
  final bool strong;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: -8 * math.pi / 180,
    child: Container(
      padding: const EdgeInsets.fromLTRB(28, 6, 28, 10),
      decoration: BoxDecoration(
        color: strong
            ? HoldemColors.accent.withValues(alpha: .55)
            : HoldemColors.panel(.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: strong ? HoldemColors.ivory : HoldemColors.line(.5),
          width: 5,
        ),
        boxShadow: [
          if (strong)
            BoxShadow(
              color: HoldemColors.accent.withValues(alpha: .9),
              spreadRadius: 4,
            ),
          BoxShadow(
            color: Colors.black.withValues(alpha: .45),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Text(
        label,
        style: HoldemFonts.title(
          size: 76,
          color: strong ? HoldemColors.ivory : HoldemColors.muted,
          shadows: const [
            Shadow(color: Color(0x4D000000), offset: Offset(0, 4)),
          ],
        ),
      ),
    ),
  );
}

class _LabeledCard extends StatelessWidget {
  const _LabeledCard({
    required this.card,
    required this.label,
    required this.mine,
  });
  final HoldemCardModel card;
  final String label;
  final bool mine;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      HoldemCardView(card: card, width: 70, layout: HoldemCardLayout.hand),
      const SizedBox(height: 8),
      SizedBox(
        width: 72,
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: HoldemFonts.text(
            size: 11,
            weight: FontWeight.w700,
            color: mine ? HoldemColors.ivory : HoldemColors.muted,
          ),
        ),
      ),
    ],
  );
}
