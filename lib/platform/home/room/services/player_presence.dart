import 'package:project00/platform/home/room/models/room_player.dart';

/// 참가자 heartbeat 간격과 태블릿의 stale 판정 유예입니다.
const playerHeartbeatInterval = Duration(seconds: 10);
const playerHeartbeatStaleGrace = Duration(seconds: 20);

/// 서버 시각 기준으로 마지막 heartbeat가 20초를 초과했는지 판정합니다.
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

/// 같은 참가자의 같은 heartbeat 관측값을 제한된 횟수만 서버에 보고하게 합니다.
class PlayerStaleReportTracker {
  static const maxAttemptsPerObservation = 2;
  final Map<String, ({int lastSeen, int attempts})> _attempts =
      <String, ({int lastSeen, int attempts})>{};

  /// 같은 heartbeat 관측값은 최초 보고와 복구 완료 뒤 재확인 한 번만 허용합니다.
  bool tryStartAttempt(String uid, int lastSeen) {
    final current = _attempts[uid];
    if (current == null || current.lastSeen != lastSeen) {
      _attempts[uid] = (lastSeen: lastSeen, attempts: 1);
      return true;
    }
    if (current.attempts >= maxAttemptsPerObservation) return false;
    _attempts[uid] = (
      lastSeen: current.lastSeen,
      attempts: current.attempts + 1,
    );
    return true;
  }

  /// 서버가 관측값을 처리했다면 같은 값은 더 이상 보고하지 않습니다.
  void markSucceeded(String uid, int lastSeen) {
    final current = _attempts[uid];
    if (current == null || current.lastSeen != lastSeen) return;
    _attempts[uid] = (
      lastSeen: current.lastSeen,
      attempts: maxAttemptsPerObservation,
    );
  }

  void retainCurrent(List<RoomPlayer> players) {
    final currentLastSeen = <String, int?>{
      for (final player in players) player.uid: player.lastSeen,
    };
    _attempts.removeWhere(
      (uid, observation) => currentLastSeen[uid] != observation.lastSeen,
    );
  }

  void forget(String uid) => _attempts.remove(uid);

  void clear() => _attempts.clear();
}
