import 'package:project00/core/sound/app_sounds.dart';

/// Final Call 전용 사운드 경로입니다.
///
/// 두 게임 이상이 함께 쓰는 소리는 `core/sound/app_sounds.dart`에 둡니다.
abstract final class FinalCallSounds {
  /// 게임 진행 중 반복 재생하는 배경음악입니다(라이어스 포커와 같은 곡, 확정).
  ///
  /// 효과음이 아니라 BGM 전용 플레이어로 재생합니다. 반복 재생이므로 게임
  /// 화면을 떠날 때 반드시 멈춰야 합니다([GameBackgroundMusic] 사용).
  /// 파이널콜 전용 곡이 생기면 이 상수만 새 파일 경로로 바꾸세요.
  static const background = AppSounds.background;

  /// 라운드 결과에서 하트가 네 조각으로 갈라지는 순간 재생합니다.
  static const heartbreak = 'assets/games/final_call/sounds/heartbreak.mp3';

  /// 게임 진입 준비 단계에서 미리 풀어 둘 효과음입니다.
  ///
  /// 하트 파열음은 라운드에 한 번만 나는 소리라 미리 준비하지 않으면 첫
  /// 재생이 화면보다 늦습니다.
  static const preloadTargets = [heartbreak];
}
