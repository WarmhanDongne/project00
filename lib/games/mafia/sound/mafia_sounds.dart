import 'package:project00/core/sound/app_sounds.dart';

/// 마피아 전용 효과음 경로입니다.
///
/// 여러 게임이 함께 쓰는 소리(카드 분배·룰렛 등)는
/// `core/sound/app_sounds.dart`에 있습니다. 여기에는 마피아만 쓰는 것만 둡니다.
abstract final class MafiaSounds {
  /// 사망·처형을 발표하는 순간 재생하는 총성입니다.
  ///
  /// 아침 발표(사망자 공개)와 처형 발표에 함께 씁니다. 연출이 시작될 때가
  /// 아니라 **결과가 드러나는 순간**에 재생하세요.
  static const gunshot = 'assets/games/mafia/sounds/gun.mp3';

  /// 투표를 제출했을 때 재생합니다.
  static const vote = 'assets/games/mafia/sounds/vote.mp3';

  /// 마피아 승리 결과 화면에서 재생합니다.
  ///
  /// 시민 승리용 소리는 아직 없습니다. 파일이 들어오면 여기에 추가하고
  /// 결과 화면에서 승리 진영으로 갈라 쓰면 됩니다.
  static const mafiaWin = 'assets/games/mafia/sounds/win_mafia.mp3';

  /// 낮 동안 깔리는 배경음악입니다.
  ///
  /// 효과음이 아니라 **BGM 채널**로 재생합니다
  /// (`shared/sound/game_background_music.dart`). 반복 재생이므로 화면을 떠날 때
  /// 반드시 멈춰야 합니다. 그래서 [preloadTargets]에 넣지 않습니다.
  ///
  /// ⚠️ 지금은 공용 곡과 같은 파일이라 임시로 공용 상수를 참조합니다(용량
  /// 절약). 마피아 전용 낮 곡이 들어오면 파일을 넣고 이 상수만 바꾸세요.
  static const background = AppSounds.background;

  /// 밤 동안 깔리는 배경음악입니다. 낮과 곡을 갈아 끼워 분위기를 바꿉니다.
  ///
  /// 곡을 바꿀 때는 `GameBackgroundMusic.stop()` 뒤에 다시 `start()`를 부릅니다.
  static const nightBackground =
      'assets/games/mafia/sounds/background/background_night.mp3';

  /// 게임 진입 준비 단계에서 미리 풀어 둘 짧은 효과음입니다.
  ///
  /// 준비하지 않으면 첫 재생에서 에셋을 파일로 풀어내며 소리가 화면보다 늦게
  /// 납니다. 총성·승리음은 게임에 한 번만 나므로 매번 그 지연을 겪습니다.
  static const preloadTargets = [gunshot, vote, mafiaWin];
}
