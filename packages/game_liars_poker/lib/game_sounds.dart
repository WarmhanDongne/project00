// [game_sounds.dart] 라이어스 포커에서 사용하는
// 배경음·효과음·음성 자산의 경로를 관리하는 파일이다.

// ========================[ import ]==========================
import 'package:game_kit/sound/app_sounds.dart';

// ============================================================
/// Liar's Poker 전용 효과음 경로입니다.

abstract final class LiarsPokerSounds {
  /// 좌석에서 중앙으로 패를 던질 때와, 그 패를 뒤집어 공개할 때 재생합니다.
  static const submit =
      'packages/game_liars_poker/assets/games/liars_poker/sounds/submit.mp3';
  static const win =
      'packages/game_liars_poker/assets/games/liars_poker/sounds/win.mp3';
  static const voiceLiar =
      'packages/game_liars_poker/assets/games/liars_poker/sounds/voice_liar.m4a';
  static const background = AppSounds.background;
  static const preloadTargets = [submit, win];
  static const narrationTargets = [voiceLiar];
}
