// [controller_room_session_store.dart] 는 여러 게임이 함께 사용하는 방 세션 컨트롤러의 생성과 수명 주기를 관리하는 파일이다.
//
// - [Package] : 게임 공통 기반
// - [Session] : 방 세션 컨트롤러의 생성과 수명 주기를 관리함
//
// 즉, 게임이 방 연결 상태를 안전하게 공유하고 정리하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'package:shared_preferences/shared_preferences.dart';
// ============================================================

/// 태블릿 controller의 현재 방 세션을 앱 재실행 뒤에도 복구합니다.
///
/// 세션 ID는 화면 상태가 아니라 서버 명령 fencing 토큰입니다. 게임 위젯이
/// dispose되거나 앱이 백그라운드로 가도 지우지 않고, 명시적인 closeRoom 성공
/// 또는 서버가 방을 찾지 못한 경우에만 제거합니다.
class ControllerRoomSessionStore {
  ControllerRoomSessionStore._();

  static final ControllerRoomSessionStore instance =
      ControllerRoomSessionStore._();

  static const _roomCodeKey = 'controller_room_code';
  static const _sessionIdKey = 'controller_room_session_id';

  String? _roomCode;
  String? _sessionId;
  bool _loaded = false;

  String? get roomCode => _roomCode;

  String? sessionIdForRoom(String roomCode) {
    if (_roomCode != roomCode.trim().toUpperCase()) return null;
    return _sessionId;
  }

  Future<void> load() async {
    if (_loaded) return;
    final preferences = await SharedPreferences.getInstance();
    _roomCode = preferences.getString(_roomCodeKey)?.trim().toUpperCase();
    _sessionId = preferences.getString(_sessionIdKey)?.trim();
    _loaded = true;
  }

  Future<void> save({
    required String roomCode,
    required String sessionId,
  }) async {
    final code = roomCode.trim().toUpperCase();
    final preferences = await SharedPreferences.getInstance();
    await Future.wait([
      preferences.setString(_roomCodeKey, code),
      preferences.setString(_sessionIdKey, sessionId),
    ]);
    _roomCode = code;
    _sessionId = sessionId;
    _loaded = true;
  }

  Future<void> clear({String? onlyRoomCode}) async {
    if (onlyRoomCode != null &&
        _roomCode != onlyRoomCode.trim().toUpperCase()) {
      return;
    }
    final preferences = await SharedPreferences.getInstance();
    await Future.wait([
      preferences.remove(_roomCodeKey),
      preferences.remove(_sessionIdKey),
    ]);
    _roomCode = null;
    _sessionId = null;
    _loaded = true;
  }
}

/// controller 전용 callable에 동일한 활성 세션을 자동으로 첨부합니다.
Map<String, dynamic> controllerCommandData(
  String roomCode, [
  Map<String, dynamic> values = const {},
]) {
  final code = roomCode.trim().toUpperCase();
  final sessionId = ControllerRoomSessionStore.instance.sessionIdForRoom(code);
  // 호출자가 예전 payload를 그대로 넘겨도 정규화된 방 코드가 항상
  // 최종값이 됩니다. values의 roomCode가 다시 덮어쓰면 세션 조회와
  // callable payload가 서로 다른 방을 가리키게 됩니다.
  final data = <String, dynamic>{...values, 'roomCode': code};
  if (sessionId != null) data['controllerSessionId'] = sessionId;
  return data;
}
