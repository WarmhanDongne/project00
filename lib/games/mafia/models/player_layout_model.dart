class PlayerLayoutModel {
  const PlayerLayoutModel({required this.players});

  /// 게임에 참가한 플레이어와 각 플레이어가 차지한 좌석입니다.
  /// 목록 순서는 플레이어 인덱스로 사용하고, 실제 화면 자리는 [seatIndex]로 찾습니다.
  final List<PlayerLayoutPlayer> players;

  int get playerCount => players.length;

  List<int> get seatIndexes =>
      players.map((player) => player.seatIndex).toList(growable: false);

  PlayerLayoutPlayer? playerByUid(String uid) {
    for (final player in players) {
      if (player.uid == uid) return player;
    }
    return null;
  }

  PlayerLayoutModel updateSeats(List<int> seatIndexes) {
    if (seatIndexes.length != players.length) {
      throw ArgumentError.value(
        seatIndexes,
        'seatIndexes',
        '플레이어 수와 좌석 수가 같아야 합니다.',
      );
    }

    final uniqueSeats = seatIndexes.toSet();
    if (uniqueSeats.length != players.length ||
        uniqueSeats.any((seat) => seat < 0 || seat >= players.length)) {
      throw ArgumentError.value(
        seatIndexes,
        'seatIndexes',
        '좌석 번호는 0부터 playerCount - 1까지 중복 없이 사용해야 합니다.',
      );
    }

    return PlayerLayoutModel(
      players: List.unmodifiable(
        List.generate(
          players.length,
          (index) => players[index].copyWith(seatIndex: seatIndexes[index]),
          growable: false,
        ),
      ),
    );
  }
}

class PlayerLayoutPlayer {
  const PlayerLayoutPlayer({
    required this.uid,
    required this.nickname,
    required this.profileImageUrl,

    required this.seatIndex,
  });

  final String uid;
  final String nickname;
  final String profileImageUrl;

  /// 테이블 주변에서 몇 번째 자리인지 나타냅니다.
  final int seatIndex;

  PlayerLayoutPlayer copyWith({int? seatIndex}) {
    return PlayerLayoutPlayer(
      uid: uid,
      nickname: nickname,
      profileImageUrl: profileImageUrl,
      seatIndex: seatIndex ?? this.seatIndex,
    );
  }
}
