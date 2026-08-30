import 'package:flutter/foundation.dart';

/// 태블릿 진행 기기의 접속 표시입니다.
///
/// `rooms/{roomCode}/controllerPresence`를 그대로 옮긴 값입니다. 두 필드를
/// **함께** 읽는 것이 요점입니다. `connected`만 보면 태블릿이 강제 종료·크래시·
/// 전원 차단으로 `markControllerDisconnected`를 보낼 기회조차 없었던 경우를
/// 영원히 알 수 없습니다(값이 `true`로 굳습니다).
@immutable
class ControllerPresence {
  const ControllerPresence({required this.connected, required this.lastSeen});

  /// 아직 아무 값도 받지 못한 상태입니다.
  ///
  /// 초기 캐시 미수신과 "끊김"을 구분해야 합니다. 방에 들어가자마자
  /// 재접속 화면을 띄우면 정상 입장이 장애로 보입니다.
  static const unknown = ControllerPresence(connected: null, lastSeen: null);

  factory ControllerPresence.fromValue(Object? value) {
    if (value is! Map) return unknown;
    final connected = value['connected'];
    final lastSeen = value['lastSeen'];
    return ControllerPresence(
      connected: connected is bool ? connected : null,
      lastSeen: lastSeen is num ? lastSeen.toInt() : null,
    );
  }

  final bool? connected;

  /// 태블릿이 마지막으로 heartbeat를 보낸 **서버 시각**입니다.
  ///
  /// `ServerValue.timestamp`로 기록되므로 기기 시계가 아니라 서버 시계입니다.
  /// 비교할 때도 반드시 `ServerClock.nowMillis()`를 써야 합니다.
  final int? lastSeen;

  bool get isEmpty => connected == null && lastSeen == null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ControllerPresence &&
          connected == other.connected &&
          lastSeen == other.lastSeen;

  @override
  int get hashCode => Object.hash(connected, lastSeen);
}

/// 태블릿 장애 판정 결과입니다.
enum ControllerPresenceVerdict { unknown, connected, reconnecting }

/// 태블릿 heartbeat가 끊긴 것으로 **표시**하기까지의 유예입니다.
///
/// heartbeat 주기는 10초입니다(`room_provider.dart`의
/// `_startControllerHeartbeat`). 이 값은 그 두 배로, **2회 연속 누락**에서만
/// 끊김으로 봅니다. 1회 누락(10초)으로는 띄우지 않습니다.
///
/// 이 앱은 집·펜션에서 씁니다. 오탐 위험이 낮은 이유:
/// - 태블릿이 백그라운드로 내려가는 경우(제어 센터·알림·앱 스위처)는
///   `paused`/`detached`에서 `markControllerDisconnected`를 **명시적으로**
///   보냅니다(`tablet_home.dart`). 이 경로는 유예와 무관하게 즉시 뜹니다.
/// - 그래서 heartbeat 누락만으로 판정해야 하는 경우는 강제 종료·크래시·전원
///   차단·Wi-Fi 완전 단절뿐이고, 이건 오탐이 아니라 진짜 장애입니다.
/// - 남은 오탐 원인은 공유기 재연결로 heartbeat write가 실패하는 것인데,
///   실패는 조용히 삼키고 10초 뒤 재시도합니다. 2주기 연속 실패는 드뭅니다.
///
/// ⚠️ **서버의 방 삭제 유예와 같은 상수를 쓰지 마세요.**
/// 표시는 빠르고(20초) 삭제는 느려야 합니다(3분 이상,
/// `functions/src/room/realtime-room-lifecycle.ts`). 한쪽을 바꿔 다른 쪽이
/// 따라가면 방이 순간 단절로 삭제되거나(C-01 재발), 장애 표시가 몇 분씩
/// 늦어집니다.
const Duration controllerPresenceDisplayGrace = Duration(seconds: 20);

/// 현재 presence와 서버 시각으로 태블릿 장애 여부를 판정합니다.
///
/// [nowMillis]는 반드시 **서버 기준** 시각이어야 합니다(`ServerClock.nowMillis`).
/// `lastSeen`이 `ServerValue.timestamp`로 기록되므로, 기기 시계로 비교하면
/// 시계 오차만큼 오탐하거나 장애를 놓칩니다.
ControllerPresenceVerdict judgeControllerPresence(
  ControllerPresence presence, {
  required int nowMillis,
  Duration grace = controllerPresenceDisplayGrace,
}) {
  // 아직 아무것도 못 받았으면 판단하지 않습니다. 방에 막 들어온 참가자에게
  // 재접속 화면을 띄우면 정상 입장이 장애로 보입니다.
  if (presence.isEmpty) return ControllerPresenceVerdict.unknown;

  // 명시적인 false는 유예 없이 즉시 표시합니다. 태블릿이 스스로 "내려간다"고
  // 알린 것이라 기다려서 얻을 정보가 없습니다.
  if (presence.connected == false) {
    return ControllerPresenceVerdict.reconnecting;
  }

  final lastSeen = presence.lastSeen;
  // connected는 true인데 lastSeen이 없는 방은 판단 근거가 없습니다.
  // 옛 방 데이터일 수 있으므로 기존 동작(연결됨)을 유지합니다.
  if (lastSeen == null) {
    return presence.connected == true
        ? ControllerPresenceVerdict.connected
        : ControllerPresenceVerdict.unknown;
  }

  // 미래 시각은 기기·서버 보정이 아직 안 맞은 것으로 보고 연결됨으로 둡니다.
  final elapsed = nowMillis - lastSeen;
  if (elapsed <= grace.inMilliseconds) {
    return ControllerPresenceVerdict.connected;
  }
  return ControllerPresenceVerdict.reconnecting;
}
