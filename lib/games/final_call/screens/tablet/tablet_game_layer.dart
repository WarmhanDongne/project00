import 'package:flutter/material.dart';
import 'package:project00/games/liars_poker/animations/card_deal.dart';
import 'package:project00/games/final_call/animations/tablet_center_card_reveal.dart';
import 'package:project00/games/final_call/models/final_call_models.dart';
import 'package:project00/games/final_call/screens/phone/phone_game_controller.dart';
import 'package:project00/games/final_call/screens/tablet/tablet_game_helper.dart';
import 'package:project00/games/final_call/widgets/final_call_card_view.dart';
import 'package:project00/gen/assets.gen.dart';

/// 중앙 덱과 라운드 공개 손패만 그리는 아이패드 보드 레이어입니다.
class FinalCallTabletGameLayer extends StatelessWidget {
  const FinalCallTabletGameLayer({super.key, required this.controller});
  final PhoneGameController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.phase == 'dealing') {
      final players =
          controller.players.values
              .where((player) => player.status == 'alive')
              .toList()
            ..sort((left, right) => left.seatIndex.compareTo(right.seatIndex));
      if (players.isEmpty) return const SizedBox.shrink();

      //=======================태블릿 카드 배분==============================
      return CardDealAnimation(
        key: ValueKey('final-call-deal-${controller.round}'),
        playerCount: players.length,
        playerSeatIndexes: List<int>.generate(players.length, (index) => index),
        cardsPerPlayer: 4,
        cardAsset: Assets.games.finalCall.images.cards.cardBack,
        cardWidth: 118,
        duration: const Duration(milliseconds: 2800),
        onCompleted: () => controller.completeDealing(),
      );
    }

    final result = controller.roundResult;
    if (result == null) {
      return Center(
        child: FinalCallCenterCardReveal(
          key: ValueKey(
            'center-card-${controller.round}-${controller.discardCard?.id}',
          ),
          card: controller.discardCard,
        ),
      );
    }
    return _RevealedTable(controller: controller, result: result);
  }
}

class _RevealedTable extends StatelessWidget {
  const _RevealedTable({required this.controller, required this.result});
  final PhoneGameController controller;
  final FinalCallRoundResult result;

  @override
  Widget build(BuildContext context) {
    final players = controller.players.values.toList()
      ..sort((left, right) => left.seatIndex.compareTo(right.seatIndex));
    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: FinalCallCenterCardReveal(
            key: ValueKey(
              'result-center-card-${controller.round}-${controller.discardCard?.id}',
            ),
            card: controller.discardCard,
            cardWidth: 86,
          ),
        ),
        for (var index = 0; index < players.length; index++)
          Align(
            alignment: finalCallSeatAlignment(index, players.length),
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Transform.rotate(
                angle: finalCallSeatRotation(index, players.length),
                child: _RevealedHand(
                  cards: result.revealedHands[players[index].uid] ?? const [],
                  score: result.scores[players[index].uid] ?? 0,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _RevealedHand extends StatelessWidget {
  const _RevealedHand({required this.cards, required this.score});
  final List<FinalCallCard> cards;
  final int score;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final card in cards)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: FinalCallCardView(card: card, width: 64),
              ),
          ],
        ),
        const SizedBox(height: 7),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)],
          ),
          child: Text(
            '$score',
            style: TextStyle(
              color: score <= 10 ? Colors.red : const Color(0xFF244EB8),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
