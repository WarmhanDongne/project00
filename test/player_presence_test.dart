import 'package:flutter_test/flutter_test.dart';
import 'package:project00/platform/home/room/services/player_presence.dart';

void main() {
  test('같은 stale 관측은 실패 후 한 번만 재시도하고 성공하면 닫는다', () {
    final tracker = PlayerStaleReportTracker();

    expect(tracker.tryStartAttempt('player', 1000), isTrue);
    expect(tracker.tryStartAttempt('player', 1000), isTrue);
    expect(tracker.tryStartAttempt('player', 1000), isFalse);

    expect(tracker.tryStartAttempt('player', 2000), isTrue);
    tracker.markSucceeded('player', 2000);
    expect(tracker.tryStartAttempt('player', 2000), isFalse);
  });
}
