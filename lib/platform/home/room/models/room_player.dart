import 'package:project00/platform/home/room/models/room_character.dart';

class RoomPlayer {
  const RoomPlayer({
    required this.uid,
    required this.nickname,
    required this.characterId,
    required this.isConnected,
    required this.seatIndex,
    required this.role,
    required this.status,
    this.joinedAt,
    this.updatedAt,
    this.lastSeen,
    required this.penaltyAttemptCount,
  });

  factory RoomPlayer.fromJson(Map<String, dynamic> json, {String? key}) {
    // RTDB에서 넘어온 JSON 딕셔너리를 Dart 표준으로 캐스팅
    return RoomPlayer(
      uid: key ?? json['uid'] as String? ?? '',
      nickname: json['nickname'] as String? ?? 'Player',
      // 마이그레이션 전 플레이어는 기본 캐릭터로 표시하고 재입장 시 정상 저장합니다.
      characterId: json['characterId'] as String? ?? defaultRoomCharacterId,
      isConnected: json['isConnected'] as bool? ?? true,
      seatIndex: json['seatIndex'] as int? ?? -1,
      role: json['role'] as String? ?? 'player',
      status: json['status'] as String? ?? 'active',
      joinedAt: _dateTimeFromTimestamp(json['joinedAt']),
      updatedAt: _dateTimeFromTimestamp(json['updatedAt']),
      lastSeen: _timestampMillis(json['lastSeen']),
      penaltyAttemptCount: json['penaltyAttemptCount'] as int? ?? 0,
    );
  }

  final String uid;
  final String nickname;
  final String characterId;
  final bool isConnected;
  final int seatIndex;
  final String role;
  final String status;
  final DateTime? joinedAt;
  final DateTime? updatedAt;
  final int? lastSeen;
  final int penaltyAttemptCount;

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'nickname': nickname,
    'characterId': characterId,
    'isConnected': isConnected,
    'seatIndex': seatIndex,
    'role': role,
    'status': status,
    if (joinedAt != null) 'joinedAt': joinedAt!.millisecondsSinceEpoch,
    if (updatedAt != null) 'updatedAt': updatedAt!.millisecondsSinceEpoch,
    if (lastSeen != null) 'lastSeen': lastSeen,
    'penaltyAttemptCount': penaltyAttemptCount,
  };

  bool get isPlayer => role == 'player';
  bool get isActive => status == 'active';

  Duration newBadgeRemainingAt(DateTime now) {
    final joined = joinedAt;
    if (joined == null) return Duration.zero;
    final remaining = const Duration(seconds: 30) - now.difference(joined);
    return remaining > Duration.zero ? remaining : Duration.zero;
  }
}

int? _timestampMillis(Object? value) => value is num ? value.toInt() : null;

DateTime? _dateTimeFromTimestamp(Object? value) {
  if (value is! num) return null;
  return DateTime.fromMillisecondsSinceEpoch(value.toInt());
}
