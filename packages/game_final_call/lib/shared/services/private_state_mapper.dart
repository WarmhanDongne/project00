// [private_state_mapper.dart] 파이널 콜 개인 snapshot을 손패와 대기 카드로
// 변환하는 순수 파서입니다. 기존 슬롯 보존은 화면 상태를 아는 controller가 담당합니다.

import 'package:game_final_call/shared/models/game_models.dart';

class FinalCallPrivateSnapshot {
  const FinalCallPrivateSnapshot({
    required this.hand,
    required this.pendingDraw,
  });

  factory FinalCallPrivateSnapshot.fromValue(Object? value) {
    final cards = <FinalCallCard>[];
    FinalCallCard? pendingDraw;
    if (value is Map) {
      final map = Map<Object?, Object?>.from(value);
      final rawHand = map['hand'];
      if (rawHand is Map) {
        for (final raw in rawHand.values) {
          if (raw is! Map) continue;
          cards.add(FinalCallCard.fromMap(Map<Object?, Object?>.from(raw)));
        }
      }
      final rawPending = map['pendingDraw'];
      if (rawPending is Map) {
        pendingDraw = FinalCallCard.fromMap(
          Map<Object?, Object?>.from(rawPending),
        );
      }
    }
    return FinalCallPrivateSnapshot(hand: cards, pendingDraw: pendingDraw);
  }

  final List<FinalCallCard> hand;
  final FinalCallCard? pendingDraw;
}
