import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:game_holdem/game_copy.dart';
import 'package:game_holdem/game_theme.dart';
import 'package:game_holdem/phone/widgets/board_summary.dart';
import 'package:game_holdem/shared/models/game_models.dart';
import 'package:game_holdem/shared/models/game_state.dart';
import 'package:game_holdem/shared/models/presentation_timing.dart';
import 'package:game_holdem/shared/widgets/card_view.dart';
import 'package:game_holdem/shared/widgets/table_ui.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:game_kit/localization/game_locale.dart';

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
    // 쇼다운은 태블릿이 카드를 한 사람씩 다 뒤집을 때까지 승패를 숨깁니다.
    final revealCount = showdown
        ? result!.revealedHands.values.where((hand) => hand.length == 2).length
        : 0;
    final announceAt = HoldemTiming.showdownWinnerAt(revealCount);
    if (_progress.duration! * _progress.value < announceAt) {
      return _ShowdownWait(
        key: const Key('holdem-result-waiting'),
        player: me,
        hand: game.hand,
        progress: _progress,
      );
    }
    final focusUid = won ? widget.uid : winners.firstOrNull;
    final focusName = game.players[focusUid]?.nickname ?? HoldemCopy.player;
    final best = focusUid == null
        ? const <HoldemCardModel>[]
        : result?.bestCards[focusUid] ?? const <HoldemCardModel>[];
    final resultMessage = split
        ? GameLocale.select(
            ko: '팟을 나눠 가졌어요',
            en: 'The pot was split',
            zhHans: '平分底池',
            zhHant: '平分底池',
          )
        : won
        ? showdown
              ? GameLocale.select(
                  ko: '팟을 가져왔어요',
                  en: 'You won the pot',
                  zhHans: '你赢得了底池',
                  zhHant: '你贏得了底池',
                )
              : GameLocale.select(
                  ko: '상대가 모두 폴드했어요',
                  en: 'Everyone else folded',
                  zhHans: '其他玩家都已弃牌',
                  zhHant: '其他玩家都已棄牌',
                )
        : GameLocale.select(
            ko: '$focusName 님 승리',
            en: '$focusName wins',
            zhHans: '$focusName 获胜',
            zhHant: '$focusName 獲勝',
          );
    final amount = won
        ? result?.awards[widget.uid] ?? 0
        : -(me?.totalContribution ?? 0);
    final myHand = {for (final card in game.hand) card.id};
    final focusHand = {
      for (final card in result?.revealedHands[focusUid] ?? const []) card.id,
    };
    final remaining = _progress.duration! * (1 - _progress.value);
    // SE처럼 낮은 휴대폰에서는 간격과 크기를 줄여 결과가 넘치지 않게 합니다.
    final compact = MediaQuery.sizeOf(context).height < 640;
    final stamp = split
        ? 'SPLIT'
        : won
        ? 'WIN'
        : 'LOSE';
    return Column(
      children: [
        const Spacer(),
        // 내 프로필: 누가 이겼는지보다 '나'를 먼저 보여 줍니다.
        _ResultProfile(
          key: const Key('holdem-result-profile'),
          characterId: me?.characterId,
          nickname: me?.nickname ?? '',
          stamp: stamp,
          won: won,
          size: compact ? 84 : 108,
        ),
        SizedBox(height: compact ? 12 : 18),
        if (amount != 0)
          HoldemChipAmount(
            amount: amount.abs(),
            prefix: amount > 0 ? '+' : '-',
            chipSize: 24,
            fontSize: compact ? 46 : 58,
            gap: 10,
          ),
        const SizedBox(height: 10),
        if (won)
          Text(
            resultMessage,
            textAlign: TextAlign.center,
            style: HoldemFonts.text(size: 17, weight: FontWeight.w900),
          )
        else
          _WinnerLine(
            characterId: game.players[focusUid]?.characterId,
            message: resultMessage,
          ),
        if (best.isNotEmpty) ...[
          SizedBox(height: compact ? 14 : 24),
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
                          ? HoldemCopy.myCards
                          : focusHand.contains(card.id)
                          ? GameLocale.select(
                              ko: '$focusName 카드',
                              en: "$focusName's cards",
                              zhHans: '$focusName 的牌',
                              zhHant: '$focusName 的牌',
                            )
                          : HoldemCopy.table,
                      mine: myHand.contains(card.id),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
        const Spacer(),
        // 칩 숫자가 커도 넘치지 않게 줄 전체를 폭에 맞춰 줄입니다.
        if (me != null)
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const HoldemChip(size: 18),
                const SizedBox(width: 8),
                Text(
                  HoldemCopy.myChips,
                  style: HoldemFonts.text(color: HoldemColors.muted),
                ),
                const SizedBox(width: 8),
                Text(
                  holdemChips(me.stack),
                  style: HoldemFonts.numbers(size: 24),
                ),
                const SizedBox(width: 6),
                Text(
                  GameLocale.select(
                    ko: '· ${_rank(game, me)}위',
                    en: '· Rank ${_rank(game, me)}',
                    zhHans: '· 第 ${_rank(game, me)} 名',
                    zhHant: '· 第 ${_rank(game, me)} 名',
                  ),
                  style: HoldemFonts.text(size: 13, color: HoldemColors.muted),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            Text(
              HoldemCopy.nextHand,
              style: HoldemFonts.text(size: 13, color: HoldemColors.muted),
            ),
            const Spacer(),
            Text(
              HoldemCopy.seconds(
                math.max(0, remaining.inMilliseconds / 1000).ceil(),
              ),
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

/// 쇼다운 결과를 알리기 전, 태블릿에서 카드를 뒤집는 동안의 화면입니다.
class _ShowdownWait extends StatelessWidget {
  const _ShowdownWait({
    super.key,
    required this.player,
    required this.hand,
    required this.progress,
  });
  final HoldemPlayerModel? player;
  final List<HoldemCardModel> hand;
  final Animation<double> progress;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Spacer(),
      MosiFace(characterId: player?.characterId, size: 84, ring: true),
      const SizedBox(height: 8),
      Text(
        player?.nickname ?? '',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: HoldemFonts.text(size: 18, weight: FontWeight.w900),
      ),
      const SizedBox(height: 26),
      Text(
        'SHOWDOWN',
        style: HoldemFonts.title(size: 40, color: HoldemColors.ivory),
      ),
      const SizedBox(height: 8),
      Text(
        GameLocale.select(
          ko: '태블릿에서 카드를 공개하고 있어요',
          en: 'Cards are being revealed on the tablet',
          zhHans: '平板正在公开卡牌',
          zhHant: '平板正在公開卡牌',
        ),
        textAlign: TextAlign.center,
        style: HoldemFonts.text(size: 15, color: HoldemColors.muted),
      ),
      const SizedBox(height: 26),
      if (hand.length == 2) HoldemHoleCards(cards: hand, width: 110),
      const Spacer(),
      ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: AnimatedBuilder(
          animation: progress,
          builder: (_, _) => LinearProgressIndicator(
            value: progress.value,
            minHeight: 6,
            color: HoldemColors.ivory,
            backgroundColor: HoldemColors.line(.18),
          ),
        ),
      ),
    ],
  );
}

/// 결과 화면 위쪽의 내 프로필입니다. 얼굴 아래에 WIN/LOSE 도장을 겹칩니다.
class _ResultProfile extends StatelessWidget {
  const _ResultProfile({
    super.key,
    required this.characterId,
    required this.nickname,
    required this.stamp,
    required this.won,
    required this.size,
  });
  final String? characterId;
  final String nickname;
  final String stamp;
  final bool won;
  final double size;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(
        width: size + 80,
        height: size + 26,
        child: Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: won
                        ? HoldemColors.accent.withValues(alpha: .85)
                        : Colors.black.withValues(alpha: .35),
                    blurRadius: won ? 34 : 18,
                    spreadRadius: won ? 6 : 0,
                  ),
                ],
              ),
              child: Opacity(
                opacity: won ? 1 : .72,
                child: MosiFace(
                  characterId: characterId,
                  size: size,
                  ring: true,
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 1.6, end: 1),
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeOutBack,
                builder: (_, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: _ResultStamp(label: stamp, strong: won),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 240),
        child: Text(
          nickname,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: HoldemFonts.text(size: 18, weight: FontWeight.w900),
        ),
      ),
    ],
  );
}

class _ResultStamp extends StatelessWidget {
  const _ResultStamp({required this.label, required this.strong});
  final String label;
  final bool strong;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: -6 * math.pi / 180,
    child: Container(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
      decoration: BoxDecoration(
        color: strong ? HoldemColors.accent : HoldemColors.panel(.92),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: strong ? HoldemColors.ivory : HoldemColors.line(.5),
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .45),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Text(
        label,
        style: HoldemFonts.title(
          size: 34,
          color: strong ? HoldemColors.ivory : HoldemColors.muted,
        ),
      ),
    ),
  );
}

/// 진 판에서 이긴 사람의 얼굴과 이름입니다.
class _WinnerLine extends StatelessWidget {
  const _WinnerLine({required this.characterId, required this.message});
  final String? characterId;
  final String message;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (characterId != null) ...[
          MosiFace(characterId: characterId, size: 28, ring: true),
          const SizedBox(width: 8),
        ],
        Text(
          message,
          style: HoldemFonts.text(size: 17, weight: FontWeight.w900),
        ),
      ],
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
