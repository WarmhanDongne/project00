import 'package:project00/core/sound/app_sounds.dart';
import 'package:project00/games/final_call/models/final_call_models.dart';

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

  /// 우승 팀 발표(태블릿 결과 화면)가 뜨는 순간 한 번 재생합니다.
  ///
  /// 폰에서는 재생하지 않습니다. 같은 방의 여러 기기가 동시에 울리면
  /// 소리가 겹치므로 방 중앙의 태블릿만 냅니다.
  static const win = 'assets/games/final_call/sounds/win.mp3';

  //=======================나레이션(사람 목소리)==============================
  // 받은 파일(2026-08-22 Take4)입니다. 방 가운데 태블릿에서만 냅니다.

  /// **'콜!'** 나레이션입니다(0.8초). CALL 선언이 확정되는 순간 재생합니다.
  static const voiceCall = 'assets/games/final_call/sounds/voice_call.m4a';

  /// 블루팀 승리 발표에 재생합니다(1.5초).
  static const voiceWinBlue =
      'assets/games/final_call/sounds/voice_win_blue.m4a';

  /// 레드팀 승리 발표에 재생합니다(1.4초).
  static const voiceWinRed = 'assets/games/final_call/sounds/voice_win_red.m4a';

  /// 무승부 발표에 재생합니다(1.0초).
  static const voiceDraw = 'assets/games/final_call/sounds/voice_draw.m4a';

  /// 결과에 맞는 나레이션입니다.
  static String resultVoiceFor({
    required bool isDraw,
    required FinalCallTeam? winningTeam,
  }) {
    if (isDraw) return voiceDraw;
    return winningTeam == FinalCallTeam.blue ? voiceWinBlue : voiceWinRed;
  }

  /// 게임 진입 준비 단계에서 미리 풀어 둘 효과음입니다.
  ///
  /// 하트 파열음·승리음처럼 한 판에 한 번만 나는 소리는 미리 준비하지
  /// 않으면 첫 재생이 화면보다 늦습니다.
  /// 여러 사람이 동시에 눌러 겹쳐 날 수 있는 짧은 소리입니다. 사본을 여러 개
  /// 물려 둡니다.
  static const preloadTargets = [heartbreak, win];

  /// 한 번에 하나만 나는 안내 음성입니다. **[preloadTargets]와 나눠 둡니다** —
  /// 겹칠 일이 없어 사본 하나로 충분하고, 사본을 아껴야 기기 디코더가 모자라
  /// 준비가 실패하는 일이 없습니다(2026-08 iOS 사고).
  static const narrationTargets = [
    voiceCall,
    voiceWinBlue,
    voiceWinRed,
    voiceDraw,
  ];
}
