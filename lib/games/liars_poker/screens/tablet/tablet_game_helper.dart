import 'package:project00/gen/assets.gen.dart';
import 'package:project00/core/assets/game_image.dart';

const int cardsPerPlayer = 5;

/// 서버에서 받은 카드 랭크를 태블릿 카드 이미지로 변환합니다.
GameImage cardAssetForRank(String rank) {
  return switch (rank.toUpperCase()) {
    'A' => Assets.games.liarsPoker.images.cards.whiteA.game,
    'K' => Assets.games.liarsPoker.images.cards.whiteK.game,
    'Q' => Assets.games.liarsPoker.images.cards.whiteQ.game,
    'JOKER' => Assets.games.liarsPoker.images.cards.whiteJoker.game,
    _ => Assets.games.liarsPoker.images.cards.whiteBack.game,
  };
}

/// 서버에서 받은 테이블 랭크를 중앙 테이블 이미지로 변환합니다.
GameImage tableAssetForRank(String rank) {
  return switch (rank.toUpperCase()) {
    'A' => Assets.games.liarsPoker.images.background.a.game,
    'K' => Assets.games.liarsPoker.images.background.k.game,
    'Q' => Assets.games.liarsPoker.images.background.q.game,
    _ => Assets.games.liarsPoker.images.background.q.game,
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
  final List<GameImage> frontCardAssets;
  final int submittedAt;
  final bool isRevealed;
  final bool animateEntry;

  SubmittedPlay copyWith({
    String? eventId,
    int? playerIndex,
    List<GameImage>? frontCardAssets,
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
