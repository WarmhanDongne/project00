// [game_interruption.dart] 는 여러 게임이 함께 사용하는 게임의 공통 단계·안내·종료 흐름을 정의하는 파일이다.
//
// - [Package] : 게임 공통 기반
// - [GameFlow] : 게임의 공통 단계·안내·종료 흐름을 정의함
//
// 즉, 각 게임이 같은 화면 전환 규칙과 예외 처리를 공유하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'package:flutter/foundation.dart';
// ============================================================

enum GameInterruptionReason { disconnected, left }

/// 모든 게임이 `game/public/interruption`에서 공유하는 중단·투표 상태입니다.
@immutable
class GameInterruption {
  const GameInterruption({
    required this.id,
    required this.playerUid,
    required this.playerNickname,
    required this.playerCharacterId,
    required this.reason,
    required this.startedAt,
    required this.deadlineAt,
    required this.eligibleVoterUids,
    required this.requiredVotes,
    required this.voterUids,
    required this.remainingPlayerCount,
    required this.minimumPlayerCount,
    required this.canContinue,
  });

  factory GameInterruption.fromMap(Map<Object?, Object?> map) {
    return GameInterruption(
      id: map['id']?.toString() ?? '',
      playerUid: map['playerUid']?.toString() ?? '',
      playerNickname: map['playerNickname']?.toString() ?? '플레이어',
      playerCharacterId: map['playerCharacterId']?.toString() ?? 'frog',
      reason: map['reason']?.toString() == 'left'
          ? GameInterruptionReason.left
          : GameInterruptionReason.disconnected,
      startedAt: (map['startedAt'] as num?)?.toInt() ?? 0,
      deadlineAt: (map['deadlineAt'] as num?)?.toInt() ?? 0,
      eligibleVoterUids: _stringValues(map['eligibleVoterUids']),
      requiredVotes: (map['requiredVotes'] as num?)?.toInt() ?? 0,
      voterUids: _mapKeys(map['votes']),
      remainingPlayerCount: (map['remainingPlayerCount'] as num?)?.toInt() ?? 0,
      minimumPlayerCount: (map['minimumPlayerCount'] as num?)?.toInt() ?? 2,
      canContinue: map['canContinue'] == true,
    );
  }

  final String id;
  final String playerUid;
  final String playerNickname;
  final String playerCharacterId;
  final GameInterruptionReason reason;
  final int startedAt;
  final int deadlineAt;
  final List<String> eligibleVoterUids;
  final int requiredVotes;
  final Set<String> voterUids;
  final int remainingPlayerCount;
  final int minimumPlayerCount;
  final bool canContinue;

  int get voteCount => voterUids.length;
  bool canVote(String uid) => canContinue && eligibleVoterUids.contains(uid);
  bool hasVoted(String uid) => voterUids.contains(uid);

  //=======================값 동등성==============================
  // Riverpod 의 Notifier 는 `previous != next` 일 때만 알림을 보냅니다.
  // == 가 없으면 copyWith 가 만든 새 객체는 내용이 같아도 늘 다른 것으로
  // 취급되어, 바뀐 게 없는 스냅샷에도 화면 전체가 다시 그려집니다.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GameInterruption &&
        id == other.id &&
        playerUid == other.playerUid &&
        playerNickname == other.playerNickname &&
        playerCharacterId == other.playerCharacterId &&
        reason == other.reason &&
        startedAt == other.startedAt &&
        deadlineAt == other.deadlineAt &&
        listEquals(eligibleVoterUids, other.eligibleVoterUids) &&
        requiredVotes == other.requiredVotes &&
        setEquals(voterUids, other.voterUids) &&
        remainingPlayerCount == other.remainingPlayerCount &&
        minimumPlayerCount == other.minimumPlayerCount &&
        canContinue == other.canContinue;
  }

  @override
  int get hashCode => Object.hash(
    id,
    playerUid,
    playerNickname,
    playerCharacterId,
    reason,
    startedAt,
    deadlineAt,
    Object.hashAll(eligibleVoterUids),
    requiredVotes,
    Object.hashAllUnordered(voterUids),
    remainingPlayerCount,
    minimumPlayerCount,
    canContinue,
  );
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
