import 'package:firebase_database/firebase_database.dart';
import 'package:project00/firebase/services/realtime_database_service.dart';

class LiarsPokerQueryService {
  LiarsPokerQueryService({
    FirebaseDatabase? database,
  }) : _database =
          database ??
          RealtimeDatabaseService.instance;

  final FirebaseDatabase _database;

  /// 공개 게임 상태
  Stream<DatabaseEvent> watchPublicGame(
    String roomCode,
  ) {
    return _database
        .ref('rooms/$roomCode/game/public')
        .onValue;
  }

  /// 내 손패
  Stream<DatabaseEvent> watchPrivateHand({
    required String roomCode,
    required String uid,
  }) {
    return _database
        .ref('rooms/$roomCode/game/private/$uid/hand')
        .onValue;
  }

  /// 현재 턴
  Stream<DatabaseEvent> watchTurn(
    String roomCode,
  ) {
    return _database
        .ref('rooms/$roomCode/game/public/turn')
        .onValue;
  }

  /// 플레이어 상태
  Stream<DatabaseEvent> watchPlayers(
    String roomCode,
  ) {
    return _database
        .ref('rooms/$roomCode/game/public/players')
        .onValue;
  }

  /// 테이블 카드
  Stream<DatabaseEvent> watchTable(
    String roomCode,
  ) {
    return _database
        .ref('rooms/$roomCode/game/public/table')
        .onValue;
  }

  /// 게임 상태
  Stream<DatabaseEvent> watchStatus(
    String roomCode,
  ) {
    return _database
        .ref('rooms/$roomCode/game/public/status')
        .onValue;
  }
}