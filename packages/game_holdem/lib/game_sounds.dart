import 'package:game_kit/sound/app_sounds.dart';

/// 홀덤에서 사용하는 효과음과 배경음악의 번들 경로입니다.
/// 새 음원은 앱 빌드에 포함해야 합니다(코드 패치만으로 전달되지 않습니다).
abstract final class HoldemSounds {
  static const dealing = AppSounds.dealing;
  // 라이어스 포커 submit.mp3와 동일한 음원의 공용 번들 사본입니다.
  static const cardTable = 'packages/game_kit/assets/sounds/card_table.mp3';
  static const check = 'packages/game_kit/assets/sounds/holdem_check.wav';
  static const allIn = 'packages/game_kit/assets/sounds/holdem_all_in.mp3';
  static const potAward =
      'packages/game_kit/assets/sounds/holdem_pot_award.mp3';
  static const chipLanding = 'packages/game_kit/assets/sounds/poker_chips.mp3';
  static const background =
      'packages/game_kit/assets/sounds/holdem_background.mp3';

  static const preloadTargets = [
    dealing,
    cardTable,
    check,
    allIn,
    potAward,
    chipLanding,
  ];
}
