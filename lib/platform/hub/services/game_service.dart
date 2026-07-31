import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GameService {
  GameService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  /// 전체 게임 목록을 불러오고 현재 사용자의 보유 여부를 함께 반환
  Future<List<Map<String, dynamic>>> fetchGames() async {
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

    return gameSnapshot.docs.map((doc) {
      final data = doc.data();

      return {
        'id': doc.id, // 문서 자체의 고유 ID
        'name': data['name'] ?? '',
        'imageUrl': data['imageUrl'] ?? '',
        'description': data['description'] ?? '',
        'genres': data['genres'] ?? [],
        'playTime': data['playTimeMin'] ?? 0,
        'minPlayers': data['minPlayers'] ?? 0,
        'maxPlayers': data['maxPlayers'] ?? 0,
        'ruleVideoUrl':data['ruleVideoUrl'] ?? 0,
        'Order': data['sortOrder'] ?? 0,
        'createdAt': data['createdAt'],
        'updatedAt': data['updatedAt'],

        // 파이어베이스 사진에는 없지만 기존 코드에 있던 부분 (유지)
        'price': data['price'] ?? 0,
        'isOwned': ownedGameIds.contains(doc.id),
      };
    }).toList();
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
}
