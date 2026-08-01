class GameInfo {
  final String title;
  final int playTime;
  final int minPlayers;
  final int maxPlayers;
  final List<String> genres;
  final String shortDescription;

  GameInfo({
    required this.title,
    required this.playTime,
    required this.minPlayers,
    required this.maxPlayers,
    required this.genres,
    required this.shortDescription,
  });

  factory GameInfo.fromJson(Map<String, dynamic> json) {
    return GameInfo(
      title: json['name'] as String? ?? '이름 없음',
      playTime: (json['playTimeMin'] as num?)?.toInt() ?? 0,
      minPlayers: (json['minPlayers'] as int?)?.toInt() ?? 0,
      maxPlayers: json['maxPlayers'] as int? ?? 0,
      genres: json['genres'] != null ? List<String>.from(json['genres']) : [],
      shortDescription: json['shortDescription'] as String? ?? '설명 없음',
    );
  }
}
