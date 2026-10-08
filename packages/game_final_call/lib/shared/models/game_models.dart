// [game_models.dart] 는 파이널콜에서 사용하는 게임 데이터를 타입으로 표현하고 변환하는 파일이다.
//
// - [Package] : 파이널콜
// - [Model] : 게임 데이터를 타입으로 표현하고 변환함
//
// 즉, 서버 값을 화면에서 안전하고 일관된 형태로 사용하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'package:flutter/foundation.dart';

// ============================================================

class FinalCallCard {
  const FinalCallCard({
    required this.id,
    required this.color,
    required this.value,
  });

  final String id;
  final String color;
  final int value;

  factory FinalCallCard.fromMap(Map<Object?, Object?> map) => FinalCallCard(
    id: map['id']?.toString() ?? '',
    color: map['color']?.toString() ?? 'red',
    value: (map['value'] as num?)?.toInt() ?? 1,
  );

  // ---------------------------------------------------------------------------
  // 값 동등성
  // ---------------------------------------------------------------------------
  // Riverpod 의 Notifier 는 `previous != next` 일 때만 알림을 보냅니다.
  // == 가 없으면 copyWith 가 만든 새 객체는 내용이 같아도 늘 다른 것으로
  // 취급되어, 바뀐 게 없는 스냅샷에도 화면 전체가 다시 그려집니다.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FinalCallCard &&
        id == other.id &&
        color == other.color &&
        value == other.value;
  }

  @override
  int get hashCode => Object.hash(id, color, value);
}

enum FinalCallCombinationType { color, sameNumber }

class FinalCallScoreResult {
  const FinalCallScoreResult({
    required this.value,
    required this.type,
    this.color,
  });

  final int value;
  final FinalCallCombinationType type;
  final String? color;

  // ---------------------------------------------------------------------------
  // 값 동등성
  // ---------------------------------------------------------------------------
  // Riverpod 의 Notifier 는 `previous != next` 일 때만 알림을 보냅니다.
  // == 가 없으면 copyWith 가 만든 새 객체는 내용이 같아도 늘 다른 것으로
  // 취급되어, 바뀐 게 없는 스냅샷에도 화면 전체가 다시 그려집니다.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FinalCallScoreResult &&
        value == other.value &&
        type == other.type &&
        color == other.color;
  }

  @override
  int get hashCode => Object.hash(value, type, color);
}

/// 선택된 카드로 만든 최고 점수와 그 점수를 만든 조합 종류를 반환합니다.
FinalCallScoreResult calculateFinalCallScoreResult(
  Iterable<FinalCallCard> cards,
) {
  final colorTotals = <String, int>{};
  final valueTotals = <int, int>{};
  final valueCounts = <int, int>{};
  for (final card in cards) {
    colorTotals.update(
      card.color,
      (total) => total + card.value,
      ifAbsent: () => card.value,
    );
    valueTotals.update(
      card.value,
      (total) => total + card.value,
      ifAbsent: () => card.value,
    );
    valueCounts.update(card.value, (count) => count + 1, ifAbsent: () => 1);
  }

  var bestColor = '';
  var bestColorScore = 0;
  for (final entry in colorTotals.entries) {
    if (entry.value > bestColorScore) {
      bestColor = entry.key;
      bestColorScore = entry.value;
    }
  }

  var bestNumberScore = 0;
  for (final entry in valueTotals.entries) {
    if ((valueCounts[entry.key] ?? 0) >= 2 && entry.value > bestNumberScore) {
      bestNumberScore = entry.value;
    }
  }

  if (bestNumberScore >= bestColorScore && bestNumberScore > 0) {
    return FinalCallScoreResult(
      value: bestNumberScore,
      type: FinalCallCombinationType.sameNumber,
    );
  }
  return FinalCallScoreResult(
    value: bestColorScore,
    type: FinalCallCombinationType.color,
    color: bestColor.isEmpty ? null : bestColor,
  );
}

/// 점수를 만든 카드 묶음입니다. 화면은 이 카드들을 묶어 표시합니다.
class FinalCallCombination {
  const FinalCallCombination({required this.result, required this.cards});

  final FinalCallScoreResult result;

  /// 점수 계산에 들어간 카드입니다(손패 순서 유지).
  final List<FinalCallCard> cards;

  int get score => result.value;
  bool get isSameNumber => result.type == FinalCallCombinationType.sameNumber;
  Set<String> get cardIds => {for (final card in cards) card.id};
}

/// [calculateFinalCallScoreResult]와 같은 규칙으로 최고 점수를 만든 카드를
/// 함께 돌려줍니다.
FinalCallCombination finalCallBestCombination(Iterable<FinalCallCard> cards) {
  final hand = cards.toList(growable: false);
  final result = calculateFinalCallScoreResult(hand);
  if (result.type == FinalCallCombinationType.sameNumber) {
    final counts = <int, int>{};
    for (final card in hand) {
      counts.update(card.value, (count) => count + 1, ifAbsent: () => 1);
    }
    final value = counts.entries
        .where((entry) => entry.value >= 2)
        .firstWhere((entry) => entry.key * entry.value == result.value)
        .key;
    return FinalCallCombination(
      result: result,
      cards: [
        for (final card in hand)
          if (card.value == value) card,
      ],
    );
  }
  return FinalCallCombination(
    result: result,
    cards: [
      for (final card in hand)
        if (card.color == result.color) card,
    ],
  );
}

/// 기존 점수 계산 호출부에서 사용하는 숫자 전용 편의 함수입니다.
int calculateFinalCallScore(Iterable<FinalCallCard> cards) =>
    calculateFinalCallScoreResult(cards).value;

/// 한 턴이 끝난 뒤 태블릿 중앙으로 던져질 버린 카드 이벤트입니다.
class FinalCallDiscardEvent {
  const FinalCallDiscardEvent({
    required this.version,
    required this.playerUid,
    required this.card,
    required this.previousCard,
    required this.drawSource,
  });

  final int version;
  final String playerUid;
  final FinalCallCard card;
  final FinalCallCard? previousCard;
  final String? drawSource;

  // ---------------------------------------------------------------------------
  // 값 동등성
  // ---------------------------------------------------------------------------
  // Riverpod 의 Notifier 는 `previous != next` 일 때만 알림을 보냅니다.
  // == 가 없으면 copyWith 가 만든 새 객체는 내용이 같아도 늘 다른 것으로
  // 취급되어, 바뀐 게 없는 스냅샷에도 화면 전체가 다시 그려집니다.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FinalCallDiscardEvent &&
        version == other.version &&
        playerUid == other.playerUid &&
        card == other.card &&
        previousCard == other.previousCard &&
        drawSource == other.drawSource;
  }

  @override
  int get hashCode =>
      Object.hash(version, playerUid, card, previousCard, drawSource);
}

class FinalCallPlayer {
  const FinalCallPlayer({
    required this.uid,
    required this.nickname,
    required this.characterId,
    required this.seatIndex,
    required this.team,
    required this.status,
    required this.lives,
  });

  final String uid;
  final String nickname;
  final String characterId;
  final int seatIndex;
  final FinalCallTeam team;
  final String status;
  final int lives;

  factory FinalCallPlayer.fromMap(String key, Map<Object?, Object?> map) {
    final seatIndex = (map['seatIndex'] as num?)?.toInt() ?? 0;
    return FinalCallPlayer(
      uid: map['uid']?.toString() ?? key,
      nickname: map['nickname']?.toString() ?? 'Player',
      characterId: map['characterId']?.toString() ?? 'frog',
      seatIndex: seatIndex,
      team: FinalCallTeam.fromWire(map['team'], seatIndex: seatIndex),
      status: map['status']?.toString() ?? 'alive',
      lives: (map['lives'] as num?)?.toInt() ?? 3,
    );
  }

  // ---------------------------------------------------------------------------
  // 값 동등성
  // ---------------------------------------------------------------------------
  // Riverpod 의 Notifier 는 `previous != next` 일 때만 알림을 보냅니다.
  // == 가 없으면 copyWith 가 만든 새 객체는 내용이 같아도 늘 다른 것으로
  // 취급되어, 바뀐 게 없는 스냅샷에도 화면 전체가 다시 그려집니다.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FinalCallPlayer &&
        uid == other.uid &&
        nickname == other.nickname &&
        characterId == other.characterId &&
        seatIndex == other.seatIndex &&
        team == other.team &&
        status == other.status &&
        lives == other.lives;
  }

  @override
  int get hashCode =>
      Object.hash(uid, nickname, characterId, seatIndex, team, status, lives);
}

/// 4인 또는 6인 테이블에서 반대 좌석끼리 묶이는 2인 팀입니다.
enum FinalCallTeam {
  red,
  blue,
  green;

  String get label => switch (this) {
    red => '레드팀',
    blue => '블루팀',
    green => '그린팀',
  };

  static FinalCallTeam fromWire(Object? value, {required int seatIndex}) {
    return switch (value?.toString()) {
      'green' => FinalCallTeam.green,
      'blue' => FinalCallTeam.blue,
      'red' => FinalCallTeam.red,
      // 이전 서버 상태를 읽더라도 반대 좌석(0·2 / 1·3)이 같은 팀이 됩니다.
      _ => seatIndex.isEven ? FinalCallTeam.red : FinalCallTeam.blue,
    };
  }
}

class FinalCallRoundResult {
  const FinalCallRoundResult({
    required this.scores,
    required this.lifeLosses,
    required this.revealedHands,
    required this.automaticCall,
  });

  final Map<String, int> scores;
  final Map<String, int> lifeLosses;
  final Map<String, List<FinalCallCard>> revealedHands;
  final bool automaticCall;

  factory FinalCallRoundResult.fromMap(Map<Object?, Object?> map) {
    Map<String, int> ints(Object? value) {
      if (value is! Map) return const {};
      return {
        for (final e in value.entries)
          e.key.toString(): (e.value as num).toInt(),
      };
    }

    final hands = <String, List<FinalCallCard>>{};
    final rawHands = map['revealedHands'];
    if (rawHands is Map) {
      for (final entry in rawHands.entries) {
        final rawCards = entry.value;
        if (rawCards is List) {
          hands[entry.key.toString()] = rawCards
              .whereType<Map>()
              .map(
                (card) =>
                    FinalCallCard.fromMap(Map<Object?, Object?>.from(card)),
              )
              .toList();
        } else if (rawCards is Map) {
          hands[entry.key.toString()] = rawCards.values
              .whereType<Map>()
              .map(
                (card) =>
                    FinalCallCard.fromMap(Map<Object?, Object?>.from(card)),
              )
              .toList();
        }
      }
    }
    return FinalCallRoundResult(
      scores: ints(map['scores']),
      lifeLosses: ints(map['lifeLosses']),
      revealedHands: hands,
      automaticCall: map['automaticCall'] == true,
    );
  }

  // ---------------------------------------------------------------------------
  // 값 동등성
  // ---------------------------------------------------------------------------
  // Riverpod 의 Notifier 는 `previous != next` 일 때만 알림을 보냅니다.
  // == 가 없으면 copyWith 가 만든 새 객체는 내용이 같아도 늘 다른 것으로
  // 취급되어, 바뀐 게 없는 스냅샷에도 화면 전체가 다시 그려집니다.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FinalCallRoundResult &&
        mapEquals(scores, other.scores) &&
        mapEquals(lifeLosses, other.lifeLosses) &&
        mapEquals(revealedHands, other.revealedHands) &&
        automaticCall == other.automaticCall;
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(
      scores.entries.map((e) => Object.hash(e.key, e.value)),
    ),
    Object.hashAllUnordered(
      lifeLosses.entries.map((e) => Object.hash(e.key, e.value)),
    ),
    Object.hashAllUnordered(
      revealedHands.entries.map((e) => Object.hash(e.key, e.value)),
    ),
    automaticCall,
  );
}
