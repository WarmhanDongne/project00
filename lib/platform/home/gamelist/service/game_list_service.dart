import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:project00/platform/home/gamelist/models/game_info.dart';

class GameService {
  GameService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _functions =
           functions ??
           FirebaseFunctions.instanceFor(region: 'asia-northeast3');

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

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
      ownedGameIds = _ownedGameIds(userSnapshot.data()?['ownedGames']);
    }

    final games = gameSnapshot.docs
        .map(
          (doc) => GameInfo.fromSnapshot(
            doc,
            isOwned: ownedGameIds.contains(doc.id),
          ),
        )
        .where((game) => game.enabled && game.isAccessible)
        .toList(growable: false);

    games.sort((left, right) => left.order.compareTo(right.order));
    return games;
  }

  // 현재 그룹이 보유 중인 게임 목록을 반환
  Future<List<GameInfo>> fetchGroupGames(List<String> uids) async {
    if (uids.isEmpty) return const [];

    // 전달된 UID는 화면 갱신 중복 방지에만 사용합니다. 권한 판정 대상은 서버가
    // 현재 controllerRooms 매핑과 실제 방 참가자 명단에서 다시 계산합니다.
    // 클라이언트가 다른 사용자의 프로필 문서를 읽지 않게 하는 보안 경계입니다.
    final entitlementResult = await _functions
        .httpsCallable('fetchRealtimeRoomGroupEntitlements')
        .call<Map<String, dynamic>>();
    final groupOwnedGameIds = _ownedGameIds(
      entitlementResult.data['ownedGameIds'],
    );

    // 전체 게임 목록 가져오기
    final gameSnapshot = await _firestore.collection('games').get();

    // 그룹이 가진 게임만 필터링하여 GameInfo 객체로 반환
    final games = gameSnapshot.docs
        .map(
          (doc) => GameInfo.fromSnapshot(
            doc,
            isOwned: groupOwnedGameIds.contains(doc.id),
          ),
        )
        .where((game) => game.enabled && game.isAccessible)
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
    final snapshot = await _firestore.collection('games').doc(gameId).get();

    if (!snapshot.exists) {
      return null;
    }
    return GameInfo.fromSnapshot(snapshot);
  }

  Set<String> _ownedGameIds(Object? value) =>
      value is List ? value.whereType<String>().toSet() : const <String>{};
}
