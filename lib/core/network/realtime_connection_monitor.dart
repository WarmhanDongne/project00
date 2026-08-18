import 'dart:async';
import 'dart:collection';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

/// 앱 전체에서 RTDB `.info/connected`를 한 번만 구독하는 연결 상태 소스입니다.
///
/// 네트워크 모달과 방 presence 복구가 같은 broadcast 스트림을 공유하므로 게임이나
/// 플랫폼 화면마다 Firebase 연결 구독이 늘어나지 않습니다.
class RealtimeConnectionMonitor {
  RealtimeConnectionMonitor._();

  @visibleForTesting
  RealtimeConnectionMonitor.forTesting();

  static final RealtimeConnectionMonitor instance =
      RealtimeConnectionMonitor._();

  final Map<Object, _ConnectionChannel> _channels =
      HashMap<Object, _ConnectionChannel>.identity();

  Stream<bool> watch(FirebaseDatabase database) => _watchSource(
    database,
    () => database
        .ref('.info/connected')
        .onValue
        .map((event) => event.snapshot.value == true),
  );

  /// Firebase 없이 인스턴스별 구독 분리와 최신값 재생을 검증하기 위한 진입점입니다.
  @visibleForTesting
  Stream<bool> watchConnectionSource(
    Object identity,
    Stream<bool> Function() createSource,
  ) => _watchSource(identity, createSource);

  Stream<bool> _watchSource(
    Object identity,
    Stream<bool> Function() createSource,
  ) {
    final channel = _channels.putIfAbsent(
      identity,
      () => _ConnectionChannel(createSource()),
    );
    return channel.watch();
  }

  @visibleForTesting
  Future<void> dispose() async {
    final channels = _channels.values.toList(growable: false);
    _channels.clear();
    await Future.wait(channels.map((channel) => channel.dispose()));
  }
}

class _ConnectionChannel {
  _ConnectionChannel(Stream<bool> source) {
    _subscription = source.listen(_emit, onError: (_) => _emit(false));
  }

  final StreamController<bool> _changes = StreamController<bool>.broadcast(
    sync: true,
  );
  late final StreamSubscription<bool> _subscription;
  bool? _latest;

  Stream<bool> watch() {
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

  Future<void> dispose() async {
    await _subscription.cancel();
    await _changes.close();
  }
}
