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
    this.characterId = 'frog',
    this.seatIndex = 0,
    this.isAlive = true,
    this.deathCause,
    this.diedRound,
  });

  final String uid;
  final String nickname;
  final String profileImageUrl;

  /// 로비에서 고른 동물 아이콘 id입니다(예: `frog`).
  ///
  /// 프로필 사진을 올리지 않은 사람은 이 아이콘으로 보입니다. 서버가 이 값을
  /// 보내지 않아 마피아 화면에서만 카드 뒷면이 나왔습니다(2026-08).
  final String characterId;

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
      characterId: map['characterId']?.toString() ?? 'frog',
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
          other.characterId == characterId &&
          other.seatIndex == seatIndex &&
          other.isAlive == isAlive &&
          other.deathCause == deathCause &&
          other.diedRound == diedRound;

  @override
  int get hashCode => Object.hash(
    uid,
    nickname,
    profileImageUrl,
    characterId,
    seatIndex,
    isAlive,
    deathCause,
    diedRound,
  );
}
