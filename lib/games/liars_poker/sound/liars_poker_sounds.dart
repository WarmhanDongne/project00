import 'package:project00/core/sound/app_sounds.dart';

/// Liar's Poker 전용 효과음 경로입니다.
///
/// 두 게임이 함께 쓰는 소리는 `core/sound/app_sounds.dart`에 둡니다.
abstract final class LiarsPokerSounds {
  /// 좌석에서 중앙으로 패를 던질 때와, 그 패를 뒤집어 공개할 때 재생합니다.
  static const submit = 'assets/games/liars_poker/sounds/submit.mp3';

  /// 우승자 발표(태블릿 결과 화면)가 뜨는 순간 한 번 재생합니다.
  ///
  /// 폰에서는 재생하지 않습니다. 같은 방의 여러 기기가 동시에 울리면
  /// 소리가 겹치므로 방 중앙의 태블릿만 냅니다.
  static const win = 'assets/games/liars_poker/sounds/win.mp3';

  /// **'라이어!'** 나레이션입니다(1.4초, 2026-08-22 Take3-1).
  ///
  /// 누군가 라이어를 선언해 패가 공개되는 순간, 방 가운데 태블릿에서만 냅니다.
  static const voiceLiar = 'assets/games/liars_poker/sounds/voice_liar.m4a';

  /// 게임 진행 중 반복 재생하는 배경음악입니다(파이널콜과 같은 곡, 확정).
  ///
  /// 효과음이 아니라 BGM 전용 플레이어로 재생합니다. 반복 재생이므로 게임
  /// 화면을 떠날 때 반드시 멈춰야 합니다([GameBackgroundMusic] 사용).
  /// 라이어스 포커 전용 곡이 생기면 이 상수만 새 파일 경로로 바꾸세요.
  static const background = AppSounds.background;

  /// 게임 진입 준비 단계에서 미리 풀어 둘 효과음입니다.
  ///
  /// 승리음처럼 한 게임에 한 번만 나는 소리는 미리 준비하지 않으면 첫
  /// 재생이 화면보다 늦습니다.
  static const preloadTargets = [submit, win, voiceLiar];
}
