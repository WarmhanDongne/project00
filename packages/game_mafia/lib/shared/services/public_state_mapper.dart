// [public_state_mapper.dart] RTDB 공개 상태의 복합 값을 마피아 모델로
// 변환하는 순수 파서입니다. 게임 규칙 판정과 구독은 포함하지 않습니다.

import 'package:game_kit/recovery/models/game_interruption.dart';
import 'package:game_mafia/shared/models/player.dart';
import 'package:game_mafia/shared/models/state_models.dart';

Map<String, MafiaPlayer> parseMafiaPlayers(Object? value) {
  if (value is! Map) return const {};
  final players = <MafiaPlayer>[];
  for (final entry in value.entries) {
    if (entry.value is! Map) continue;
    players.add(
      MafiaPlayer.fromMap(
        entry.key.toString(),
        Map<Object?, Object?>.from(entry.value as Map),
      ),
    );
  }
  players.sort((left, right) => left.seatIndex.compareTo(right.seatIndex));
  return <String, MafiaPlayer>{
    for (final player in players) player.uid: player,
  };
}

Map<String, String> parseMafiaStringMap(Object? value) {
  if (value is! Map) return const {};
  return <String, String>{
    for (final entry in value.entries)
      entry.key.toString(): entry.value.toString(),
  };
}

MafiaMorningResult? parseMafiaMorningResult(Object? value) {
  if (value is! Map) return null;
  return MafiaMorningResult.fromMap(Map<Object?, Object?>.from(value));
}

MafiaVoteResult? parseMafiaVoteResult(Object? value) {
  if (value is! Map) return null;
  return MafiaVoteResult.fromMap(Map<Object?, Object?>.from(value));
}

GameInterruption? parseMafiaInterruption(Object? value) {
  if (value is! Map) return null;
  return GameInterruption.fromMap(Map<Object?, Object?>.from(value));
}
