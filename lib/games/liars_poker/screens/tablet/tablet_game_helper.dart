import 'package:project00/games/liars_poker/models/player_layout_model.dart';
import 'package:project00/gen/assets.gen.dart';

const int cardsPerPlayer = 5;

/// 서버에서 받은 카드 랭크를 태블릿 카드 이미지로 변환합니다.
AssetGenImage cardAssetForRank(String rank) {
  return switch (rank.toUpperCase()) {
    'A' => Assets.games.liarsPoker.images.cards.whiteA,
    'K' => Assets.games.liarsPoker.images.cards.whiteK,
    'Q' => Assets.games.liarsPoker.images.cards.whiteQ,
    'JOKER' => Assets.games.liarsPoker.images.cards.whiteJoker,
    _ => Assets.games.liarsPoker.images.cards.whiteBack,
  };
}

/// 서버에서 받은 테이블 랭크를 중앙 테이블 이미지로 변환합니다.
AssetGenImage tableAssetForRank(String rank) {
  return switch (rank.toUpperCase()) {
    'A' => Assets.games.liarsPoker.images.background.a,
    'K' => Assets.games.liarsPoker.images.background.k,
    'Q' => Assets.games.liarsPoker.images.background.q,
    _ => Assets.games.liarsPoker.images.background.q,
  };
}

/// 태블릿 중앙에 표현할 한 번의 카드 제출 정보입니다.
class SubmittedPlay {
  const SubmittedPlay({
    required this.eventId,
    required this.playerIndex,
    required this.frontCardAssets,
    required this.submittedAt,
    this.isRevealed = false,
    this.animateEntry = true,
  });

  final String eventId;
  final int playerIndex;
  final List<AssetGenImage> frontCardAssets;
  final int submittedAt;
  final bool isRevealed;
  final bool animateEntry;

  SubmittedPlay copyWith({
    String? eventId,
    int? playerIndex,
    List<AssetGenImage>? frontCardAssets,
    int? submittedAt,
    bool? isRevealed,
    bool? animateEntry,
  }) {
    return SubmittedPlay(
      eventId: eventId ?? this.eventId,
      playerIndex: playerIndex ?? this.playerIndex,
      frontCardAssets: frontCardAssets ?? this.frontCardAssets,
      submittedAt: submittedAt ?? this.submittedAt,
      isRevealed: isRevealed ?? this.isRevealed,
      animateEntry: animateEntry ?? this.animateEntry,
    );
  }
}

/// `game/public/lastPlay`에서 태블릿 애니메이션에 필요한 값만 추립니다.
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

/// Cloud Function이 작성한 `game/public` 스냅샷입니다.
class TabletPublicGameSnapshot {
  const TabletPublicGameSnapshot({
    required this.status,
    required this.phase,
    required this.round,
    required this.table,
    required this.turnUid,
    required this.penaltyTargetUid,
    required this.players,
    required this.lastPlay,
    required this.roundPlays,
  });

  final String status;
  final String phase;
  final int round;
  final String table;
  final String? turnUid;
  final String? penaltyTargetUid;
  final Map<Object?, Object?> players;
  final PublicLastPlay? lastPlay;
  final List<PublicLastPlay> roundPlays;

  static TabletPublicGameSnapshot? tryParse(Object? value) {
    if (value is! Map) return null;

    final data = Map<Object?, Object?>.from(value);
    final playersValue = data['players'];

    final round = _asInt(data['round']) ?? 1;
    final lastPlay = PublicLastPlay.tryParse(data['lastPlay']);
    final roundPlays = _parseRoundPlays(
      data['roundPlays'],
    ).where((play) => play.round == round).toList();

    // 배포 전 데이터처럼 round가 없는 제출은 누적 목록 전체를 복원하지 않고,
    // 현재 lastPlay 한 건만 호환 표시해 이전 라운드 카드가 섞이지 않게 합니다.
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

    return TabletPublicGameSnapshot(
      status: data['status'] is String ? data['status'] as String : 'playing',
      phase: data['phase'] is String ? data['phase'] as String : 'playing',
      round: round,
      table: data['table'] is String ? data['table'] as String : 'K',
      turnUid: data['turnUid'] is String ? data['turnUid'] as String : null,
      penaltyTargetUid: data['penaltyTargetUid'] as String?,
      players: playersValue is Map
          ? Map<Object?, Object?>.from(playersValue)
          : const <Object?, Object?>{},
      lastPlay: lastPlay,
      roundPlays: List.unmodifiable(roundPlays),
    );
  }

  /// 화면에 배치된 플레이어 순서대로 남은 카드 수를 반환합니다.
  List<int> remainingCardCounts(PlayerLayoutModel layout) {
    return layout.players
        .map((layoutPlayer) {
          final playerValue = players[layoutPlayer.uid];
          if (playerValue is! Map) return 0;
          return _asInt(playerValue['remainingCardCount']) ?? 0;
        })
        .toList(growable: false);
  }

  int get penaltyAttemptCount {
    final targetUid = penaltyTargetUid;
    if (targetUid == null) return 0;

    final playerValue = players[targetUid];
    if (playerValue is! Map) return 0;
    return _asInt(playerValue['penaltyCount']) ?? 0;
  }
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
