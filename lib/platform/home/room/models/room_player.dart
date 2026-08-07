class RoomPlayer {
  const RoomPlayer({
    required this.uid,
    required this.nickname,
    required this.profileImageUrl,
    required this.isConnected,
    required this.seatIndex,
    required this.role,
    required this.status,
    this.isHost = false,
    this.joinedAt,
    this.updatedAt,
    required this.penaltyAttemptCount,
  });

  factory RoomPlayer.fromJson(Map<String, dynamic> json, {String? key}) {
    // RTDB에서 넘어온 JSON 딕셔너리를 Dart 표준으로 캐스팅
    return RoomPlayer(
      uid: key ?? json['uid'] as String? ?? '',
      nickname: json['nickname'] as String? ?? 'Player',
      profileImageUrl: json['profileImageUrl'] as String? ?? '',
      isConnected: json['isConnected'] as bool? ?? true,
      seatIndex: json['seatIndex'] as int? ?? -1,
      role: json['role'] as String? ?? 'player',
      status: json['status'] as String? ?? 'active',
      isHost: json['isHost'] as bool? ?? false,
      penaltyAttemptCount: json['penaltyAttemptCount'] as int ?? 0,
    );
  }

  final String uid;
  final String nickname;
  final String profileImageUrl;
  final bool isConnected;
  final int seatIndex;
  final String role;
  final String status;
  final DateTime? joinedAt;
  final DateTime? updatedAt;
  final int penaltyAttemptCount;
  final bool isHost;

  bool get isPlayer => role == 'player';
  bool get isActive => status == 'active';
}
