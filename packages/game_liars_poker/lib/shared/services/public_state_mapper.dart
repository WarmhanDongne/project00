// [public_state_mapper.dart] RTDB 공개 상태의 느슨한 Map 값을
// 라이어스 포커 모델과 안전한 기본형으로 변환하는 순수 파서입니다.
// 구독, 상태 발행, 타이머, 화면 연출은 이 파일에서 처리하지 않습니다.

import 'package:game_liars_poker/shared/models/game_models.dart';

String liarsPokerString(Object? value, {required String fallback}) {
  return value is String && value.isNotEmpty ? value : fallback;
}

String? liarsPokerNullableString(Object? value) {
  return value is String && value.isNotEmpty ? value : null;
}

int? liarsPokerInteger(Object? value) {
  return value is int ? value : (value is num ? value.toInt() : null);
}

List<String> liarsPokerStringList(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<String>()
      .map((cardValue) => cardValue.toUpperCase())
      .toList(growable: false);
}

Map<String, PhoneGamePlayer> parseLiarsPokerPlayers(Object? value) {
  if (value is! Map) return const {};

  final result = <String, PhoneGamePlayer>{};
  for (final entry in value.entries) {
    if (entry.value is! Map) continue;
    final player = PhoneGamePlayer.fromMap(
      entry.key.toString(),
      Map<Object?, Object?>.from(entry.value as Map),
    );
    result[player.uid] = player;
  }
  return result;
}

PhonePenaltyResult? parseLiarsPokerPenaltyResult(Object? value) {
  if (value is! Map) return null;
  return PhonePenaltyResult.fromMap(Map<Object?, Object?>.from(value));
}

class LiarsPokerLastPlaySnapshot {
  const LiarsPokerLastPlaySnapshot({
    this.playId,
    this.playerUid,
    this.revealed = false,
    this.cardCount = 0,
    this.actualCardValues = const [],
  });

  factory LiarsPokerLastPlaySnapshot.fromValue(Object? value) {
    if (value is! Map) return const LiarsPokerLastPlaySnapshot();
    final map = Map<Object?, Object?>.from(value);
    return LiarsPokerLastPlaySnapshot(
      playId: liarsPokerNullableString(map['playId']),
      playerUid: liarsPokerNullableString(map['playerUid']),
      revealed: map['revealed'] == true,
      cardCount: liarsPokerInteger(map['cardCount']) ?? 0,
      // 서버 필드명은 이전 계약 호환 때문에 actualRanks를 유지합니다.
      actualCardValues: liarsPokerStringList(map['actualRanks']),
    );
  }

  final String? playId;
  final String? playerUid;
  final bool revealed;
  final int cardCount;
  final List<String> actualCardValues;
}
