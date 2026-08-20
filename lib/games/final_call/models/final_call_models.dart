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
}

/// 반대 좌석끼리 묶이는 Final Call의 고정 2대2 팀입니다.
enum FinalCallTeam {
  red,
  blue;

  static FinalCallTeam fromWire(Object? value, {required int seatIndex}) {
    return switch (value?.toString()) {
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
}
