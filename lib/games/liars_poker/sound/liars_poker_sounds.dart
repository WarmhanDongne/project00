/// Liar's Poker 전용 효과음 경로입니다.
///
/// 두 게임이 함께 쓰는 소리는 `core/sound/app_sounds.dart`에 둡니다.
abstract final class LiarsPokerSounds {
  /// 좌석에서 중앙으로 패를 던질 때와, 그 패를 뒤집어 공개할 때 재생합니다.
  static const submit = 'assets/sounds/liars_poker/submit.mp3';

  /// 게임 진입 준비 단계에서 미리 풀어 둘 효과음입니다.
  static const preloadTargets = [submit];
}
