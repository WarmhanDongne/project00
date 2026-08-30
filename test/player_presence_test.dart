import 'package:flutter_test/flutter_test.dart';
import 'package:project00/platform/home/room/models/room_player.dart';
import 'package:project00/platform/home/room/services/player_presence.dart';

void main() {
  RoomPlayer player({bool connected = true, int? lastSeen = 1000}) =>
      RoomPlayer(
        uid: 'player-a',
        nickname: '참가자',
        characterId: 'frog',
        isConnected: connected,
        seatIndex: 0,
        role: 'player',
        status: 'active',
        lastSeen: lastSeen,
        penaltyAttemptCount: 0,
      );

  test('정확히 20초는 stale 후보가 아니다', () {
    expect(
      isStalePlayerHeartbeatCandidate(player(), nowMillis: 21000),
      isFalse,
    );
  });

  test('20초를 초과하면 stale 후보이다', () {
    expect(isStalePlayerHeartbeatCandidate(player(), nowMillis: 21001), isTrue);
  });

  test('이미 끊겼거나 lastSeen이 없으면 후보가 아니다', () {
    expect(
      isStalePlayerHeartbeatCandidate(
        player(connected: false),
        nowMillis: 99999,
      ),
      isFalse,
    );
    expect(
      isStalePlayerHeartbeatCandidate(player(lastSeen: null), nowMillis: 99999),
      isFalse,
    );
  });

  test('RTDB 변환이 lastSeen을 보존한다', () {
    final parsed = RoomPlayer.fromJson({
      'nickname': '참가자',
      'characterId': 'frog',
      'isConnected': true,
      'seatIndex': 0,
      'role': 'player',
      'status': 'active',
      'lastSeen': 12345,
      'penaltyAttemptCount': 0,
    }, key: 'player-a');
    expect(parsed.lastSeen, 12345);
    expect(parsed.toJson()['lastSeen'], 12345);
  });

  test('같은 참가자의 같은 heartbeat는 한 번만 보고한다', () {
    final tracker = PlayerStaleReportTracker();
    expect(tracker.markIfNew('player-a', 1000), isTrue);
    expect(tracker.markIfNew('player-a', 1000), isFalse);
  });

  test('새 heartbeat가 오면 다음 단절을 다시 보고할 수 있다', () {
    final tracker = PlayerStaleReportTracker();
    tracker.markIfNew('player-a', 1000);
    tracker.retainCurrent([player(lastSeen: 2000)]);
    expect(tracker.markIfNew('player-a', 2000), isTrue);
  });
}
