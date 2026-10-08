/// 홀덤에서 사용하는 공용 칩 효과음의 번들 경로입니다.
abstract final class HoldemSounds {
  static const chipLanding = 'packages/game_kit/assets/sounds/poker_chips.mp3';
  static const background = chipLanding;

  static const preloadTargets = [chipLanding];
}
