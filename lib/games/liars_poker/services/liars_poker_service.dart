import 'package:firebase_database/firebase_database.dart';
import 'package:project00/platform/home/room/models/room_player.dart';

class LiarsPokerGameService {
  final FirebaseDatabase realtime;

  LiarsPokerGameService(this.realtime);

  Future<void> startGame({
    required String roomCode,
    required String hostUid,
    required List<RoomMember> players,
  }) async {
    // 카드 덱 생성
    // 카드 섞기
    // 플레이어별 카드 분배
    // rooms/$roomCode/game 생성
    // rooms/$roomCode/playersPublic 생성
    // roomPrivate/$roomCode/players 생성
  }
}