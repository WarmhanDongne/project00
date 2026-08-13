import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:project00/games/final_call/controllers/final_call_controller.dart';
import 'package:project00/games/final_call/services/final_call_service.dart';
import 'package:project00/games/final_call/widgets/final_call_card_view.dart';
import 'package:project00/games/final_call/widgets/final_call_result.dart';
import 'package:project00/games/final_call/widgets/final_call_timer.dart';
import 'package:project00/gen/assets.gen.dart';

/// 화면 방향이 바뀌어도 같은 컨트롤러와 Firebase 구독을 유지합니다.
class FinalCallPhoneGame extends StatefulWidget {
  const FinalCallPhoneGame({
    super.key,
    required this.roomCode,
    required this.service,
    required this.onExitRoom,
  });

  final String roomCode;
  final FinalCallService service;
  final Future<bool> Function() onExitRoom;

  @override
  State<FinalCallPhoneGame> createState() => _FinalCallPhoneGameState();
}

class _FinalCallPhoneGameState extends State<FinalCallPhoneGame> {
  FinalCallController? controller;
  String? initializationError;
  String? selectedCardId;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      initializationError = '게임에 참여하려면 사용자 인증이 필요합니다.';
      return;
    }
    controller = FinalCallController(
      roomCode: widget.roomCode,
      uid: uid,
      service: widget.service,
    )..initialize();
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  Future<void> _leaveRoom() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (_) => const _ExitDialog(),
    );
    if (leave != true || !mounted) return;
    final left = await widget.onExitRoom();
    if (left && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final game = controller;
    if (game == null) {
      return Scaffold(
        body: Center(child: Text(initializationError ?? '게임을 열 수 없습니다.')),
      );
    }
    return AnimatedBuilder(
      animation: game,
      builder: (context, _) {
        if (selectedCardId != null &&
            !game.hand.any((card) => card.id == selectedCardId)) {
          selectedCardId = null;
        }
        return Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              Assets.games.finalCall.images.background.phoneBackground.image(
                fit: BoxFit.cover,
              ),
              SafeArea(
                child: game.loading
                    ? const SizedBox.shrink()
                    : OrientationBuilder(
                        builder: (context, orientation) {
                          return _GameContent(
                            controller: game,
                            selectedCardId: selectedCardId,
                            onSelectCard: (id) => setState(() {
                              selectedCardId = selectedCardId == id ? null : id;
                            }),
                            onLeave: _leaveRoom,
                            landscape: orientation == Orientation.landscape,
                          );
                        },
                      ),
              ),
              if (game.commandInFlight)
                const Positioned(
                  right: 14,
                  bottom: 14,
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              if (game.phase == 'roundResult' && game.roundResult != null)
                _RoundResult(controller: game),
              if (game.isFinished)
                FinalCallResultOverlay(
                  winner: game.players[game.winnerUid],
                  showActions: false,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _GameContent extends StatelessWidget {
  const _GameContent({
    required this.controller,
    required this.selectedCardId,
    required this.onSelectCard,
    required this.onLeave,
    required this.landscape,
  });
  final FinalCallController controller;
  final String? selectedCardId;
  final ValueChanged<String> onSelectCard;
  final VoidCallback onLeave;
  final bool landscape;

  @override
  Widget build(BuildContext context) {
    final hand = _Hand(
      controller: controller,
      selectedCardId: selectedCardId,
      onSelectCard: onSelectCard,
      compact: landscape,
    );
    final actions = _Actions(
      controller: controller,
      selectedCardId: selectedCardId,
      compact: landscape,
    );
    return Column(
      children: [
        _Header(controller: controller, onLeave: onLeave, compact: landscape),
        Expanded(
          child: landscape
              ? Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: _TurnAndDraw(
                        controller: controller,
                        compact: true,
                      ),
                    ),
                    Expanded(
                      flex: 7,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [hand, const SizedBox(height: 8), actions],
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    const Spacer(),
                    _TurnAndDraw(controller: controller),
                    const Spacer(),
                    hand,
                    const SizedBox(height: 16),
                    actions,
                    const SizedBox(height: 18),
                  ],
                ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.controller,
    required this.onLeave,
    required this.compact,
  });
  final FinalCallController controller;
  final VoidCallback onLeave;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final me = controller.players[controller.uid];
    return Padding(
      padding: EdgeInsets.fromLTRB(18, compact ? 5 : 14, 14, 4),
      child: SizedBox(
        height: compact ? 40 : 56,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (controller.turnDeadlineAt != null &&
                controller.phase != 'roundResult')
              FinalCallTimer(
                key: ValueKey(controller.turnDeadlineAt),
                deadline: controller.turnDeadlineAt!,
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'ROUND ${controller.round}',
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var index = 0; index < (me?.lives ?? 0); index++)
                    Padding(
                      padding: const EdgeInsets.only(right: 3),
                      child: Assets.games.finalCall.images.icons.iconHeart
                          .image(width: compact ? 15 : 19),
                    ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: onLeave,
                    child: Assets.games.finalCall.images.icons.iconOut.image(
                      width: compact ? 27 : 34,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TurnAndDraw extends StatelessWidget {
  const _TurnAndDraw({required this.controller, this.compact = false});
  final FinalCallController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final turn = controller.turnPlayer;
    final text = controller.phase == 'dealing'
        ? '카드를 나누는 중입니다'
        : controller.phase == 'finalTurns' &&
              controller.callerUid == controller.uid
        ? '다른 플레이어의 마지막 교체를 기다리는 중...'
        : controller.isMyTurn
        ? controller.pendingDraw == null
              ? '가져올 카드를 선택하세요'
              : '교체할 손패를 선택하거나 그대로 버리세요'
        : '${turn?.nickname ?? '다른 플레이어'}의 턴';
    final cardWidth = compact ? 60.0 : 82.0;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          child: Text(
            text,
            key: ValueKey(text),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _DrawChoice(
              label: 'DECK\n${controller.deckRemainingCount}',
              enabled: controller.canDraw,
              onTap: () => controller.draw('deck'),
              child: FinalCallCardView(faceDown: true, width: cardWidth),
            ),
            SizedBox(width: compact ? 14 : 24),
            _DrawChoice(
              label: '공개 카드',
              enabled: controller.canDraw,
              onTap: () => controller.draw('discard'),
              child: FinalCallCardView(
                card: controller.discardCard,
                width: cardWidth,
              ),
            ),
            if (controller.pendingDraw != null) ...[
              SizedBox(width: compact ? 14 : 24),
              _DrawChoice(
                label: '가져온 카드',
                enabled: false,
                onTap: () {},
                child: FinalCallCardView(
                  card: controller.pendingDraw,
                  width: cardWidth,
                  selected: true,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _DrawChoice extends StatelessWidget {
  const _DrawChoice({
    required this.label,
    required this.enabled,
    required this.onTap,
    required this.child,
  });
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        opacity: enabled || label == '가져온 카드' ? 1 : 0.7,
        duration: const Duration(milliseconds: 150),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            child,
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hand extends StatelessWidget {
  const _Hand({
    required this.controller,
    required this.selectedCardId,
    required this.onSelectCard,
    required this.compact,
  });
  final FinalCallController controller;
  final String? selectedCardId;
  final ValueChanged<String> onSelectCard;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final width = (available / 5.3).clamp(56.0, compact ? 80.0 : 96.0);
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final card in controller.hand)
              GestureDetector(
                onTap: controller.canCompleteTurn
                    ? () => onSelectCard(card.id)
                    : null,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: compact ? 3 : 4),
                  child: FinalCallCardView(
                    card: card,
                    width: width,
                    selected: selectedCardId == card.id,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.controller,
    required this.selectedCardId,
    required this.compact,
  });
  final FinalCallController controller;
  final String? selectedCardId;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ImageButton(
          enabled: controller.canCall,
          width: compact ? 84 : 112,
          onTap: controller.call,
          image: Assets.games.finalCall.images.button.buttonCall,
        ),
        SizedBox(width: compact ? 10 : 18),
        _ImageButton(
          enabled: controller.canCompleteTurn && selectedCardId != null,
          width: compact ? 84 : 112,
          onTap: () => controller.completeTurn(selectedCardId),
          image: Assets.games.finalCall.images.button.buttonCardChange,
        ),
        SizedBox(width: compact ? 8 : 12),
        _DiscardButton(
          enabled: controller.canCompleteTurn,
          compact: compact,
          onTap: () => controller.completeTurn(null),
        ),
      ],
    );
  }
}

class _DiscardButton extends StatefulWidget {
  const _DiscardButton({
    required this.enabled,
    required this.compact,
    required this.onTap,
  });
  final bool enabled;
  final bool compact;
  final Future<bool> Function() onTap;

  @override
  State<_DiscardButton> createState() => _DiscardButtonState();
}

class _DiscardButtonState extends State<_DiscardButton> {
  bool pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.enabled ? (_) => setState(() => pressed = true) : null,
      onTapCancel: widget.enabled
          ? () => setState(() => pressed = false)
          : null,
      onTapUp: widget.enabled
          ? (_) {
              setState(() => pressed = false);
              widget.onTap();
            }
          : null,
      child: AnimatedScale(
        scale: pressed ? 0.92 : 1,
        duration: const Duration(milliseconds: 100),
        child: AnimatedOpacity(
          opacity: widget.enabled ? 1 : 0.32,
          duration: const Duration(milliseconds: 150),
          child: Container(
            width: widget.compact ? 58 : 72,
            height: widget.compact ? 36 : 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(7),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x44000000),
                  blurRadius: 8,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: const Text(
              '버리기',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ),
    );
  }
}

class _ImageButton extends StatefulWidget {
  const _ImageButton({
    required this.enabled,
    required this.width,
    required this.onTap,
    required this.image,
  });
  final bool enabled;
  final double width;
  final Future<bool> Function() onTap;
  final AssetGenImage image;

  @override
  State<_ImageButton> createState() => _ImageButtonState();
}

class _ImageButtonState extends State<_ImageButton> {
  bool pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.enabled ? (_) => setState(() => pressed = true) : null,
      onTapCancel: widget.enabled
          ? () => setState(() => pressed = false)
          : null,
      onTapUp: widget.enabled
          ? (_) {
              setState(() => pressed = false);
              widget.onTap();
            }
          : null,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 100),
        scale: pressed ? 0.91 : 1,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: widget.enabled ? 1 : 0.32,
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 12,
                  offset: Offset(0, 7),
                ),
              ],
            ),
            child: widget.image.image(width: widget.width),
          ),
        ),
      ),
    );
  }
}

class _RoundResult extends StatelessWidget {
  const _RoundResult({required this.controller});
  final FinalCallController controller;

  @override
  Widget build(BuildContext context) {
    final result = controller.roundResult!;
    final players = controller.players.values.toList()
      ..sort((a, b) => a.seatIndex.compareTo(b.seatIndex));
    return ColoredBox(
      color: const Color(0xECFFFFFF),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  result.automaticCall ? 'AUTO CALL' : 'ROUND RESULT',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 16),
                for (final player in players)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 5,
                      horizontal: 28,
                    ),
                    child: Row(
                      children: [
                        Expanded(child: Text(player.nickname)),
                        Text('${result.scores[player.uid] ?? 0}점'),
                        const SizedBox(width: 14),
                        Text(
                          result.lifeLosses[player.uid] == null
                              ? '-'
                              : '♥ -${result.lifeLosses[player.uid]}',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 10),
                const Text('다음 라운드를 기다려주세요.'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExitDialog extends StatelessWidget {
  const _ExitDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Assets.games.finalCall.images.modal.modalImageDoor.image(width: 80),
          const SizedBox(width: 16),
          const Flexible(child: Text('게임에서 나가시겠습니까?')),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('나가기'),
        ),
      ],
    );
  }
}
