import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:project00/platform/home/gamelist/models/game_info.dart';

class GameService {
  GameService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  /// 전체 게임 목록을 불러오고 현재 사용자의 보유 여부를 함께 반환
  Future<List<GameInfo>> fetchGames() async {
    final user = _auth.currentUser;

    // 전체 게임 목록
    final gameSnapshot = await _firestore.collection('games').get();

    // 내가 보유한 게임 ID
    Set<String> ownedGameIds = {};

    if (user != null) {
      final userSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      final ownedGames = userSnapshot.data()?['ownedGames'];

      if (ownedGames is List) {
        ownedGameIds = ownedGames.whereType<String>().toSet();
      }
    }

    final games = gameSnapshot.docs
        .map(
          (doc) => GameInfo.fromSnapshot(
            doc,
            isOwned: ownedGameIds.contains(doc.id),
          ),
        )
        .where((game) => game.enabled)
        .toList(growable: false);

    games.sort((left, right) => left.order.compareTo(right.order));
    return games;
  }

  // 현재 그룹이 보유 중인 게임 목록을 반환
  Future<List<GameInfo>> fetchGroupGames(List<String> uids) async {
    // set 선언
    Set<String> groupOwnedGameIds = {};

    for (final uid in uids) {
      final userSnapshot = await _firestore.collection('users').doc(uid).get();
      final ownedGames = userSnapshot.data()?['ownedGames'];

      if (ownedGames is List) {
        groupOwnedGameIds.addAll(ownedGames.whereType<String>());
      }
    }

    // 전체 게임 목록 가져오기
    final gameSnapshot = await _firestore.collection('games').get();

    // 그룹이 가진 게임만 필터링하여 GameInfo 객체로 반환
    final games = gameSnapshot.docs
        .where((doc) => groupOwnedGameIds.contains(doc.id))
        .map((doc) => GameInfo.fromSnapshot(doc, isOwned: true))
        .where((game) => game.enabled)
        .toList(growable: false);

    // 순서에 맞게 정렬 후 반환
    games.sort((left, right) => left.order.compareTo(right.order));
    return games;
  }

  /// 특정 게임 보유 여부 확인
  Future<bool> isGameOwned(String gameId) async {
    final user = _auth.currentUser;

    if (user == null) return false;

    final userSnapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .get();

    final ownedGames = userSnapshot.data()?['ownedGames'];

    if (ownedGames is! List) return false;

    return ownedGames.whereType<String>().contains(gameId);
  }

  Future<GameInfo?> getGame(String gameId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('games')
        .doc(gameId)
        .get();

    if (!snapshot.exists) {
      return null;
    }
    return GameInfo.fromSnapshot(snapshot);
  }
}
