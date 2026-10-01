// [game_background_music.dart] 는 여러 게임이 함께 사용하는 게임 진행 단계에 맞는 음악과 효과음을 관리하는 파일이다.
//
// - [Package] : 게임 공통 기반
// - [Sound] : 게임 진행 단계에 맞는 음악과 효과음을 관리함
//
// 즉, 서버 진행 상태와 소리 재생 시점을 맞추기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:game_kit/core/sound/providers/sound_provider.dart';
import 'package:game_kit/core/sound/sound_effects.dart';
// ============================================================

/// 게임 화면이 살아 있는 동안 배경음악을 관리합니다.
///
/// 배경음악은 반복 재생이라, 멈추지 않으면 게임을 나간 뒤에도 계속 들립니다.
/// 시작과 정지를 화면마다 따로 쓰면 한쪽을 빠뜨리기 쉬우므로 여기에 묶습니다.
///
/// 사용법 — 태블릿 게임 화면 State에서:
/// ```dart
/// final _bgm = GameBackgroundMusic();
///
/// @override
/// void didChangeDependencies() {
///   super.didChangeDependencies();
///   _bgm.attach(context);
/// }
///
/// // 카드 분배 단계에 들어갈 때
/// _bgm.start(LiarsPokerSounds.background);
///
/// @override
/// void dispose() {
///   _bgm.stop();
///   super.dispose();
/// }
/// ```
class GameBackgroundMusic {
  SoundProvider? _sound;
  bool _isPlaying = false;
  bool _isPlaybackRequested = false;
  int _operationGeneration = 0;

  /// 배경음악이 재생 중인지 여부입니다.
  bool get isPlaying => _isPlaying;

  /// 사운드 Provider를 붙잡아 둡니다. `didChangeDependencies`에서 호출하세요.
  ///
  /// `dispose`에서는 `context.read`를 쓸 수 없으므로 미리 보관해야 화면을 떠날
  /// 때 확실히 멈출 수 있습니다.
  void attach(BuildContext context) {
    _sound ??= SoundEffects.of(context);
  }

  /// 배경음악을 시작합니다. 이미 재생 중이면 아무것도 하지 않습니다.
  ///
  /// 라운드마다 카드 분배가 반복되므로 두 번째 호출부터는 무시합니다. 그렇지
  /// 않으면 라운드가 넘어갈 때마다 곡이 처음으로 되감깁니다.
  ///
  /// [asset]은 게임마다 다릅니다. 각 게임의 `sound/<game>_sounds.dart`에 있는
  /// 값을 넘기세요. 곡을 바꾸려면 [stop]으로 멈춘 뒤 다시 부릅니다.
  void start(String asset) {
    if (_isPlaybackRequested) return;

    final sound = _sound;
    if (sound == null) return;

    _isPlaybackRequested = true;
    final generation = ++_operationGeneration;
    unawaited(
      sound
          .playBgm(asset)
          .then((_) {
            // stop/fadeOut이 더 나중에 호출됐다면 이 재생 완료는
            // 현재 상태를 다시 되돌리지 않습니다.
            if (generation == _operationGeneration && _isPlaybackRequested) {
              _isPlaying = true;
            } else if (!_isPlaybackRequested) {
              // 재생이 완료되기 전 stop/fadeOut이 들어온 경우, 늦게 시작된
              // 네이티브 재생이 화면을 나간 뒤 남지 않도록 한 번 더 멈춥니다.
              _run(sound.stopBgm(), '배경음악을 멈추지 못했습니다');
            }
          })
          .catchError((Object error) {
            if (generation == _operationGeneration) {
              _isPlaybackRequested = false;
              _isPlaying = false;
            }
            // 사운드는 보조 기능이라 실패해도 게임 진행을 막지 않습니다.
            debugPrint('배경음악을 재생하지 못했습니다: $error');
          }),
    );
  }

  /// 배경음악을 멈춥니다. 화면의 `dispose`에서 반드시 호출하세요.
  void stop() {
    if (!_isPlaybackRequested && !_isPlaying) return;

    _isPlaybackRequested = false;
    _isPlaying = false;
    _operationGeneration += 1;
    _run(_sound?.stopBgm(), '배경음악을 멈추지 못했습니다');
  }

  /// 배경음악을 **서서히 줄이며** 멈춥니다.
  ///
  /// 장면이 바뀌는 순간에 씁니다(마피아는 아침이 될 때 밤 곡을 이렇게
  /// 내립니다). 곧바로 [start]를 부르면 페이드는 버려지고 새 곡이 제 볼륨으로
  /// 시작합니다.
  ///
  /// ⚠️ 화면의 `dispose`에서는 [stop]을 쓰세요. 화면이 사라진 뒤에도 소리가
  /// 몇 초 더 들리면 안 됩니다.
  void fadeOut({Duration duration = const Duration(milliseconds: 1200)}) {
    if (!_isPlaybackRequested && !_isPlaying) return;

    _isPlaybackRequested = false;
    _isPlaying = false;
    _operationGeneration += 1;
    _run(_sound?.fadeOutBgm(duration: duration), '배경음악을 서서히 줄이지 못했습니다');
  }

  void _run(Future<void>? operation, String message) {
    if (operation == null) return;
    unawaited(
      operation.catchError((Object error) {
        // 사운드는 보조 기능이라 실패해도 게임 진행을 막지 않습니다.
        debugPrint('$message: $error');
      }),
    );
  }
}
