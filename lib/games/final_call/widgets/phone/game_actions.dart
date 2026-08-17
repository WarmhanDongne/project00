import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:project00/games/final_call/final_call_copy.dart';
import 'package:project00/games/final_call/models/final_call_models.dart';
import 'package:project00/games/final_call/controllers/final_call_controller.dart';
import 'package:project00/games/final_call/widgets/final_call_card_view.dart';
import 'package:project00/gen/assets.gen.dart';

class FinalCallPhoneActions extends StatelessWidget {
  const FinalCallPhoneActions({
    super.key,
    required this.controller,
    required this.selectedCardId,
    required this.onOpenCardChange,
    required this.onCall,
    required this.onCompleteTurn,
    required this.replacementInProgress,
  });

  final FinalCallController controller;
  final String? selectedCardId;
  final VoidCallback onOpenCardChange;
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
    if (controller.phase == 'finalTurns') {
      // CALL 이후 자동 카드 선택창을 바깥 탭으로 닫아도 다시 열 수 있어야
      // 하므로 마지막 교체 턴에서는 새 카드 버튼을 계속 유지합니다.
      return _PressableImageButton(
        enabled: controller.canDraw,
        asset: Assets.games.finalCall.images.button.buttonBasicWide,
        labelOverride: FinalCallCopy.newCard,
        onTap: onOpenCardChange,
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PressableImageButton(
          enabled: controller.canCall,
          asset: Assets.games.finalCall.images.button.buttonBasicWide,
          labelOverride: 'CALL',
          onTap: onCall,
        ),
        const SizedBox(height: 12),
        _PressableImageButton(
          enabled: controller.canDraw,
          asset: Assets.games.finalCall.images.button.buttonBasicWide,
          labelOverride: FinalCallCopy.newCard,
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PendingCardEntry(
          key: ValueKey('pending-${card.id}-${controller.pendingDrawSource}'),
          card: card,
          revealFromBack: controller.pendingDrawSource == 'deck',
          leavingForReplacement:
              replacementInProgress && selectedCardId != null,
        ),
        const SizedBox(height: 9),
        _WhiteActionButton(
          // 마지막 교체를 최종 제출로 오해하지 않도록 두 동작의 버튼
          // 문구를 분리합니다. 이 버튼이 끝난 뒤 별도 최종 제출 UI가 열립니다.
          label: selectedCardId == null
              ? FinalCallCopy.discard
              : FinalCallCopy.replace,
          enabled: !replacementInProgress,
          onTap: () => onCompleteTurn(selectedCardId),
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
    this.labelOverride,
  });
  final bool enabled;
  final AssetGenImage asset;
  final VoidCallback onTap;
  final String? labelOverride;

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
            //=======================그림자 안전 여백==============================
            // 버튼 면보다 넓은 페인트 영역을 확보해 하단 베이스와 그림자가
            // FittedBox 또는 전환 위젯 경계에서 잘리지 않게 합니다.
            width: 154,
            height: 122,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                //=======================버튼 하단 베이스==============================
                Positioned(
                  top: 9,
                  child: Container(
                    width: 132,
                    height: 99,
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
                    width: 132,
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
                    child: Stack(
                      fit: StackFit.passthrough,
                      alignment: Alignment.center,
                      children: [
                        widget.asset.image(
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                        ),
                        if (widget.labelOverride != null)
                          Center(
                            child: Text(
                              widget.labelOverride!,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                                shadows: [
                                  Shadow(
                                    color: Color(0x22000000),
                                    offset: Offset(2, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
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
  const _WhiteActionButton({
    required this.label,
    required this.onTap,
    this.enabled = true,
  });
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        opacity: enabled ? 1 : 0.45,
        duration: const Duration(milliseconds: 150),
        child: Container(
          width: 102,
          height: 47,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(7),
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
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}

/// 덱에서 가져온 카드는 뒷면으로 들어온 뒤 회전해 공개하고, 공개 카드에서
/// 가져온 경우에는 앞면 그대로 조작부에 들어옵니다.
class _PendingCardEntry extends StatefulWidget {
  const _PendingCardEntry({
    super.key,
    required this.card,
    required this.revealFromBack,
    required this.leavingForReplacement,
  });

  final FinalCallCard card;
  final bool revealFromBack;
  final bool leavingForReplacement;

  @override
  State<_PendingCardEntry> createState() => _PendingCardEntryState();
}

class _PendingCardEntryState extends State<_PendingCardEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: widget.leavingForReplacement
          ? const Offset(-2.4, 0)
          : Offset.zero,
      duration: const Duration(milliseconds: 460),
      curve: Curves.easeInOutCubic,
      child: AnimatedOpacity(
        opacity: widget.leavingForReplacement ? 0 : 1,
        duration: const Duration(milliseconds: 460),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final progress = Curves.easeOutCubic.transform(_controller.value);
            final showFront = !widget.revealFromBack || progress >= 0.5;
            final rotationY = widget.revealFromBack
                ? showFront
                      ? (progress - 1) * math.pi
                      : progress * math.pi
                : 0.0;
            return Transform.translate(
              offset: Offset(58 * (1 - progress), 0),
              child: Opacity(
                opacity: progress,
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0016)
                    ..rotateY(rotationY),
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.topCenter,
                    children: [
                      FinalCallCardView(
                        card: widget.card,
                        faceDown: !showFront,
                        width: 98,
                      ),
                      const Positioned(
                        top: -20,
                        child: Text(
                          'NEW',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
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
