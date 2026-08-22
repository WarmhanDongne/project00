import 'package:flutter/material.dart';
import 'package:project00/games/final_call/models/final_call_models.dart';
import 'package:project00/gen/assets.gen.dart';
import 'package:project00/core/assets/game_image.dart';

/// Final Call 앞면 카드 원본(700 × 1026)의 높이/너비 비율입니다.
const double finalCallCardHeightRatio = 1026 / 700;

GameImage finalCallCardAsset(FinalCallCard card) {
  // 에셋 압축(2026-08-22)으로 확장자가 webp가 됐습니다.
  final suffix = '${card.color}_${card.value}.webp';
  return Assets.games.finalCall.images.cards.values
      .firstWhere(
        (asset) => asset.path.endsWith(suffix),
        orElse: () => Assets.games.finalCall.images.cards.cardBack,
      )
      .game;
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
        ? Assets.games.finalCall.images.cards.cardBack.game
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
