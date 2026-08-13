import 'package:flutter/material.dart';
import 'package:project00/games/final_call/animations/phone_card_receive_animation.dart';
import 'package:project00/games/final_call/models/final_call_models.dart';
import 'package:project00/games/final_call/widgets/final_call_card_view.dart';

/// 라운드마다 처음에는 한 덱으로 들어오고, 탭한 뒤 펼쳐진 손패를 유지합니다.
class FinalCallPhoneHandCardStack extends StatelessWidget {
  const FinalCallPhoneHandCardStack({
    super.key,
    required this.cards,
    required this.isLandscape,
    required this.isRevealed,
    required this.selectedCardId,
    this.selectedCardIds = const {},
    required this.onRevealStarted,
    required this.onRevealCompleted,
    required this.onCardSelected,
    this.newCardId,
    this.selectionEnabled = false,
  });

  final List<FinalCallCard> cards;
  final bool isLandscape;
  final bool isRevealed;
  final String? selectedCardId;
  final Set<String> selectedCardIds;
  final String? newCardId;
  final bool selectionEnabled;
  final VoidCallback onRevealStarted;
  final VoidCallback onRevealCompleted;
  final ValueChanged<String> onCardSelected;

  @override
  Widget build(BuildContext context) {
    if (!isRevealed) {
      return FinalCallPhoneCardReceiveAnimation(
        key: ValueKey(
          'final-call-deal-${cards.map((card) => card.id).join('-')}',
        ),
        cards: cards,
        isLandscape: isLandscape,
        onRevealStarted: onRevealStarted,
        onCompleted: onRevealCompleted,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = isLandscape
            ? (constraints.maxWidth / 5.1).clamp(64.0, 98.0)
            : (constraints.maxWidth / 4.9).clamp(60.0, 92.0);
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final card in cards)
              GestureDetector(
                onTap: selectionEnabled ? () => onCardSelected(card.id) : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.topCenter,
                    children: [
                      FinalCallCardView(
                        card: card,
                        width: width,
                        selected:
                            selectedCardIds.contains(card.id) ||
                            selectedCardId == card.id,
                      ),
                      if (card.id == newCardId)
                        const Positioned(
                          top: -18,
                          child: Text(
                            'NEW',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              shadows: [
                                Shadow(color: Colors.white, blurRadius: 3),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
