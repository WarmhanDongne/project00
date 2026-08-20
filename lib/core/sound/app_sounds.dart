/// 여러 게임이 함께 쓰는 공용 효과음 경로입니다.
///
/// 게임 전용 사운드는 `lib/games/<game>/sound/`에 따로 둡니다. 여기에는
/// `assets/sounds/`에 있는 것만 모읍니다.
abstract final class AppSounds {
  // 배경음악은 여기 없습니다. 게임마다 다른 곡을 쓸 수 있어야 하므로
  // 각 게임의 `sound/<game>_sounds.dart`에 두고 `GameBackgroundMusic.start`에
  // 넘깁니다. 마피아는 낮·밤 두 곡을 씁니다.

  /// 카드가 한 장씩 날아갈 때마다 재생하는 짧은 효과음입니다.
  static const dealing = 'assets/sounds/dealing.mp3';

  /// 벌칙 결과 도장이 프로필에 찍히는 순간 재생하는 효과음입니다.
  ///
  /// 도장이 내려오기 시작할 때가 아니라 실제로 닿는 순간(진행도 0.30)에
  /// 재생합니다.
  static const stamp = 'assets/sounds/stamp.mp3';

  /// 벌칙 룰렛의 레버를 끝까지 내렸을 때 한 번 재생하는 효과음입니다.
  ///
  /// 레버가 실제로 잠기는 순간에만 재생합니다. 임계점에 못 미쳐 손을 뗀 뒤
  /// 레버가 제자리로 돌아가는 경우에는 재생하지 않습니다.
  static const lever = 'assets/sounds/lever.mp3';

  /// 앱 시작 직후 미리 준비할 짧은 효과음입니다.
  ///
  /// 준비하지 않으면 첫 재생에서 에셋을 파일로 풀어내며 소리가 화면보다 늦게
  /// 납니다. 도장처럼 한 게임에 한 번만 나는 소리는 매번 그 지연을 겪으므로
  /// 반드시 여기에 넣습니다.
  ///
  /// [roulette]은 파일이 길고 전용 플레이어로 한 번만 재생되므로 제외합니다.
  static const preloadTargets = [dealing, lever, stamp];

  /// 벌칙 룰렛이 도는 동안 재생하는 긴 효과음입니다.
  ///
  /// 파일이 룰렛 회전(4초)보다 길어서, 재생만 하고 두면 연출이 끝난 뒤에도
  /// 소리가 남습니다. 반드시 정지 가능한 채널로 재생하세요.
  static const roulette = 'assets/sounds/roulette.mp3';
}
