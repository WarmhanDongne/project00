// [public_state_mapper.dart] RTDB 공개 상태의 복합 값을 파이널 콜 모델로
// 변환하는 순수 파서입니다. 구독과 상태 발행은 controller가 계속 소유합니다.

import 'package:game_final_call/shared/models/game_models.dart';
import 'package:game_kit/recovery/models/game_interruption.dart';

FinalCallCard? parseFinalCallCard(Object? value) {
  if (value is! Map) return null;
  return FinalCallCard.fromMap(Map<Object?, Object?>.from(value));
}

Map<String, FinalCallPlayer> parseFinalCallPlayers(Object? value) {
  if (value is! Map) return const {};
  final players = <String, FinalCallPlayer>{};
  for (final entry in value.entries) {
    if (entry.value is! Map) continue;
    players[entry.key.toString()] = FinalCallPlayer.fromMap(
      entry.key.toString(),
      Map<Object?, Object?>.from(entry.value as Map),
    );
  }
  return players;
}

List<String> parseFinalCallStringCollection(Object? value) {
  if (value is List) {
    return value.map((item) => item.toString()).toList(growable: false);
  }
  if (value is Map) {
    return value.values.map((item) => item.toString()).toList(growable: false);
  }
  return const [];
}

FinalCallRoundResult? parseFinalCallRoundResult(Object? value) {
  if (value is! Map) return null;
  return FinalCallRoundResult.fromMap(Map<Object?, Object?>.from(value));
}

GameInterruption? parseFinalCallInterruption(Object? value) {
  if (value is! Map) return null;
  return GameInterruption.fromMap(Map<Object?, Object?>.from(value));
}

FinalCallTeam? parseFinalCallWinningTeam(Object? value) {
  if (value == null) return null;
  return FinalCallTeam.fromWire(value, seatIndex: 0);
}
