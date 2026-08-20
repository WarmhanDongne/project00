import 'package:shared_preferences/shared_preferences.dart';

/// 휴대폰 플레이어가 앱 종료 뒤 같은 UID로 진행 중인 방에 돌아가기 위한 정보입니다.
///
/// 게임 상태와 손패는 서버의 기존 UID 경로가 계속 소유합니다. 여기에는 재접속
/// 요청에 필요한 방 코드와 공개 프로필만 저장하며, 명시적 퇴장·강퇴·방 종료 때만
/// 지웁니다.
class PlayerRoomSession {
  const PlayerRoomSession({
    required this.uid,
    required this.roomCode,
    required this.nickname,
    required this.accentColor,
  });

  final String uid;
  final String roomCode;
  final String nickname;
  final String accentColor;
}

class PlayerRoomSessionStore {
  PlayerRoomSessionStore._();

  static final PlayerRoomSessionStore instance = PlayerRoomSessionStore._();

  static const _uidKey = 'player_room_uid';
  static const _roomCodeKey = 'player_room_code';
  static const _nicknameKey = 'player_room_nickname';
  static const _accentColorKey = 'player_room_accent_color';

  PlayerRoomSession? _session;
  bool _loaded = false;

  Future<PlayerRoomSession?> load() async {
    if (_loaded) return _session;
    final preferences = await SharedPreferences.getInstance();
    final uid = preferences.getString(_uidKey)?.trim();
    final roomCode = preferences.getString(_roomCodeKey)?.trim().toUpperCase();
    final nickname = preferences.getString(_nicknameKey)?.trim();
    final accentColor = preferences.getString(_accentColorKey)?.trim();
    _loaded = true;

    if (uid == null ||
        uid.isEmpty ||
        roomCode == null ||
        roomCode.isEmpty ||
        nickname == null ||
        nickname.isEmpty ||
        accentColor == null ||
        accentColor.isEmpty) {
      _session = null;
      return null;
    }
    _session = PlayerRoomSession(
      uid: uid,
      roomCode: roomCode,
      nickname: nickname,
      accentColor: accentColor,
    );
    return _session;
  }

  Future<void> save({
    required String uid,
    required String roomCode,
    required String nickname,
    required String accentColor,
  }) async {
    final session = PlayerRoomSession(
      uid: uid.trim(),
      roomCode: roomCode.trim().toUpperCase(),
      nickname: nickname.trim(),
      accentColor: accentColor.trim().toUpperCase(),
    );
    final preferences = await SharedPreferences.getInstance();
    await Future.wait([
      preferences.setString(_uidKey, session.uid),
      preferences.setString(_roomCodeKey, session.roomCode),
      preferences.setString(_nicknameKey, session.nickname),
      preferences.setString(_accentColorKey, session.accentColor),
    ]);
    _session = session;
    _loaded = true;
  }

  Future<void> clear({String? onlyRoomCode}) async {
    final current = await load();
    if (onlyRoomCode != null &&
        current?.roomCode != onlyRoomCode.trim().toUpperCase()) {
      return;
    }
    final preferences = await SharedPreferences.getInstance();
    await Future.wait([
      preferences.remove(_uidKey),
      preferences.remove(_roomCodeKey),
      preferences.remove(_nicknameKey),
      preferences.remove(_accentColorKey),
    ]);
    _session = null;
    _loaded = true;
  }
}
