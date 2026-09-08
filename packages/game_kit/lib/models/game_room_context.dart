import 'package:flutter/foundation.dart';

/// 게임 패키지가 방 구현체를 직접 알지 않도록 노출하는 읽기/명령 경계입니다.
abstract class GameRoomContext extends ChangeNotifier {
  String? get roomCode;
  List<GameRoomPlayer> get players;
  GameRoomMetadata? get selectedGame;
  bool get isLeaving;

  Future<bool> leaveGame(String gameId);
  Future<bool> removePlayer(String uid);
  Stream<bool> watchServerConnection();
  Future<void> retryConnectionRecovery();
}

/// 게임 UI에 필요한 참가자 정보의 최소 계약입니다.
abstract interface class GameRoomPlayer {
  String get uid;
  String get nickname;
  String get characterId;
  bool get isConnected;
  int get seatIndex;
  String get role;
  String get status;
  bool get isPlayer;
  bool get isActive;
}

/// 게임 설정/룰북에 필요한 카탈로그 메타데이터의 최소 계약입니다.
abstract interface class GameRoomMetadata {
  String get name;
  String get imageUrl;
  String get ruleVideoUrl;
}
