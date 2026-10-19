import 'package:game_kit/firebase/firebase_backend.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:project00/platform/home/gamelist/models/game_info.dart';
import 'package:project00/platform/home/gamelist/models/game_catalog_id.dart';

class GameService {
  GameService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseBackend.firestore,
       _auth = auth ?? FirebaseBackend.auth,
       _functions = functions ?? FirebaseBackend.functions;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;
  Future<QuerySnapshot<Map<String, dynamic>>>? _catalogRequest;

  // Share only an active read, never retain stale ownership/catalog decisions.
  Future<QuerySnapshot<Map<String, dynamic>>> _readCatalog() async {
    final request = _catalogRequest ??= _firestore.collection('games').get();
    try {
      return await request;
    } finally {
      if (identical(_catalogRequest, request)) _catalogRequest = null;
    }
  }

  /// 전체 게임 목록을 불러오고 현재 사용자의 보유 여부를 함께 반환
  Future<List<GameInfo>> fetchGames() => _fetchPersonalCatalog(
    include: (game) => game.enabled && game.isAccessible,
  );

  /// 상점에 진열할 전체 카탈로그를 보유 여부와 함께 반환합니다.
  ///
  /// 내 게임 목록과 달리 유료 미보유 게임과 아직 비활성화된 예고 게임도
  /// `storeVisible`이면 포함합니다. 실제 실행 가능 여부는 [GameInfo.isAccessible]과
  /// [GameInfo.enabled]를 별도로 확인합니다.
  Future<List<GameInfo>> fetchStoreGames() =>
      _fetchPersonalCatalog(include: (game) => game.storeVisible);

  Future<List<GameInfo>> _fetchPersonalCatalog({
    required bool Function(GameInfo game) include,
  }) async {
    final user = _auth.currentUser;

    late QuerySnapshot<Map<String, dynamic>> gameSnapshot;
    Set<String> ownedGameIds = {};
    await Future.wait<void>([
      _readCatalog().then((value) {
        gameSnapshot = value;
      }),
      if (user != null)
        _firestore.collection('users').doc(user.uid).get().then((value) {
          ownedGameIds = _ownedGameIds(value.data()?['ownedGames']);
        }),
    ]);
    if (_auth.currentUser?.uid != user?.uid) {
      throw StateError('계정이 변경되었습니다. 다시 조회해주세요.');
    }

    final games = preferredCatalogEntries(gameSnapshot.docs, (doc) => doc.id)
        .values
        .map(
          (doc) => GameInfo.fromSnapshot(
            doc,
            isOwned: ownedGameIds.contains(runtimeGameId(doc.id)),
          ),
        )
        .where(include)
        .toList(growable: false);

    games.sort((left, right) => left.order.compareTo(right.order));
    return games;
  }

  // 현재 그룹이 보유 중인 게임 목록을 반환
  Future<List<GameInfo>> fetchGroupGames(
    List<String> uids, {
    required String roomCode,
    required String roomInstanceId,
  }) async {
    if (uids.isEmpty) return const [];

    // 전달된 UID는 화면 갱신 중복 방지에만 사용합니다. 권한 판정 대상은 서버가
    // 현재 controllerRooms 매핑과 실제 방 참가자 명단에서 다시 계산합니다.
    // 클라이언트가 다른 사용자의 프로필 문서를 읽지 않게 하는 보안 경계입니다.
    final uid = _auth.currentUser?.uid;
    late HttpsCallableResult<Map<String, dynamic>> entitlementResult;
    late QuerySnapshot<Map<String, dynamic>> gameSnapshot;
    await Future.wait<void>([
      _functions
          .httpsCallable('fetchRealtimeRoomGroupEntitlements')
          .call<Map<String, dynamic>>({
            'roomCode': roomCode,
            'roomInstanceId': roomInstanceId,
          })
          .then((value) {
            entitlementResult = value;
          }),
      _readCatalog().then((value) {
        gameSnapshot = value;
      }),
    ]);
    if (_auth.currentUser?.uid != uid) {
      throw StateError('계정이 변경되었습니다. 다시 조회해주세요.');
    }
    if (entitlementResult.data['status'] == 'stale') {
      throw StateError('그룹 구성이 변경되었습니다.');
    }
    final groupOwnedGameIds = _ownedGameIds(
      entitlementResult.data['ownedGameIds'],
    );

    // 그룹이 가진 게임만 필터링하여 GameInfo 객체로 반환
    final games = preferredCatalogEntries(gameSnapshot.docs, (doc) => doc.id)
        .values
        .map(
          (doc) => GameInfo.fromSnapshot(
            doc,
            isOwned: groupOwnedGameIds.contains(runtimeGameId(doc.id)),
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

    return _ownedGameIds(ownedGames).contains(runtimeGameId(gameId));
  }

  Future<GameInfo?> getGame(String gameId) async {
    final canonicalId = catalogDocumentId(gameId);
    var snapshot = await _firestore.collection('games').doc(canonicalId).get();
    final legacyId = runtimeGameId(gameId);
    if (!snapshot.exists && canonicalId != legacyId) {
      snapshot = await _firestore.collection('games').doc(legacyId).get();
    }

    if (!snapshot.exists) {
      return null;
    }
    return GameInfo.fromSnapshot(snapshot);
  }

  Set<String> _ownedGameIds(Object? value) => value is List
      ? value.whereType<String>().map(runtimeGameId).toSet()
      : const <String>{};
}
