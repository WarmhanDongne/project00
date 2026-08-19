import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:project00/core/sound/app_sounds.dart';
import 'package:project00/core/sound/providers/sound_provider.dart';
import 'package:project00/core/sound/sound_effects.dart';

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
/// _bgm.start();
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
  void start() {
    if (_isPlaying) return;

    final sound = _sound;
    if (sound == null) return;

    _isPlaying = true;
    _run(sound.playBgm(AppSounds.background), '배경음악을 재생하지 못했습니다');
  }

  /// 배경음악을 멈춥니다. 화면의 `dispose`에서 반드시 호출하세요.
  void stop() {
    if (!_isPlaying) return;

    _isPlaying = false;
    _run(_sound?.stopBgm(), '배경음악을 멈추지 못했습니다');
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
