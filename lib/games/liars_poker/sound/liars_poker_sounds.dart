/// Liar's Poker 전용 효과음 경로입니다.
///
/// 두 게임이 함께 쓰는 소리는 `core/sound/app_sounds.dart`에 둡니다.
abstract final class LiarsPokerSounds {
  /// 좌석에서 중앙으로 패를 던질 때와, 그 패를 뒤집어 공개할 때 재생합니다.
  static const submit = 'assets/games/liars_poker/sounds/submit.mp3';

  /// 게임 진행 중 반복 재생하는 배경음악입니다.
  ///
  /// 효과음이 아니라 BGM 전용 플레이어로 재생합니다. 반복 재생이므로 게임
  /// 화면을 떠날 때 반드시 멈춰야 합니다([GameBackgroundMusic] 사용).
  static const background =
      'assets/games/liars_poker/sounds/background/background.mp3';

  /// 게임 진입 준비 단계에서 미리 풀어 둘 효과음입니다.
  static const preloadTargets = [submit];
}
