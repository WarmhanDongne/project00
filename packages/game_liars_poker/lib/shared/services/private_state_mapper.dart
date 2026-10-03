// [private_state_mapper.dart] 개인 손패 snapshot을 안정적인 카드 목록으로
// 변환하는 순수 파서입니다. 카드 표시 순서는 ID 기준으로 고정합니다.

import 'package:game_liars_poker/shared/models/game_models.dart';

List<PhoneHandCard> parseLiarsPokerHand(Object? value) {
  final cards = <PhoneHandCard>[];
  if (value is Map) {
    for (final entry in value.entries) {
      if (entry.value is! Map) continue;
      final card = PhoneHandCard.fromMap(
        entry.key.toString(),
        Map<Object?, Object?>.from(entry.value as Map),
      );
      if (card != null) cards.add(card);
    }
  }
  cards.sort((left, right) => left.id.compareTo(right.id));
  return cards;
}
