import 'dart:async';

import 'package:firebase_database/firebase_database.dart';

/// 서버 시각을 기준으로 마감 시간을 계산합니다.
///
/// 턴 마감(`turnDeadlineAt`)은 서버가 `Date.now()`로 찍은 값인데, 클라이언트가
/// 기기 시계로 비교하면 다음 문제가 생깁니다.
/// - 기기 시계가 몇 초만 빨라도 타이머가 즉시 0이 되어 턴을 놓칩니다.
/// - 사용자가 시간을 수동으로 바꿔 타이머를 늘릴 수 있습니다.
/// - 앱을 백그라운드에 두었다 돌아오면 기기 시계와 서버 시각이 더 벌어집니다.
///
/// Realtime Database가 제공하는 `.info/serverTimeOffset`(서버 시각 - 기기 시각)을
/// 구독해 두고, 마감 계산에는 항상 [nowMillis]를 씁니다.
abstract final class ServerClock {
  static StreamSubscription<DatabaseEvent>? _subscription;
  static int _offsetMillis = 0;

  /// 서버와 기기 시각의 차이(밀리초)입니다.
  static int get offsetMillis => _offsetMillis;

  /// 앱 시작 시 한 번 호출해 서버 시각 보정을 시작합니다.
  static void start([FirebaseDatabase? database]) {
    if (_subscription != null) return;
    final ref = (database ?? FirebaseDatabase.instance).ref(
      '.info/serverTimeOffset',
    );
    _subscription = ref.onValue.listen(
      (event) {
        final value = event.snapshot.value;
        if (value is num) _offsetMillis = value.toInt();
      },
      // 보정을 못 받아도 기기 시각으로 계속 동작해야 하므로 무시합니다.
      onError: (_) {},
    );
  }

  /// 서버 기준 현재 시각(밀리초)입니다.
  static int nowMillis() =>
      DateTime.now().millisecondsSinceEpoch + _offsetMillis;

  /// 서버 기준으로 [deadlineMillis]까지 남은 시간입니다. 이미 지났으면 0입니다.
  static Duration remainingUntil(int deadlineMillis) {
    final remaining = deadlineMillis - nowMillis();
    return Duration(milliseconds: remaining < 0 ? 0 : remaining);
  }

  /// 서버 기준으로 마감이 지났는지 여부입니다.
  static bool hasPassed(int? deadlineMillis) =>
      deadlineMillis != null && nowMillis() >= deadlineMillis;

  /// 테스트에서 보정값을 직접 지정합니다.
  static void debugSetOffset(int millis) => _offsetMillis = millis;

  static Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    _offsetMillis = 0;
  }
}
