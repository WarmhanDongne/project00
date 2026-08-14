enum PlayerRole {
  main,     // 메인 플레이어
  partner,  // 파트너
}

class PlayerModel {
  final String id;
  final String teamId; // e.g., 'A' or 'B'
  final String name;
  final PlayerRole role;

  const PlayerModel({
    required this.id,
    required this.teamId,
    required this.name,
    required this.role,
  });

  PlayerModel copyWith({
    String? id,
    String? teamId,
    String? name,
    PlayerRole? role,
  }) {
    return PlayerModel(
      id: id ?? this.id,
      teamId: teamId ?? this.teamId,
      name: name ?? this.name,
      role: role ?? this.role,
    );
  }

  @override
  String toString() {
    return 'Player(id: $id, team: $teamId, role: $role)';
  }
}
