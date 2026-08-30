import 'package:flutter/foundation.dart';

/// 같은 앱 안의 여러 [RoomProvider]가 서로의 퇴장을 존중하게 하는 프로세스 전역
/// 마커입니다.
///
/// 휴대폰은 홈 화면과 참여 화면이 각각 다른 [RoomProvider]를 들고 있어
/// (`phone_home.dart`의 복원용 인스턴스, `phone_room_join.dart`의 입장용 인스턴스)
/// 인스턴스 필드로는 "다른 쪽이 이 방에서 나가는 중"을 알 수 없습니다. 실제로
/// 퇴장은 입장용 인스턴스에서 일어나고, 저장 세션 자동 복원은 복원용 인스턴스가
/// 수행하므로 두 인스턴스가 공유하는 판단 근거가 필요합니다.
///
/// [complete]로 기록한 방은 [forget] 없이는 이 앱 실행 동안 다시 자동 복원되지
/// 않습니다. 사용자가 직접 나간 방으로 네트워크 복구가 되돌려 보내는 일을 막는
/// 것이 이 클래스의 목적입니다.
abstract final class RoomLeaveIntent {
  static final Set<String> _leaving = <String>{};
  static final Set<String> _left = <String>{};

  static String _normalize(String roomCode) => roomCode.trim().toUpperCase();

  /// 퇴장 요청이 아직 진행 중인 방입니다.
  static bool isLeaving(String roomCode) =>
      _leaving.contains(_normalize(roomCode));

  /// 퇴장이 확정된 방입니다.
  static bool hasLeft(String roomCode) => _left.contains(_normalize(roomCode));

  /// 저장 세션 자동 복원과 네트워크 복구가 건드리면 안 되는 방인지입니다.
  static bool blocksRestore(String roomCode) {
    final code = _normalize(roomCode);
    return _leaving.contains(code) || _left.contains(code);
  }

  static void begin(String roomCode) {
    _leaving.add(_normalize(roomCode));
  }

  /// 퇴장이 확정됐습니다. 다시 입장하기 전까지 복원 대상에서 제외합니다.
  static void complete(String roomCode) {
    final code = _normalize(roomCode);
    _leaving.remove(code);
    _left.add(code);
  }

  /// 퇴장이 실패했습니다. 사용자는 아직 이 방을 쓰므로 복원을 다시 허용합니다.
  static void fail(String roomCode) {
    _leaving.remove(_normalize(roomCode));
  }

  /// 같은 방 코드로 다시 입장했습니다. 이전 퇴장 기록을 지웁니다.
  static void forget(String roomCode) {
    final code = _normalize(roomCode);
    _leaving.remove(code);
    _left.remove(code);
  }

  @visibleForTesting
  static void resetForTesting() {
    _leaving.clear();
    _left.clear();
  }
}
