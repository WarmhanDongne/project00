// [game_actions.dart] 는 파이널콜에서 사용하는 휴대폰 게임 화면에서 재사용하는 UI를 구성하는 파일이다.
//
// - [Package] : 파이널콜
// - [PhoneWidget] : 휴대폰 게임 화면에서 재사용하는 UI를 구성함
//
// 즉, 플레이어 입력과 상태 표시를 작은 책임으로 나눠 관리하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:game_final_call/game_copy.dart';
import 'package:game_final_call/game_theme.dart';
import 'package:game_final_call/shared/models/game_models.dart';
import 'package:game_final_call/shared/providers/game_controller.dart';
import 'package:game_final_call/shared/widgets/card_view.dart';
import 'package:game_final_call/shared/widgets/party_pop.dart';

// ============================================================

/// 휴대폰 오른쪽 조작 패널의 폭입니다(시안 222).
const double finalCallPhonePanelWidth = 222;

/// 오른쪽 흰 패널 틀입니다.
class FinalCallPhonePanel extends StatelessWidget {
  const FinalCallPhonePanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => FinalCallPopBox(
    width: finalCallPhonePanelWidth,
    padding: const EdgeInsets.all(14),
    child: child,
  );
}

/// 내 차례 조작부입니다. 새 카드를 받기 전에는 가져올 곳과 CALL을,
/// 받은 뒤에는 교체·버리기를 보여 줍니다.
class FinalCallPhoneActions extends StatelessWidget {
  const FinalCallPhoneActions({
    super.key,
    required this.controller,
    required this.selectedCardId,
    required this.onDraw,
    required this.onCall,
    required this.onCompleteTurn,
    required this.replacementInProgress,
  });

  final FinalCallController controller;
  final String? selectedCardId;
  final ValueChanged<String> onDraw;
  final VoidCallback onCall;
  final Future<void> Function(String? replaceCardId) onCompleteTurn;
  final bool replacementInProgress;

  @override
  Widget build(BuildContext context) {
    if (controller.pendingDraw != null) {
      return _PendingCardAction(
        controller: controller,
        selectedCardId: selectedCardId,
        onCompleteTurn: onCompleteTurn,
        replacementInProgress: replacementInProgress,
      );
    }
    return _TurnStartAction(
      controller: controller,
      onDraw: onDraw,
      onCall: onCall,
    );
  }
}

// ---------------------------------------------------------------------------
// ① 턴 시작: 덱 / 공개 카드 / CALL
// ---------------------------------------------------------------------------
class _TurnStartAction extends StatelessWidget {
  const _TurnStartAction({
    required this.controller,
    required this.onDraw,
    required this.onCall,
  });

  final FinalCallController controller;
  final ValueChanged<String> onDraw;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    final discard = controller.discardCard;
    final canDraw = controller.canDraw;
    final lastSwap = controller.phase == 'finalTurns';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          FinalCallCopy.whereToDraw,
          textAlign: TextAlign.center,
          style: finalCallPopText(15, color: FinalCallColors.muted),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _SourceButton(
                label: FinalCallCopy.deck,
                semanticLabel: '덱에서 새 카드 가져오기',
                onPressed: canDraw && controller.deckRemainingCount > 0
                    ? () => onDraw('deck')
                    : null,
                card: const FinalCallCardBack(width: 44),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SourceButton(
                label: FinalCallCopy.publicCard,
                semanticLabel: '공개 카드 가져오기',
                onPressed: canDraw && discard != null
                    ? () => onDraw('discard')
                    : null,
                card: discard == null
                    ? const SizedBox(width: 44, height: 62)
                    : FinalCallCardFace(card: discard, width: 44),
              ),
            ),
          ],
        ),
        const Spacer(),
        if (lastSwap)
          FinalCallPopBox(
            color: FinalCallColors.lilac,
            radius: 16,
            borderWidth: 3,
            shadowDepth: 0,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              FinalCallCopy.lastSwap,
              textAlign: TextAlign.center,
              style: finalCallPopText(15),
            ),
          )
        else
          FinalCallHoldToCallButton(
            enabled: controller.canCall,
            onCall: onCall,
          ),
      ],
    );
  }
}

class _SourceButton extends StatelessWidget {
  const _SourceButton({
    required this.label,
    required this.semanticLabel,
    required this.onPressed,
    required this.card,
  });

  final String label;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final Widget card;

  @override
  Widget build(BuildContext context) => FinalCallPopButton(
    semanticLabel: semanticLabel,
    onPressed: onPressed,
    color: FinalCallColors.lilac,
    height: 108,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        card,
        const SizedBox(height: 6),
        Text(label, style: finalCallPopText(16)),
      ],
    ),
  );
}

/// 꾹 누르고 있어야 선언되는 CALL 버튼입니다.
///
/// 실수로 스치기만 해도 판이 뒤집히지 않도록 [holdDuration] 동안 누르고
/// 있어야 합니다. 누르는 동안 버튼 안이 왼쪽부터 차오릅니다.
/// 화면 읽기 사용자는 접근성 탭 한 번으로 선언합니다.
class FinalCallHoldToCallButton extends StatefulWidget {
  const FinalCallHoldToCallButton({
    super.key,
    required this.enabled,
    required this.onCall,
  });

  final bool enabled;
  final VoidCallback onCall;

  static const holdDuration = Duration(milliseconds: 650);

  @override
  State<FinalCallHoldToCallButton> createState() =>
      _FinalCallHoldToCallButtonState();
}

class _FinalCallHoldToCallButtonState extends State<FinalCallHoldToCallButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: FinalCallHoldToCallButton.holdDuration,
  )..addStatusListener(_handleStatus);

  void _handleStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    if (widget.enabled) widget.onCall();
    _hold.value = 0;
  }

  @override
  void didUpdateWidget(covariant FinalCallHoldToCallButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _hold.value > 0) _hold.value = 0;
  }

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'CALL 선언',
      excludeSemantics: true,
      onTap: enabled ? widget.onCall : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _hold.forward() : null,
        onTapUp: enabled ? (_) => _hold.reverse() : null,
        onTapCancel: enabled ? () => _hold.reverse() : null,
        child: AnimatedOpacity(
          opacity: enabled ? 1 : 0.45,
          duration: const Duration(milliseconds: 150),
          child: AnimatedBuilder(
            animation: _hold,
            builder: (context, _) {
              final depth = 5 - 4 * _hold.value;
              return SizedBox(
                height: 67,
                child: Padding(
                  padding: EdgeInsets.only(top: 5 - depth, bottom: depth),
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: FinalCallColors.red,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: FinalCallColors.ink, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: FinalCallColors.ink,
                          offset: Offset(0, depth),
                        ),
                      ],
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: _hold.value,
                          child: const ColoredBox(color: Color(0x2E1B1530)),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'CALL!',
                              style: finalCallPopText(
                                26,
                                color: Colors.white,
                                height: 1.1,
                                shadows: finalCallPopOutline(),
                              ),
                            ),
                            Text(
                              FinalCallCopy.holdToCall,
                              style: finalCallPopText(12, color: Colors.white),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ② 새 카드 받음: 교체 / 버리기
// ---------------------------------------------------------------------------
class _PendingCardAction extends StatelessWidget {
  const _PendingCardAction({
    required this.controller,
    required this.selectedCardId,
    required this.onCompleteTurn,
    required this.replacementInProgress,
  });

  final FinalCallController controller;
  final String? selectedCardId;
  final Future<void> Function(String? replaceCardId) onCompleteTurn;
  final bool replacementInProgress;

  @override
  Widget build(BuildContext context) {
    final card = controller.pendingDraw!;
    final hand = controller.hand;
    final selected = hand
        .where((handCard) => handCard.id == selectedCardId)
        .firstOrNull;
    final current = finalCallBestCombination(hand);
    final after = selected == null
        ? null
        : finalCallBestCombination([
            for (final handCard in hand)
              handCard.id == selected.id ? card : handCard,
          ]);
    // 가장 낮은 가로 휴대폰(SE)에서는 버튼 높이를 줄여 패널을 넘지 않게 합니다.
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 250;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _PendingCardEntry(
                  key: ValueKey(
                    'pending-${card.id}-${controller.pendingDrawSource}',
                  ),
                  card: card,
                  revealFromBack: controller.pendingDrawSource == 'deck',
                  leavingForReplacement: replacementInProgress,
                  cardWidth: compact ? 62 : 72,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: after == null
                      ? Text(
                          FinalCallCopy.pickToPreview,
                          style: finalCallPopText(
                            13,
                            color: FinalCallColors.muted,
                          ),
                        )
                      : _ScorePreview(before: current.score, after: after),
                ),
              ],
            ),
            const Spacer(),
            // 마지막 교체를 최종 제출로 오해하지 않도록 두 동작을 분리합니다.
            // 이 버튼이 끝난 뒤 별도 최종 제출 화면이 열립니다.
            FinalCallPopButton(
              semanticLabel: selected == null
                  ? FinalCallCopy.pickCardToReplace
                  : FinalCallCopy.replaceWith(
                      finalCallCardColorLabel(selected.color),
                      selected.value,
                    ),
              onPressed: selected == null || replacementInProgress
                  ? null
                  : () => onCompleteTurn(selected.id),
              color: FinalCallColors.violet,
              height: compact ? 46 : 54,
              radius: 18,
              borderWidth: 4,
              shadowDepth: 5,
              child: Text(
                selected == null
                    ? FinalCallCopy.pickCardToReplace
                    : FinalCallCopy.replaceWith(
                        finalCallCardColorLabel(selected.color),
                        selected.value,
                      ),
                style: finalCallPopText(
                  18,
                  color: Colors.white,
                  shadows: finalCallPopOutline(),
                ),
              ),
            ),
            SizedBox(height: compact ? 6 : 8),
            FinalCallPopButton(
              semanticLabel: FinalCallCopy.discardNewCard,
              onPressed: replacementInProgress
                  ? null
                  : () => onCompleteTurn(null),
              height: compact ? 38 : 44,
              child: Text(
                FinalCallCopy.discardNewCard,
                style: finalCallPopText(16),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ScorePreview extends StatelessWidget {
  const _ScorePreview({required this.before, required this.after});

  final int before;
  final FinalCallCombination after;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        FinalCallCopy.ifReplaced,
        style: finalCallPopText(13, color: FinalCallColors.muted),
      ),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '$before',
              style: finalCallPopText(22, color: const Color(0xFF9C95B8)),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Icon(
                Icons.arrow_forward_rounded,
                size: 18,
                color: FinalCallColors.ink,
              ),
            ),
            Text(
              '${after.score}',
              style: finalCallPopText(
                40,
                color: after.score >= before
                    ? FinalCallColors.violet
                    : FinalCallColors.red,
                height: 1,
                shadows: finalCallPopOutline(),
              ),
            ),
          ],
        ),
      ),
      Text(
        FinalCallCopy.combinationName(after, finalCallCardColorLabel),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: finalCallPopText(13),
      ),
    ],
  );
}

/// 덱에서 가져온 카드는 뒷면으로 들어온 뒤 회전해 공개하고, 공개 카드에서
/// 가져온 경우에는 앞면 그대로 조작부에 들어옵니다.
///
/// 상위가 카드마다 다른 key를 주므로 새 카드가 올 때마다 처음부터 재생됩니다.
class _PendingCardEntry extends StatelessWidget {
  const _PendingCardEntry({
    super.key,
    required this.card,
    required this.revealFromBack,
    required this.leavingForReplacement,
    this.cardWidth = 72,
  });

  /// 새 카드 너비입니다. 낮은 휴대폰에서는 조금 작게 그립니다.
  final double cardWidth;
  final FinalCallCard card;
  final bool revealFromBack;
  final bool leavingForReplacement;

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: leavingForReplacement ? const Offset(-2.4, 0) : Offset.zero,
      duration: const Duration(milliseconds: 460),
      curve: Curves.easeInOutCubic,
      child: AnimatedOpacity(
        opacity: leavingForReplacement ? 0 : 1,
        duration: const Duration(milliseconds: 460),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 620),
          curve: Curves.easeOutCubic,
          builder: (context, progress, _) {
            final showFront = !revealFromBack || progress >= 0.5;
            final rotationY = revealFromBack
                ? showFront
                      ? (progress - 1) * math.pi
                      : progress * math.pi
                : 0.0;
            return Transform.translate(
              offset: Offset(40 * (1 - progress), 0),
              child: Opacity(
                opacity: progress,
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0016)
                    ..rotateY(rotationY),
                  // NEW 꼬리표가 카드 밖으로 튀어나와 잘리지 않도록 카드
                  // 둘레에 꼬리표 자리만큼 여백을 두고 그 안에 겹쳐 붙입니다.
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 8, right: 10),
                        child: FinalCallCardView(
                          card: card,
                          faceDown: !showFront,
                          width: cardWidth,
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Transform.rotate(
                          angle: 0.17,
                          child: const FinalCallPopTag(
                            label: 'NEW',
                            color: FinalCallColors.red,
                            textColor: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ③ 다른 사람 차례: 내 점수와 차례 순서
// ---------------------------------------------------------------------------
class FinalCallWaitingPanel extends StatelessWidget {
  const FinalCallWaitingPanel({super.key, required this.controller});

  final FinalCallController controller;

  /// 서버와 같은 규칙(생존자 좌석 오름차순, 순환)으로 지금 차례부터 나열합니다.
  /// CALL 이후 마지막 교체에서는 아직 교체하지 않은 사람만 남깁니다.
  List<FinalCallPlayer> _turnOrder() {
    final alive =
        controller.players.values
            .where((player) => player.status == 'alive')
            .toList()
          ..sort((left, right) => left.seatIndex.compareTo(right.seatIndex));
    final start = alive.indexWhere(
      (player) => player.uid == controller.turnUid,
    );
    final rotated = start < 0
        ? alive
        : [...alive.sublist(start), ...alive.sublist(0, start)];
    if (controller.phase != 'finalTurns') return rotated;
    final pending = controller.finalTurnPendingUids.toSet();
    return [
      for (final player in rotated)
        if (player.uid == controller.turnUid || pending.contains(player.uid))
          player,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final score = finalCallBestCombination(controller.hand).score;
    final myTeam = controller.myTeam;
    final order = _turnOrder();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              FinalCallCopy.myScore,
              style: finalCallPopText(15, color: FinalCallColors.muted),
            ),
            const Spacer(),
            Text(
              '$score',
              style: finalCallPopText(
                44,
                color: FinalCallColors.violet,
                height: 1,
                shadows: finalCallPopOutline(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 3,
          decoration: BoxDecoration(
            color: FinalCallColors.lilac,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          FinalCallCopy.turnOrder,
          style: finalCallPopText(14, color: FinalCallColors.muted),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: finalCallPhonePanelWidth - 28,
              child: Column(
                children: [
                  for (var index = 0; index < order.length; index++)
                    _TurnOrderRow(
                      player: order[index],
                      isCurrent:
                          index == 0 && order[index].uid == controller.turnUid,
                      note: order[index].uid == controller.turnUid
                          ? FinalCallCopy.now
                          : order[index].uid == controller.uid
                          ? FinalCallCopy.turnsLater(index)
                          : order[index].team == myTeam
                          ? FinalCallCopy.partner
                          : null,
                      isMe: order[index].uid == controller.uid,
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TurnOrderRow extends StatelessWidget {
  const _TurnOrderRow({
    required this.player,
    required this.isCurrent,
    required this.note,
    required this.isMe,
  });

  final FinalCallPlayer player;
  final bool isCurrent;
  final String? note;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final teamColor = finalCallTeamColor(player.team);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isCurrent
            ? Color.lerp(Colors.white, teamColor, 0.16)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isCurrent ? FinalCallColors.ink : Colors.transparent,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          FinalCallPopAvatar(
            characterId: player.characterId,
            color: teamColor,
            size: 26,
            borderWidth: 2,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isMe ? FinalCallCopy.me : player.nickname,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: finalCallPopText(16),
            ),
          ),
          if (note != null)
            Text(
              note!,
              style: finalCallPopText(
                13,
                color: isCurrent
                    ? teamColor
                    : isMe
                    ? FinalCallColors.violet
                    : FinalCallColors.muted,
              ),
            ),
        ],
      ),
    );
  }
}
