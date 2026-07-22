class GameRoomModel {
  const GameRoomModel({
    required this.id,
    required this.code,
    required this.playerIds,
  });
  final String id;
  final String code;
  final List<String> playerIds;
}
