import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:game_kit/firebase/firebase_backend.dart';
import 'package:project00/platform/home/store/models/game_bundle.dart';

/// Reads the storefront's configurable bundle catalog. It never writes data.
class GameBundleService {
  GameBundleService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseBackend.firestore;

  final FirebaseFirestore _firestore;
  Future<QuerySnapshot<Map<String, dynamic>>>? _request;

  Future<List<GameBundle>> fetchStoreBundles() async {
    final request = _request ??= _firestore.collection('gameBundles').get();
    late QuerySnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await request;
    } finally {
      if (identical(_request, request)) _request = null;
    }
    final bundles =
        snapshot.docs
            .map(GameBundle.fromSnapshot)
            .where((bundle) => bundle.storeVisible && bundle.gameIds.isNotEmpty)
            .toList(growable: false)
          ..sort((left, right) => left.order.compareTo(right.order));
    return bundles;
  }
}
