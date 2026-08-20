/// Final Call 전용 사운드 경로입니다.
///
/// 두 게임 이상이 함께 쓰는 소리는 `core/sound/app_sounds.dart`에 둡니다.
abstract final class FinalCallSounds {
  /// 게임 진행 중 반복 재생하는 배경음악입니다.
  ///
  /// 효과음이 아니라 BGM 전용 플레이어로 재생합니다. 반복 재생이므로 게임
  /// 화면을 떠날 때 반드시 멈춰야 합니다([GameBackgroundMusic] 사용).
  static const background =
      'assets/games/final_call/sounds/background/background.mp3';
}
