import 'package:flutter/material.dart';
import 'package:project00/games/final_call/models/final_call_models.dart';
import 'package:project00/gen/assets.gen.dart';

AssetGenImage finalCallCardAsset(FinalCallCard card) {
  final suffix = '${card.color}_${card.value}.png';
  return Assets.games.finalCall.images.cards.values.firstWhere(
    (asset) => asset.path.endsWith(suffix),
    orElse: () => Assets.games.finalCall.images.cards.cardBack,
  );
}

class FinalCallCardView extends StatelessWidget {
  const FinalCallCardView({
    super.key,
    this.card,
    this.faceDown = false,
    this.width = 92,
    this.selected = false,
  });

  final FinalCallCard? card;
  final bool faceDown;
  final double width;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final asset = faceDown || card == null
        ? Assets.games.finalCall.images.cards.cardBack
        : finalCallCardAsset(card!);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      transform: Matrix4.translationValues(0, selected ? -12 : 0, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),
        boxShadow: [
          BoxShadow(
            color: selected ? const Color(0xAAE0B75C) : Colors.black45,
            blurRadius: selected ? 16 : 8,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: asset.image(
        width: width,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}
