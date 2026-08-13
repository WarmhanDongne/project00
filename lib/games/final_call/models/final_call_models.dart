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

class FinalCallPlayer {
  const FinalCallPlayer({
    required this.uid,
    required this.nickname,
    required this.profileImageUrl,
    required this.seatIndex,
    required this.status,
    required this.lives,
  });

  final String uid;
  final String nickname;
  final String profileImageUrl;
  final int seatIndex;
  final String status;
  final int lives;

  factory FinalCallPlayer.fromMap(String key, Map<Object?, Object?> map) =>
      FinalCallPlayer(
        uid: map['uid']?.toString() ?? key,
        nickname: map['nickname']?.toString() ?? 'Player',
        profileImageUrl: map['profileImageUrl']?.toString() ?? '',
        seatIndex: (map['seatIndex'] as num?)?.toInt() ?? 0,
        status: map['status']?.toString() ?? 'alive',
        lives: (map['lives'] as num?)?.toInt() ?? 3,
      );
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
