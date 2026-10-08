/// 홀덤에서 사용하는 효과음과 배경음악의 번들 경로입니다.
abstract final class HoldemSounds {
  static const chipLanding = 'packages/game_kit/assets/sounds/poker_chips.mp3';
  static const background =
      'packages/game_kit/assets/sounds/holdem_background.mp3';

  static const preloadTargets = [chipLanding];
}
