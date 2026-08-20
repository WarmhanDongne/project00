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
    required this.characterId,
  });

  final String uid;
  final String roomCode;
  final String nickname;
  final String characterId;
}

class PlayerRoomSessionStore {
  PlayerRoomSessionStore._();

  static final PlayerRoomSessionStore instance = PlayerRoomSessionStore._();

  static const _uidKey = 'player_room_uid';
  static const _roomCodeKey = 'player_room_code';
  static const _nicknameKey = 'player_room_nickname';
  static const _characterIdKey = 'player_room_character_id';
  static const _legacyAccentColorKey = 'player_room_accent_color';

  PlayerRoomSession? _session;
  bool _loaded = false;

  Future<PlayerRoomSession?> load() async {
    if (_loaded) return _session;
    final preferences = await SharedPreferences.getInstance();
    final uid = preferences.getString(_uidKey)?.trim();
    final roomCode = preferences.getString(_roomCodeKey)?.trim().toUpperCase();
    final nickname = preferences.getString(_nicknameKey)?.trim();
    final characterId = preferences.getString(_characterIdKey)?.trim();
    _loaded = true;

    if (uid == null ||
        uid.isEmpty ||
        roomCode == null ||
        roomCode.isEmpty ||
        nickname == null ||
        nickname.isEmpty ||
        characterId == null ||
        characterId.isEmpty) {
      _session = null;
      return null;
    }
    _session = PlayerRoomSession(
      uid: uid,
      roomCode: roomCode,
      nickname: nickname,
      characterId: characterId,
    );
    return _session;
  }

  Future<void> save({
    required String uid,
    required String roomCode,
    required String nickname,
    required String characterId,
  }) async {
    final session = PlayerRoomSession(
      uid: uid.trim(),
      roomCode: roomCode.trim().toUpperCase(),
      nickname: nickname.trim(),
      characterId: characterId.trim(),
    );
    final preferences = await SharedPreferences.getInstance();
    await Future.wait([
      preferences.setString(_uidKey, session.uid),
      preferences.setString(_roomCodeKey, session.roomCode),
      preferences.setString(_nicknameKey, session.nickname),
      preferences.setString(_characterIdKey, session.characterId),
      preferences.remove(_legacyAccentColorKey),
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
      preferences.remove(_characterIdKey),
      preferences.remove(_legacyAccentColorKey),
    ]);
    _session = null;
    _loaded = true;
  }
}
