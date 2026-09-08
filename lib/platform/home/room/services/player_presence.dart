import 'package:project00/platform/home/room/models/room_player.dart';

/// 참가자 heartbeat 간격과 태블릿의 stale 판정 유예입니다.
const playerHeartbeatInterval = Duration(seconds: 10);
const playerHeartbeatStaleGrace = Duration(seconds: 20);

/// 서버 시각 기준으로 마지막 heartbeat가 20초를 **초과**했는지 판정합니다.
///
/// 이 함수는 후보만 고릅니다. 실제 접속 해제와 게임 중단은 controller 세션을
/// 검증하는 서버 transaction이 최신 값을 다시 확인한 뒤 수행합니다.
bool isStalePlayerHeartbeatCandidate(
  RoomPlayer player, {
  required int nowMillis,
}) {
  final lastSeen = player.lastSeen;
  if (!player.isPlayer ||
      !player.isActive ||
      !player.isConnected ||
      lastSeen == null) {
    return false;
  }
  return nowMillis - lastSeen > playerHeartbeatStaleGrace.inMilliseconds;
}

/// 같은 참가자의 같은 heartbeat 관측값을 한 번만 서버에 보고하게 합니다.
class PlayerStaleReportTracker {
  final Map<String, int> _reportedLastSeen = <String, int>{};

  bool markIfNew(String uid, int lastSeen) {
    if (_reportedLastSeen[uid] == lastSeen) return false;
    _reportedLastSeen[uid] = lastSeen;
    return true;
  }

  void retainCurrent(List<RoomPlayer> players) {
    final currentLastSeen = <String, int?>{
      for (final player in players) player.uid: player.lastSeen,
    };
    _reportedLastSeen.removeWhere(
      (uid, reported) => currentLastSeen[uid] != reported,
    );
  }

  void clear() => _reportedLastSeen.clear();
}
