import 'package:flutter_test/flutter_test.dart';
import 'package:project00/core/time/server_clock.dart';

/// 턴 마감은 서버 시각 기준이므로, 기기 시계가 어긋나 있어도 남은 시간이
/// 올바르게 계산돼야 합니다.
void main() {
  tearDown(() => ServerClock.debugSetOffset(0));

  test('보정값이 없으면 기기 시각을 그대로 쓴다', () {
    ServerClock.debugSetOffset(0);
    final now = DateTime.now().millisecondsSinceEpoch;
    expect((ServerClock.nowMillis() - now).abs(), lessThan(50));
  });

  test('기기 시계가 느릴 때 서버 시각으로 앞당겨 계산한다', () {
    // 기기가 서버보다 30초 느린 상황
    ServerClock.debugSetOffset(30000);
    final deadline = DateTime.now().millisecondsSinceEpoch + 40000;

    // 기기 시각으로는 40초 남았지만, 서버 기준으로는 10초만 남았습니다.
    final remaining = ServerClock.remainingUntil(deadline).inSeconds;
    expect(remaining, closeTo(10, 1));
  });

  test('기기 시계가 빠를 때 마감을 성급하게 지나치지 않는다', () {
    // 기기가 서버보다 30초 빠른 상황
    ServerClock.debugSetOffset(-30000);
    final deadline = DateTime.now().millisecondsSinceEpoch;

    // 기기 시각만 보면 이미 마감이지만, 서버 기준으로는 30초 남았습니다.
    expect(ServerClock.hasPassed(deadline), isFalse);
    expect(ServerClock.remainingUntil(deadline).inSeconds, closeTo(30, 1));
  });

  test('지난 마감은 0으로 고정된다', () {
    ServerClock.debugSetOffset(0);
    final past = DateTime.now().millisecondsSinceEpoch - 5000;
    expect(ServerClock.remainingUntil(past), Duration.zero);
    expect(ServerClock.hasPassed(past), isTrue);
  });

  test('마감이 없으면 지나지 않은 것으로 본다', () {
    expect(ServerClock.hasPassed(null), isFalse);
  });
}
