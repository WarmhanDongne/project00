import 'package:flutter_test/flutter_test.dart';
import 'package:project00/platform/home/room/services/controller_presence.dart';

//=======================heartbeat 기반 태블릿 장애 판정 (C-12)==============================
// 지금까지는 `controllerPresence/connected` bool 하나만 봤습니다. 태블릿이 강제
// 종료·크래시·전원 차단으로 markControllerDisconnected를 보낼 기회조차 없으면 그
// 값이 true로 굳어 **참가자에게 아무 안내도 뜨지 않았습니다.** heartbeat가
// 끊긴 것을 lastSeen으로 직접 판정해 그 구멍을 막습니다.

void main() {
  const now = 1000000;
  const grace = controllerPresenceDisplayGrace;

  ControllerPresenceVerdict judge(
    ControllerPresence presence, {
    int nowMillis = now,
  }) {
    return judgeControllerPresence(presence, nowMillis: nowMillis);
  }

  group('표시 유예', () {
    test('heartbeat 주기(10초)의 두 배다', () {
      // 1회 누락으로는 띄우지 않고 2회 연속 누락에서만 띄웁니다.
      // room_provider.dart의 _startControllerHeartbeat가 10초 주기입니다.
      expect(grace, const Duration(seconds: 20));
    });

    test('서버의 방 삭제 유예(3분)와 다른 값이다', () {
      // 표시는 빠르고 삭제는 느려야 합니다. 같은 상수를 공유하면 방이 순간
      // 단절로 삭제되거나(C-01 재발) 장애 표시가 몇 분씩 늦어집니다.
      expect(grace, lessThan(const Duration(minutes: 3)));
    });
  });

  group('명시적 신호', () {
    test('connected == false는 유예 없이 즉시 재접속 대기다', () {
      // 태블릿이 스스로 내려간다고 알린 것이라 기다려서 얻을 정보가 없습니다.
      expect(
        judge(ControllerPresence(connected: false, lastSeen: now)),
        ControllerPresenceVerdict.reconnecting,
      );
    });

    test('방금 heartbeat를 받았으면 연결됨이다', () {
      expect(
        judge(ControllerPresence(connected: true, lastSeen: now)),
        ControllerPresenceVerdict.connected,
      );
    });
  });

  group('heartbeat 누락 판정 — 이번 작업의 핵심', () {
    test('1회 누락(10초)으로는 띄우지 않는다', () {
      expect(
        judge(ControllerPresence(connected: true, lastSeen: now - 10000)),
        ControllerPresenceVerdict.connected,
      );
    });

    test('유예 경계에서는 아직 연결됨이다', () {
      expect(
        judge(
          ControllerPresence(
            connected: true,
            lastSeen: now - grace.inMilliseconds,
          ),
        ),
        ControllerPresenceVerdict.connected,
      );
    });

    test('connected가 true여도 유예를 넘기면 재접속 대기다', () {
      // 강제 종료·크래시·전원 차단은 connected를 false로 바꿀 기회가 없습니다.
      // 이 판정이 없으면 참가자는 영영 아무 안내도 못 받습니다.
      expect(
        judge(
          ControllerPresence(
            connected: true,
            lastSeen: now - grace.inMilliseconds - 1,
          ),
        ),
        ControllerPresenceVerdict.reconnecting,
      );
    });

    test('오래 지나도 판정은 그대로 재접속 대기다', () {
      expect(
        judge(ControllerPresence(connected: true, lastSeen: now - 600000)),
        ControllerPresenceVerdict.reconnecting,
      );
    });
  });

  group('판단 근거가 없을 때', () {
    test('아무 값도 없으면 판단하지 않는다', () {
      // 방에 막 들어온 참가자에게 재접속 화면을 띄우면 정상 입장이 장애로
      // 보입니다. 초기 캐시 미수신과 끊김을 구분해야 합니다.
      expect(
        judge(ControllerPresence.unknown),
        ControllerPresenceVerdict.unknown,
      );
    });

    test('lastSeen이 없는 옛 방은 기존 동작을 유지한다', () {
      expect(
        judge(const ControllerPresence(connected: true, lastSeen: null)),
        ControllerPresenceVerdict.connected,
      );
    });

    test('미래 시각은 시계 보정이 덜 된 것으로 보고 연결됨으로 둔다', () {
      expect(
        judge(ControllerPresence(connected: true, lastSeen: now + 5000)),
        ControllerPresenceVerdict.connected,
      );
    });
  });

  group('RTDB 값 해석', () {
    test('맵에서 두 필드를 읽는다', () {
      final presence = ControllerPresence.fromValue({
        'connected': true,
        'lastSeen': 1234,
      });
      expect(presence.connected, isTrue);
      expect(presence.lastSeen, 1234);
    });

    test('노드가 없으면 unknown이다', () {
      expect(ControllerPresence.fromValue(null), ControllerPresence.unknown);
      expect(
        ControllerPresence.fromValue('nonsense'),
        ControllerPresence.unknown,
      );
    });

    test('일부 필드만 있어도 나머지는 null로 둔다', () {
      final presence = ControllerPresence.fromValue({'connected': false});
      expect(presence.connected, isFalse);
      expect(presence.lastSeen, isNull);
      expect(presence.isEmpty, isFalse);
    });
  });
}
