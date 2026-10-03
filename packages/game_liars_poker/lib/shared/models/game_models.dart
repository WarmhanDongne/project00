// [game_models.dart] 라이어스 포커에서 사용하는 카드, 플레이어, 룰렛 결과,
// 카드 제출 기록 등의 게임 데이터를 Dart 객체로 표현하고 변환하는 파일이다.

// ========================[ import ]==========================
import 'package:flutter/foundation.dart';

// ============================================================

// ---------------------------------------------------------------------------
// 카드
// ---------------------------------------------------------------------------
@immutable
class PhoneHandCard {
  const PhoneHandCard({required this.id, required this.cardValue});

  final String id;
  final String cardValue;

  // ===[ 카드 형식 변환 ]===
  // RTDB에서 받은 카드 데이터를 PhoneHandCard 객체로 변환한다.
  static PhoneHandCard? fromMap(String key, Map<Object?, Object?> map) {
    final id = map['id']?.toString();

    // RTDB의 `rank`는 기존 앱과 서버가 공유하는 배포된 키이므로 유지한다.
    final cardValue = map['rank']?.toString();

    // 카드 값이 없으면 정상적인 카드 데이터가 아니므로 null을 반환한다.
    if (cardValue == null || cardValue.isEmpty) return null;

    return PhoneHandCard(
      // id가 없으면 RTDB의 key를 카드 id로 사용한다.
      id: (id == null || id.isEmpty) ? key : id,

      // 카드 값의 대소문자를 통일한다. (q → Q)
      cardValue: cardValue.toUpperCase(),
    );
  }

  // ===[ 카드 데이터 비교 ]===
  // 두 PhoneHandCard의 id와 cardValue가 모두 같은지 비교한다.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is PhoneHandCard &&
        id == other.id &&
        cardValue == other.cardValue;
  }

  // == 비교 기준과 동일한 값으로 hashCode를 생성한다.
  @override
  int get hashCode => Object.hash(id, cardValue);
}

// ---------------------------------------------------------------------------
// 플레이어
// ---------------------------------------------------------------------------
@immutable
class PhoneGamePlayer {
  const PhoneGamePlayer({
    required this.uid,
    required this.nickname,
    required this.characterId,
    required this.status,
    required this.remainingCardCount,
    this.seatIndex = 0,
    this.penaltyCount = 0,
  });

  final String uid;
  final String nickname;
  final String characterId;
  final String status;
  final int remainingCardCount;

  // 자리 배치에서 사용하는 플레이어의 좌석 번호
  final int seatIndex;

  // 지금까지 받은 벌칙 횟수
  final int penaltyCount;

  // ===[ 플레이어 형식 변환 ]===
  // RTDB에서 받은 플레이어 데이터를 PhoneGamePlayer 객체로 변환한다.
  factory PhoneGamePlayer.fromMap(String key, Map<Object?, Object?> map) {
    final uid = map['uid']?.toString();

    return PhoneGamePlayer(
      // uid가 없으면 RTDB의 key를 uid로 사용한다.
      uid: (uid == null || uid.isEmpty) ? key : uid,

      // 값이 없을 경우 각 항목의 기본값을 사용한다.
      nickname: map['nickname']?.toString() ?? 'Player',
      characterId: map['characterId']?.toString() ?? 'frog',
      status: map['status']?.toString() ?? 'alive',
      remainingCardCount: (map['remainingCardCount'] as num?)?.toInt() ?? 0,
      seatIndex: (map['seatIndex'] as num?)?.toInt() ?? 0,
      penaltyCount: (map['penaltyCount'] as num?)?.toInt() ?? 0,
    );
  }

  // ===[ 플레이어 데이터 비교 ]===
  // 두 플레이어의 게임 상태 데이터가 모두 같은지 비교한다.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is PhoneGamePlayer &&
        uid == other.uid &&
        nickname == other.nickname &&
        characterId == other.characterId &&
        status == other.status &&
        remainingCardCount == other.remainingCardCount &&
        seatIndex == other.seatIndex &&
        penaltyCount == other.penaltyCount;
  }

  // == 비교 기준과 동일한 값으로 hashCode를 생성한다.
  @override
  int get hashCode => Object.hash(
    uid,
    nickname,
    characterId,
    status,
    remainingCardCount,
    seatIndex,
    penaltyCount,
  );
}

// ---------------------------------------------------------------------------
// 룰렛 결과
// ---------------------------------------------------------------------------
@immutable
class PhonePenaltyResult {
  const PhonePenaltyResult({
    required this.targetUid,
    required this.result,
    required this.resolvedAt,
  });

  // 룰렛 벌칙 대상 플레이어 uid
  final String targetUid;

  // 룰렛 결과: safe 또는 eliminated
  final String result;

  // 룰렛 결과가 확정된 시간
  final int resolvedAt;

  // ===[ 룰렛 결과 형식 변환 ]===
  // RTDB에서 받은 룰렛 결과를 PhonePenaltyResult 객체로 변환한다.
  static PhonePenaltyResult? fromMap(Map<Object?, Object?> map) {
    final targetUid = map['targetUid']?.toString();
    final result = map['result']?.toString();
    final resolvedAt = (map['resolvedAt'] as num?)?.toInt();

    // 필수 데이터가 없거나 결과가 올바르지 않으면 null을 반환한다.
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

  // ===[ 룰렛 결과 데이터 비교 ]===
  // 두 룰렛 결과의 대상, 결과, 처리 시간이 모두 같은지 비교한다.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is PhonePenaltyResult &&
        targetUid == other.targetUid &&
        result == other.result &&
        resolvedAt == other.resolvedAt;
  }

  // == 비교 기준과 동일한 값으로 hashCode를 생성한다.
  @override
  int get hashCode => Object.hash(targetUid, result, resolvedAt);
}

// ---------------------------------------------------------------------------
// 카드 제출 기록
// ---------------------------------------------------------------------------
@immutable
class PublicLastPlay {
  const PublicLastPlay({
    required this.playId,
    required this.round,
    required this.playerUid,
    required this.cardCount,
    required this.declaredCardValue,
    required this.revealed,
    required this.actualCardValues,
    required this.submittedAt,
  });

  // 카드 제출 한 번을 구분하는 고유 id
  final String playId;

  // 해당 카드를 제출한 라운드
  final int? round;

  // 카드를 제출한 플레이어 uid
  final String playerUid;

  // 제출한 카드 장수
  final int cardCount;

  // 플레이어가 선언한 카드 값
  final String declaredCardValue;

  // 실제 카드가 공개되었는지 여부
  final bool revealed;

  // 실제로 제출한 카드 값 목록
  final List<String> actualCardValues;

  // 카드를 제출한 시간
  final int submittedAt;

  // ===[ 카드 제출 기록 형식 변환 ]===
  // RTDB의 lastPlay 또는 roundPlays 데이터를 PublicLastPlay 객체로 변환한다.
  static PublicLastPlay? tryParse(Object? value) {
    // Map 형태가 아니면 카드 제출 데이터로 사용할 수 없다.
    if (value is! Map) return null;

    final data = Map<Object?, Object?>.from(value);

    final playId = data['playId'];
    final playerUid = data['playerUid'];
    final cardCount = _asInt(data['cardCount']);

    // 카드 제출 기록에 반드시 필요한 값들을 확인한다.
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

      // RTDB 키는 기존 앱과의 호환성을 위해 `declaredRank`를 유지한다.
      declaredCardValue: data['declaredRank'] is String
          ? data['declaredRank'] as String
          : 'Q',

      revealed: data['revealed'] == true,

      // 실제 제출 카드 목록을 List<String> 형태로 변환한다.
      actualCardValues: _asStringList(data['actualRanks']),

      submittedAt: _asInt(data['submittedAt']) ?? 0,
    );
  }

  // ===[ 카드 제출 기록 데이터 비교 ]===
  // 두 카드 제출 기록의 모든 주요 데이터가 같은지 비교한다.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is PublicLastPlay &&
        playId == other.playId &&
        round == other.round &&
        playerUid == other.playerUid &&
        cardCount == other.cardCount &&
        declaredCardValue == other.declaredCardValue &&
        revealed == other.revealed &&
        listEquals(actualCardValues, other.actualCardValues) &&
        submittedAt == other.submittedAt;
  }

  // == 비교 기준과 동일한 값으로 hashCode를 생성한다.
  @override
  int get hashCode => Object.hash(
    playId,
    round,
    playerUid,
    cardCount,
    declaredCardValue,
    revealed,
    Object.hashAll(actualCardValues),
    submittedAt,
  );
}

// ---------------------------------------------------------------------------
// 현재 라운드 카드 제출 기록 병합
// ---------------------------------------------------------------------------

// ===[ 카드 제출 기록 병합 ]===
// roundPlays와 lastPlay를 합쳐 현재 라운드의 카드 제출 목록을 만든다.
//
// round가 없는 이전 버전 데이터는 누적 기록 전체에 섞지 않고,
// 현재 lastPlay 한 건만 호환하여 이전 라운드 카드가 섞이는 것을 방지한다.
List<PublicLastPlay> mergeRoundPlays({
  required Object? roundPlaysValue,
  required Object? lastPlayValue,
  required int round,
}) {
  // 가장 최근 카드 제출 기록을 변환한다.
  final lastPlay = PublicLastPlay.tryParse(lastPlayValue);

  // 전체 제출 기록 중 현재 라운드의 기록만 가져온다.
  final roundPlays = _parseRoundPlays(
    roundPlaysValue,
  ).where((play) => play.round == round).toList();

  // lastPlay가 현재 라운드에서 사용할 수 있는 기록인지 확인한다.
  final canUseLastPlay =
      lastPlay != null && (lastPlay.round == null || lastPlay.round == round);

  // roundPlays 안에 이미 같은 lastPlay가 들어 있는지 확인한다.
  final containsLastPlay =
      lastPlay != null &&
      roundPlays.any((play) => play.playId == lastPlay.playId);

  // 사용할 수 있는 lastPlay가 목록에 없다면 추가한다.
  if (canUseLastPlay && !containsLastPlay) {
    roundPlays.add(lastPlay);
  }

  // 제출 시간을 기준으로 오래된 기록부터 정렬한다.
  // 시간이 같으면 playId를 기준으로 다시 정렬한다.
  roundPlays.sort((left, right) {
    final timeOrder = left.submittedAt.compareTo(right.submittedAt);

    return timeOrder != 0 ? timeOrder : left.playId.compareTo(right.playId);
  });

  return roundPlays;
}

// ---------------------------------------------------------------------------
// 카드 제출 기록 목록 변환
// ---------------------------------------------------------------------------

// ===[ roundPlays 형식 변환 ]===
// RTDB에서 받은 여러 카드 제출 기록을 PublicLastPlay 목록으로 변환한다.
List<PublicLastPlay> _parseRoundPlays(Object? value) {
  if (value is! Map) return <PublicLastPlay>[];

  final plays = value.values
      // 각각의 RTDB 데이터를 PublicLastPlay로 변환한다.
      .map(PublicLastPlay.tryParse)
      // 변환에 실패해 null이 된 데이터는 제거한다.
      .whereType<PublicLastPlay>()
      .toList();

  // 제출 시간을 기준으로 순서대로 정렬한다.
  plays.sort((left, right) {
    final timeOrder = left.submittedAt.compareTo(right.submittedAt);

    return timeOrder != 0 ? timeOrder : left.playId.compareTo(right.playId);
  });

  return plays;
}

// ---------------------------------------------------------------------------
// 공통 형식 변환 함수
// ---------------------------------------------------------------------------

// ===[ 정수 형식 변환 ]===
// 값이 숫자라면 int로 변환하고, 숫자가 아니면 null을 반환한다.
int? _asInt(Object? value) {
  return value is num ? value.toInt() : null;
}

// ===[ 문자열 목록 형식 변환 ]===
// RTDB에서 받은 값을 List<String> 형태로 변환한다.
List<String> _asStringList(Object? value) {
  // 일반적인 List 형태로 전달된 경우
  if (value is List) {
    return value.whereType<String>().toList(growable: false);
  }

  // RTDB 배열이 숫자 key를 가진 Map 형태로 반환되는 경우도 처리한다.
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

  // List나 Map이 아니면 빈 목록을 반환한다.
  return const [];
}
