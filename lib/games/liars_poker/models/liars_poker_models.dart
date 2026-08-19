import 'package:flutter/foundation.dart';

//=======================Liar's Poker 도메인 모델==============================
// Realtime Database `game/public`과 `game/private`에서 읽은 값을 표현합니다.
// Final Call의 `models/final_call_models.dart`와 같은 역할입니다.

/// 내 손패 한 장입니다.
@immutable
class PhoneHandCard {
  const PhoneHandCard({required this.id, required this.rank});

  final String id;
  final String rank;

  /// RTDB `hand/<cardKey>` 항목을 파싱합니다. rank가 없으면 null입니다.
  static PhoneHandCard? fromMap(String key, Map<Object?, Object?> map) {
    final id = map['id']?.toString();
    final rank = map['rank']?.toString();
    if (rank == null || rank.isEmpty) return null;
    return PhoneHandCard(
      id: (id == null || id.isEmpty) ? key : id,
      rank: rank.toUpperCase(),
    );
  }
}

/// 공개 상태의 플레이어 한 명입니다.
@immutable
class PhoneGamePlayer {
  const PhoneGamePlayer({
    required this.uid,
    required this.nickname,
    required this.profileImageUrl,
    required this.status,
    required this.remainingCardCount,
    this.seatIndex = 0,
    this.penaltyCount = 0,
  });

  final String uid;
  final String nickname;
  final String profileImageUrl;
  final String status;
  final int remainingCardCount;

  /// 자리 배치에서의 좌석 번호입니다. 태블릿 화면이 좌석 좌표를 계산할 때 씁니다.
  final int seatIndex;

  /// 지금까지 받은 벌칙 횟수입니다. 룰렛의 탈락 확률 단계를 정합니다.
  final int penaltyCount;

  factory PhoneGamePlayer.fromMap(String key, Map<Object?, Object?> map) {
    final uid = map['uid']?.toString();
    return PhoneGamePlayer(
      uid: (uid == null || uid.isEmpty) ? key : uid,
      nickname: map['nickname']?.toString() ?? 'Player',
      profileImageUrl: map['profileImageUrl']?.toString() ?? '',
      status: map['status']?.toString() ?? 'alive',
      remainingCardCount: (map['remainingCardCount'] as num?)?.toInt() ?? 0,
      seatIndex: (map['seatIndex'] as num?)?.toInt() ?? 0,
      penaltyCount: (map['penaltyCount'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 룰렛이 끝난 뒤 잠시 공개되는 벌칙 결과입니다.
@immutable
class PhonePenaltyResult {
  const PhonePenaltyResult({
    required this.targetUid,
    required this.result,
    required this.resolvedAt,
  });

  final String targetUid;
  final String result;
  final int resolvedAt;

  /// RTDB `penaltyResult`를 파싱합니다. 필수 값이 없거나 결과 값이 유효하지
  /// 않으면 null입니다.
  static PhonePenaltyResult? fromMap(Map<Object?, Object?> map) {
    final targetUid = map['targetUid']?.toString();
    final result = map['result']?.toString();
    final resolvedAt = (map['resolvedAt'] as num?)?.toInt();
    if (targetUid == null ||
        targetUid.isEmpty ||
        result == null ||
        (result != 'safe' && result != 'eliminated') ||
        resolvedAt == null) {
      return null;
    }
    return PhonePenaltyResult(
      targetUid: targetUid,
      result: result,
      resolvedAt: resolvedAt,
    );
  }
}

/// `game/public/lastPlay`·`roundPlays`의 한 번의 카드 제출입니다.
///
/// 태블릿 중앙 카드 더미 연출과 재접속 복원의 원본 데이터입니다.
@immutable
class PublicLastPlay {
  const PublicLastPlay({
    required this.playId,
    required this.round,
    required this.playerUid,
    required this.cardCount,
    required this.declaredRank,
    required this.revealed,
    required this.actualRanks,
    required this.submittedAt,
  });

  final String playId;
  final int? round;
  final String playerUid;
  final int cardCount;
  final String declaredRank;
  final bool revealed;
  final List<String> actualRanks;
  final int submittedAt;

  static PublicLastPlay? tryParse(Object? value) {
    if (value is! Map) return null;

    final data = Map<Object?, Object?>.from(value);
    final playId = data['playId'];
    final playerUid = data['playerUid'];
    final cardCount = _asInt(data['cardCount']);

    if (playId is! String ||
        playerUid is! String ||
        cardCount == null ||
        cardCount <= 0) {
      return null;
    }

    return PublicLastPlay(
      playId: playId,
      round: _asInt(data['round']),
      playerUid: playerUid,
      cardCount: cardCount,
      declaredRank: data['declaredRank'] is String
          ? data['declaredRank'] as String
          : 'Q',
      revealed: data['revealed'] == true,
      actualRanks: _asStringList(data['actualRanks']),
      submittedAt: _asInt(data['submittedAt']) ?? 0,
    );
  }
}

/// `game/public`의 `roundPlays`와 `lastPlay`를 이번 라운드의 제출 목록으로
/// 병합합니다.
///
/// 배포 전 데이터처럼 round가 없는 제출은 누적 목록 전체를 복원하지 않고,
/// 현재 lastPlay 한 건만 호환 표시해 이전 라운드 카드가 섞이지 않게 합니다.
List<PublicLastPlay> mergeRoundPlays({
  required Object? roundPlaysValue,
  required Object? lastPlayValue,
  required int round,
}) {
  final lastPlay = PublicLastPlay.tryParse(lastPlayValue);
  final roundPlays = _parseRoundPlays(
    roundPlaysValue,
  ).where((play) => play.round == round).toList();

  final canUseLastPlay =
      lastPlay != null && (lastPlay.round == null || lastPlay.round == round);
  final containsLastPlay =
      lastPlay != null &&
      roundPlays.any((play) => play.playId == lastPlay.playId);
  if (canUseLastPlay && !containsLastPlay) {
    roundPlays.add(lastPlay);
  }
  roundPlays.sort((left, right) {
    final timeOrder = left.submittedAt.compareTo(right.submittedAt);
    return timeOrder != 0 ? timeOrder : left.playId.compareTo(right.playId);
  });
  return roundPlays;
}

List<PublicLastPlay> _parseRoundPlays(Object? value) {
  if (value is! Map) return <PublicLastPlay>[];

  final plays = value.values
      .map(PublicLastPlay.tryParse)
      .whereType<PublicLastPlay>()
      .toList();

  plays.sort((left, right) {
    final timeOrder = left.submittedAt.compareTo(right.submittedAt);
    return timeOrder != 0 ? timeOrder : left.playId.compareTo(right.playId);
  });
  return plays;
}

int? _asInt(Object? value) {
  return value is num ? value.toInt() : null;
}

List<String> _asStringList(Object? value) {
  if (value is List) {
    return value.whereType<String>().toList(growable: false);
  }

  // RTDB 배열이 드물게 숫자 키를 가진 Map으로 반환되는 경우도 처리합니다.
  if (value is Map) {
    final entries = value.entries.toList()
      ..sort((left, right) {
        final leftIndex = int.tryParse(left.key.toString()) ?? 0;
        final rightIndex = int.tryParse(right.key.toString()) ?? 0;
        return leftIndex.compareTo(rightIndex);
      });
    return entries
        .map((entry) => entry.value)
        .whereType<String>()
        .toList(growable: false);
  }

  return const [];
}
