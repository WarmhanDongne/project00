import 'dart:async';

import 'package:firebase_database/firebase_database.dart';

/// 앱 전체에서 RTDB `.info/connected`를 한 번만 구독하는 연결 상태 소스입니다.
///
/// 네트워크 모달과 방 presence 복구가 같은 broadcast 스트림을 공유하므로 게임이나
/// 플랫폼 화면마다 Firebase 연결 구독이 늘어나지 않습니다.
class RealtimeConnectionMonitor {
  RealtimeConnectionMonitor._();

  static final RealtimeConnectionMonitor instance =
      RealtimeConnectionMonitor._();

  final StreamController<bool> _changes = StreamController<bool>.broadcast(
    sync: true,
  );
  StreamSubscription<DatabaseEvent>? _subscription;
  FirebaseDatabase? _database;
  bool? _latest;

  Stream<bool> watch(FirebaseDatabase database) {
    if (_subscription == null || !identical(_database, database)) {
      unawaited(_subscription?.cancel());
      _database = database;
      _subscription = database
          .ref('.info/connected')
          .onValue
          .listen(
            (event) => _emit(event.snapshot.value == true),
            onError: (_) => _emit(false),
          );
    }
    return Stream<bool>.multi((controller) {
      final latest = _latest;
      if (latest != null) controller.add(latest);
      final subscription = _changes.stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = subscription.cancel;
    }, isBroadcast: true);
  }

  void _emit(bool value) {
    if (_latest == value) return;
    _latest = value;
    _changes.add(value);
  }
}
