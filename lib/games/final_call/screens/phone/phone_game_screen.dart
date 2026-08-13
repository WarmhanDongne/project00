import 'package:flutter/material.dart';
import 'package:project00/games/final_call/screens/phone/phone_game_controller.dart';
import 'package:project00/games/final_call/widgets/phone/card_change_dialog.dart';
import 'package:project00/games/final_call/widgets/phone/phone_actions.dart';
import 'package:project00/games/final_call/widgets/phone/phone_hand_card_stack.dart';
import 'package:project00/games/final_call/widgets/phone/phone_top_bar.dart';
import 'package:project00/games/final_call/widgets/phone/turn_action_switcher.dart';
import 'package:project00/games/shared/widgets/phone_rule_dialog.dart';
import 'package:project00/gen/assets.gen.dart';

/// 휴대폰의 손패와 조작부를 분리된 두 영역으로 표시합니다.
class PhoneGameScreen extends StatelessWidget {
  const PhoneGameScreen({
    super.key,
    required this.controller,
    required this.handRevealed,
    required this.selectedCardId,
    required this.selectedFinalCardIds,
    required this.visibleCallerUid,
    required this.onRevealStarted,
    required this.onRevealCompleted,
    required this.onSelectedCardChanged,
    required this.onFinalCardSelected,
    required this.onExitRoom,
  });

  final PhoneGameController controller;
  final bool handRevealed;
  final String? selectedCardId;
  final Set<String> selectedFinalCardIds;
  final String? visibleCallerUid;
  final VoidCallback onRevealStarted;
  final VoidCallback onRevealCompleted;
  final ValueChanged<String?> onSelectedCardChanged;
  final ValueChanged<String> onFinalCardSelected;
  final VoidCallback onExitRoom;

  Future<void> _openCardChange(BuildContext context) async {
    final discard = controller.discardCard;
    if (discard == null || !controller.canDraw) return;
    final source = await showDialog<String>(
      context: context,
      barrierColor: Colors.black38,
      builder: (_) => FinalCallCardChangeDialog(
        discardCard: discard,
        canSelectDeck: controller.deckRemainingCount > 0,
      ),
    );
    if (source == null || !context.mounted) return;

    // 모달을 보고 있는 동안 턴이 끝났다면 오래된 명령을 보내지 않습니다.
    if (!controller.canDraw) {
      _showActionError(context, '카드 교체 시간이 종료되었습니다.');
      return;
    }
    final completed = await controller.draw(source);
    if (!completed && context.mounted) {
      _showActionError(context, controller.actionErrorMessage);
    }
  }

  Future<void> _call(BuildContext context) async {
    if (!controller.canCall) return;
    onSelectedCardChanged(null);
    final completed = await controller.call();
    if (!completed && context.mounted) {
      _showActionError(context, controller.actionErrorMessage);
    }
  }

  void _showActionError(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final board = Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 16, 0),
              child: FinalCallPhoneTopBar(
                controller: controller,
                onOutPressed: onExitRoom,
                onBookPressed: () => _showRules(context),
                isLandscape: true,
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  Expanded(flex: 8, child: _buildLandscapeHand()),
                  //=======================손패와 조작부 구분선==============================
                  LayoutBuilder(
                    builder: (context, dividerConstraints) => Center(
                      child: SizedBox(
                        height: dividerConstraints.maxHeight * 0.62,
                        child: const VerticalDivider(
                          width: 1,
                          thickness: 1,
                          color: Color(0x26000000),
                        ),
                      ),
                    ),
                  ),
                  Expanded(flex: 3, child: _buildControl(context)),
                ],
              ),
            ),
          ],
        );

        final waitingForReveal = !handRevealed;
        return Stack(
          fit: StackFit.expand,
          children: [
            Assets.games.finalCall.images.background.phoneBackground.image(
              fit: BoxFit.cover,
            ),
            SafeArea(
              child: waitingForReveal
                  ? FinalCallPhoneHandCardStack(
                      cards: controller.hand,
                      isLandscape: true,
                      isRevealed: false,
                      selectedCardId: null,
                      selectedCardIds: const {},
                      onRevealStarted: onRevealStarted,
                      onRevealCompleted: onRevealCompleted,
                      onCardSelected: (_) {},
                    )
                  : board,
            ),
            if (visibleCallerUid != null && visibleCallerUid != controller.uid)
              _CallNotice(
                nickname:
                    controller.players[visibleCallerUid]?.nickname ?? 'PLAYER',
                profileImageUrl:
                    controller.players[visibleCallerUid]?.profileImageUrl ?? '',
              ),
          ],
        );
      },
    );
  }

  void _showRules(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => const PhoneGameRuleDialog(
        title: 'FINAL CALL',
        rules:
            '같은 숫자 카드의 합과 같은 색 카드의 합 중 더 높은 값이 '
            '최종 점수입니다. 자신의 턴에는 공개 카드 또는 카드 더미에서 '
            '한 장을 가져와 손패와 교체하거나 버릴 수 있습니다.\n\n'
            'CALL을 선언하면 나머지 플레이어가 마지막 교체를 한 번 진행합니다. '
            '가장 낮은 점수의 플레이어는 생명 1개를 잃고, CALL을 선언한 '
            '플레이어가 최하위라면 생명 2개를 잃습니다. 마지막 생존자가 승리합니다.',
        surfaceColor: Color(0xFFF5F4F1),
        foregroundColor: Color(0xFF161616),
      ),
    );
  }

  Widget _buildLandscapeHand() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: FinalCallPhoneHandCardStack(
        cards: controller.hand,
        isLandscape: true,
        isRevealed: handRevealed,
        selectedCardId: selectedCardId,
        selectedCardIds: selectedFinalCardIds,
        newCardId: controller.pendingDraw?.id,
        selectionEnabled:
            controller.canCompleteTurn || controller.canSubmitCallerHand,
        onRevealStarted: onRevealStarted,
        onRevealCompleted: onRevealCompleted,
        onCardSelected: controller.canSubmitCallerHand
            ? onFinalCardSelected
            : (id) {
                onSelectedCardChanged(selectedCardId == id ? null : id);
              },
      ),
    );
  }

  Widget _buildControl(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: FinalCallTurnActionSwitcher(
          isMyTurn: controller.isMyTurn,
          turnPlayer: controller.turnPlayer,
          action: controller.canSubmitCallerHand
              ? _CallerSubmitAction(
                  controller: controller,
                  selectedCardIds: selectedFinalCardIds,
                )
              : FinalCallPhoneActions(
                  controller: controller,
                  selectedCardId: selectedCardId,
                  onOpenCardChange: () => _openCardChange(context),
                  onSelectedCardChanged: onSelectedCardChanged,
                  onCall: () => _call(context),
                ),
        ),
      ),
    );
  }
}

class _CallerSubmitAction extends StatelessWidget {
  const _CallerSubmitAction({
    required this.controller,
    required this.selectedCardIds,
  });
  final PhoneGameController controller;
  final Set<String> selectedCardIds;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '최종 손패를 제출하세요',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: selectedCardIds.length == controller.hand.length
              ? () => controller.submitFinalHand(selectedCardIds.toList())
              : null,
          child: Container(
            width: 92,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selectedCardIds.length == controller.hand.length
                  ? Colors.white
                  : const Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(6),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black38,
                  blurRadius: 8,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Text(
              selectedCardIds.length == controller.hand.length
                  ? '제출'
                  : '${selectedCardIds.length}/4',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ],
    );
  }
}

class _CallNotice extends StatelessWidget {
  const _CallNotice({required this.nickname, required this.profileImageUrl});
  final String nickname;
  final String profileImageUrl;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 20,
      top: 64,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 8),
              ],
            ),
            child: const Text(
              'CALL',
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 19,
                fontWeight: FontWeight.w800,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: SizedBox(
              width: 54,
              height: 54,
              child: profileImageUrl.isEmpty
                  ? const ColoredBox(
                      color: Colors.black12,
                      child: Icon(Icons.person),
                    )
                  : Image.network(
                      profileImageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const ColoredBox(
                        color: Colors.black12,
                        child: Icon(Icons.person),
                      ),
                    ),
            ),
          ),
          Text(
            nickname,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }
}
