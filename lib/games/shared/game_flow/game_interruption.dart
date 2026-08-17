import 'package:flutter/foundation.dart';

enum GameInterruptionReason { disconnected, left }

/// 모든 게임이 `game/public/interruption`에서 공유하는 중단·투표 상태입니다.
@immutable
class GameInterruption {
  const GameInterruption({
    required this.id,
    required this.playerUid,
    required this.playerNickname,
    required this.playerProfileImageUrl,
    required this.reason,
    required this.startedAt,
    required this.deadlineAt,
    required this.eligibleVoterUids,
    required this.requiredVotes,
    required this.voterUids,
    required this.canContinue,
  });

  factory GameInterruption.fromMap(Map<Object?, Object?> map) {
    return GameInterruption(
      id: map['id']?.toString() ?? '',
      playerUid: map['playerUid']?.toString() ?? '',
      playerNickname: map['playerNickname']?.toString() ?? '플레이어',
      playerProfileImageUrl: map['playerProfileImageUrl']?.toString() ?? '',
      reason: map['reason']?.toString() == 'left'
          ? GameInterruptionReason.left
          : GameInterruptionReason.disconnected,
      startedAt: (map['startedAt'] as num?)?.toInt() ?? 0,
      deadlineAt: (map['deadlineAt'] as num?)?.toInt() ?? 0,
      eligibleVoterUids: _stringValues(map['eligibleVoterUids']),
      requiredVotes: (map['requiredVotes'] as num?)?.toInt() ?? 0,
      voterUids: _mapKeys(map['votes']),
      canContinue: map['canContinue'] == true,
    );
  }

  final String id;
  final String playerUid;
  final String playerNickname;
  final String playerProfileImageUrl;
  final GameInterruptionReason reason;
  final int startedAt;
  final int deadlineAt;
  final List<String> eligibleVoterUids;
  final int requiredVotes;
  final Set<String> voterUids;
  final bool canContinue;

  int get voteCount => voterUids.length;
  bool canVote(String uid) => canContinue && eligibleVoterUids.contains(uid);
  bool hasVoted(String uid) => voterUids.contains(uid);
}

List<String> _stringValues(Object? value) {
  if (value is List) {
    return List.unmodifiable(value.whereType<String>());
  }
  if (value is Map) {
    final entries = value.entries.toList()
      ..sort(
        (left, right) => left.key.toString().compareTo(right.key.toString()),
      );
    return List.unmodifiable(
      entries.map((entry) => entry.value).whereType<String>(),
    );
  }
  return const [];
}

Set<String> _mapKeys(Object? value) {
  if (value is! Map) return const {};
  return Set.unmodifiable(
    value.entries
        .where((entry) => entry.value == true)
        .map((entry) => entry.key.toString()),
  );
}
