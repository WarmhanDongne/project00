import 'package:flutter/material.dart';
import 'package:project00/games/final_call/models/final_call_models.dart';
import 'package:project00/games/final_call/widgets/final_call_card_view.dart';
import 'package:project00/gen/assets.gen.dart';

/// 태블릿 중앙의 비공개 덱 또는 공개 카드를 선택하는 교체 모달입니다.
class FinalCallCardChangeDialog extends StatefulWidget {
  const FinalCallCardChangeDialog({
    super.key,
    required this.discardCard,
    required this.canSelectDeck,
  });

  final FinalCallCard discardCard;
  final bool canSelectDeck;

  @override
  State<FinalCallCardChangeDialog> createState() =>
      _FinalCallCardChangeDialogState();
}

class _FinalCallCardChangeDialogState extends State<FinalCallCardChangeDialog> {
  String? source;

  @override
  Widget build(BuildContext context) {
    final landscape =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;
    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: landscape ? 80 : 16,
        vertical: 24,
      ),
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 620),
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 16),
        decoration: BoxDecoration(
          image: DecorationImage(
            image: Assets.games.finalCall.images.background.phoneBackground
                .provider(),
            fit: BoxFit.cover,
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 16)],
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 72,
              child: Text(
                '카드\n교체',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
              ),
            ),
            const VerticalDivider(color: Colors.black26, thickness: 1),
            const SizedBox(width: 10),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ModalCard(
                    selected: source == 'deck',
                    enabled: widget.canSelectDeck,
                    onTap: () => setState(() => source = 'deck'),
                    child: const FinalCallCardView(faceDown: true, width: 72),
                  ),
                  const SizedBox(width: 12),
                  _ModalCard(
                    selected: source == 'discard',
                    enabled: true,
                    onTap: () => setState(() => source = 'discard'),
                    child: FinalCallCardView(
                      card: widget.discardCard,
                      width: 72,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: source == null
                  ? null
                  : () => Navigator.pop(context, source),
              child: AnimatedOpacity(
                opacity: source == null ? 0.35 : 1,
                duration: const Duration(milliseconds: 150),
                child: Container(
                  width: 72,
                  height: 92,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(7),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black38,
                        blurRadius: 8,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Text(
                    '확인',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModalCard extends StatelessWidget {
  const _ModalCard({
    required this.selected,
    required this.enabled,
    required this.onTap,
    required this.child,
  });
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        opacity: enabled ? 1 : 0.35,
        duration: const Duration(milliseconds: 150),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? const Color(0xFFE3D400) : Colors.transparent,
              width: 3,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: child,
        ),
      ),
    );
  }
}
