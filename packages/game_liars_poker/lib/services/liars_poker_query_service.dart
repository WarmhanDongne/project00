import 'package:firebase_database/firebase_database.dart';
import 'package:game_kit/services/game_query_service.dart';

/// Liar's Poker Realtime Database 읽기·구독 전용 서비스입니다.
///
/// 공개 상태·상태값·개인 노드 구독은 [GameQueryService]가 제공합니다.
/// 여기에는 이 게임에만 있는 노드만 둡니다.
class LiarsPokerQueryService extends GameQueryService {
  LiarsPokerQueryService({super.database});

  /// 내 손패입니다. 개인 노드 전체가 아니라 `hand`만 구독합니다.
  Stream<DatabaseEvent> watchPrivateHand({
    required String roomCode,
    required String uid,
  }) => observeRealtime(
    privateRef(roomCode: roomCode, uid: uid, child: 'hand').onValue,
    channel: '라이어스포커 손패',
  );
}
