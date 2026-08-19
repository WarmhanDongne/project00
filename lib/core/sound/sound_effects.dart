import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:project00/core/sound/providers/sound_provider.dart';
import 'package:provider/provider.dart';

/// 위젯에서 효과음을 안전하게 재생합니다.
///
/// [SoundProvider]가 없는 환경(위젯 테스트, 사운드 초기화 실패 등)에서는 조용히
/// 넘어갑니다. 사운드는 보조 기능이라 없다고 해서 연출이나 게임 진행이 막히면
/// 안 됩니다.
abstract final class SoundEffects {
  /// 위젯이 붙잡아 둘 수 있는 [SoundProvider]입니다.
  ///
  /// dispose에서는 `context.read`를 쓸 수 없으므로, 정지까지 책임져야 하는
  /// 위젯은 이 값을 필드에 담아두고 사용하세요.
  static SoundProvider? of(BuildContext context) => _providerOf(context);

  static SoundProvider? _providerOf(BuildContext context) {
    try {
      return context.read<SoundProvider>();
    } catch (_) {
      return null;
    }
  }

  /// 짧은 효과음을 1회 재생합니다. 여러 개가 겹쳐 재생될 수 있습니다.
  static void play(BuildContext context, String assetPath) {
    _run(_providerOf(context)?.playEffect(assetPath));
  }

  static void _run(Future<void>? operation) {
    if (operation == null) return;
    unawaited(
      operation.catchError((Object error) {
        debugPrint('효과음을 재생하지 못했습니다: $error');
      }),
    );
  }
}
