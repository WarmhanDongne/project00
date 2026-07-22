class GamePlayerModel {
  const GamePlayerModel({
    required this.id,
    required this.name,
    this.isReady = false,
  });
  final String id;
  final String name;
  final bool isReady;
}
