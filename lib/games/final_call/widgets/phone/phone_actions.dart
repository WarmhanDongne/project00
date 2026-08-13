import 'package:flutter/material.dart';
import 'package:project00/games/final_call/screens/phone/phone_game_controller.dart';
import 'package:project00/games/final_call/widgets/final_call_card_view.dart';
import 'package:project00/gen/assets.gen.dart';

class FinalCallPhoneActions extends StatelessWidget {
  const FinalCallPhoneActions({
    super.key,
    required this.controller,
    required this.selectedCardId,
    required this.onOpenCardChange,
    required this.onSelectedCardChanged,
    required this.onCall,
  });

  final PhoneGameController controller;
  final String? selectedCardId;
  final VoidCallback onOpenCardChange;
  final ValueChanged<String?> onSelectedCardChanged;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    if (controller.pendingDraw != null) {
      return _PendingCardAction(
        controller: controller,
        selectedCardId: selectedCardId,
        onSelectedCardChanged: onSelectedCardChanged,
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PressableImageButton(
          enabled: controller.canCall,
          asset: Assets.games.finalCall.images.button.buttonCall,
          onTap: onCall,
        ),
        const SizedBox(height: 10),
        _PressableImageButton(
          enabled: controller.canDraw,
          asset: Assets.games.finalCall.images.button.buttonCardChange,
          onTap: onOpenCardChange,
        ),
      ],
    );
  }
}

class _PendingCardAction extends StatelessWidget {
  const _PendingCardAction({
    required this.controller,
    required this.selectedCardId,
    required this.onSelectedCardChanged,
  });

  final PhoneGameController controller;
  final String? selectedCardId;
  final ValueChanged<String?> onSelectedCardChanged;

  @override
  Widget build(BuildContext context) {
    final card = controller.pendingDraw!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            FinalCallCardView(card: card, width: 82),
            const Positioned(
              top: -18,
              child: Text(
                'NEW',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        _WhiteActionButton(
          label: controller.phase == 'finalTurns'
              ? '제출'
              : selectedCardId == null
              ? '버리기'
              : '대체',
          onTap: () async {
            final completed = await controller.completeTurn(selectedCardId);
            if (completed) onSelectedCardChanged(null);
          },
        ),
      ],
    );
  }
}

class _PressableImageButton extends StatefulWidget {
  const _PressableImageButton({
    required this.enabled,
    required this.asset,
    required this.onTap,
  });
  final bool enabled;
  final AssetGenImage asset;
  final VoidCallback onTap;

  @override
  State<_PressableImageButton> createState() => _PressableImageButtonState();
}

class _PressableImageButtonState extends State<_PressableImageButton> {
  bool pressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: widget.enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.enabled ? widget.onTap : null,
        onTapDown: widget.enabled ? (_) => _setPressed(true) : null,
        onTapCancel: widget.enabled ? () => _setPressed(false) : null,
        onTapUp: widget.enabled ? (_) => _setPressed(false) : null,
        child: AnimatedOpacity(
          opacity: widget.enabled ? 1 : 0.32,
          duration: const Duration(milliseconds: 150),
          child: SizedBox(
            width: 104,
            height: 84,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                //=======================버튼 하단 베이스==============================
                Positioned(
                  top: 7,
                  child: Container(
                    width: 100,
                    height: 76,
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B8B8B),
                      borderRadius: BorderRadius.circular(17),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x52000000),
                          blurRadius: 8,
                          spreadRadius: 1,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                  ),
                ),
                //=======================눌리는 버튼 면==============================
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 90),
                  curve: Curves.easeOutCubic,
                  top: pressed ? 6 : 0,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 90),
                    curve: Curves.easeOutCubic,
                    width: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(17),
                      boxShadow: [
                        BoxShadow(
                          color: pressed
                              ? const Color(0x28000000)
                              : const Color(0x42000000),
                          blurRadius: pressed ? 2 : 7,
                          offset: Offset(0, pressed ? 1 : 4),
                        ),
                        if (!pressed)
                          const BoxShadow(
                            color: Color(0x99FFFFFF),
                            blurRadius: 3,
                            offset: Offset(0, -2),
                          ),
                      ],
                    ),
                    child: widget.asset.image(
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _setPressed(bool value) {
    if (!mounted || pressed == value) return;
    setState(() => pressed = value);
  }
}

class _WhiteActionButton extends StatelessWidget {
  const _WhiteActionButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 84,
        height: 39,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          boxShadow: const [
            BoxShadow(
              color: Colors.black38,
              blurRadius: 7,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
