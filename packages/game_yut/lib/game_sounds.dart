/// 윷놀이 게임에서 사용하는 효과음입니다.
abstract final class YutSounds {
  /// 윷놀이 태블릿 게임 중 반복 재생하는 배경음악입니다.
  static const background =
      'packages/game_yut/assets/games/yut/sounds/yut_background.m4a';

  /// 태블릿에서 새 윷 결과를 공개할 때 재생합니다.
  static const throwSticks =
      'packages/game_yut/assets/games/yut/sounds/yut_throw.mp3';

  /// 짧고 겹쳐 재생되지 않는 게임 효과음입니다.
  static const preloadTargets = [throwSticks];
}
