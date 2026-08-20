import 'package:flutter/foundation.dart';

/// 화면에 표시하는 플레이어 한 명입니다.
///
/// 밤 지목(P2~P4) · 낮 투표(P7) · 관전 명단(P8)이 같은 모델을 씁니다.
///
/// **신분은 여기 없습니다.** 공개된 신분은 컨트롤러의 `revealedRoleOf`,
/// 관전자용 전원 신분표는 `spectatorRoles`로 따로 옵니다.
@immutable
class MafiaPlayer {
  const MafiaPlayer({
    required this.uid,
    required this.nickname,
    required this.profileImageUrl,
    this.seatIndex = 0,
    this.isAlive = true,
    this.deathCause,
    this.diedRound,
  });

  final String uid;
  final String nickname;
  final String profileImageUrl;

  /// 태블릿 좌석 배치와 정렬 순서에 씁니다.
  final int seatIndex;

  final bool isAlive;

  /// 사망 사유입니다. `nightAttack` · `execution` · `left`.
  /// 살아 있으면 null입니다.
  final String? deathCause;

  /// 사망한 라운드입니다.
  final int? diedRound;

  factory MafiaPlayer.fromMap(String key, Map<Object?, Object?> map) {
    final uid = map['uid']?.toString();
    return MafiaPlayer(
      uid: (uid == null || uid.isEmpty) ? key : uid,
      nickname: map['nickname']?.toString() ?? '플레이어',
      profileImageUrl: map['profileImageUrl']?.toString() ?? '',
      seatIndex: (map['seatIndex'] as num?)?.toInt() ?? 0,
      // 서버는 살아 있는 사람에게 status를 보내므로 기본값을 alive로 둡니다.
      isAlive: (map['status']?.toString() ?? 'alive') == 'alive',
      deathCause: map['deathCause']?.toString(),
      diedRound: (map['diedRound'] as num?)?.toInt(),
    );
  }

  /// 밤에 죽었는지입니다. 아침 발표 연출이 씁니다.
  bool get diedAtNight => deathCause == 'nightAttack';

  /// 처형됐는지입니다.
  bool get wasExecuted => deathCause == 'execution';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MafiaPlayer &&
          other.uid == uid &&
          other.nickname == nickname &&
          other.profileImageUrl == profileImageUrl &&
          other.seatIndex == seatIndex &&
          other.isAlive == isAlive &&
          other.deathCause == deathCause &&
          other.diedRound == diedRound;

  @override
  int get hashCode => Object.hash(
    uid,
    nickname,
    profileImageUrl,
    seatIndex,
    isAlive,
    deathCause,
    diedRound,
  );
}
