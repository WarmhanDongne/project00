import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:project00/core/sound/app_sounds.dart';
import 'package:project00/core/sound/providers/sound_provider.dart';
import 'package:project00/core/sound/sound_effects.dart';
import 'package:project00/core/time/server_clock.dart';

/// 마감 직전 [leadTime] 동안 초읽기 소리를 냅니다.
///
/// 화면의 남은 초와 소리를 맞추려면 1초 주기 갱신에 기대면 안 됩니다. 그
/// 방식은 갱신 시점이 마감과 어긋난 만큼(최대 1초) 소리가 밀립니다. 그래서
/// 마감까지 남은 시간을 재서 **정확히 [leadTime] 전에 한 번** 재생을 겁니다.
/// [AppSounds.timer]가 그 구간에 맞춰 만들어져 있어, 재생만 하면 초읽기가
/// 남은 초와 함께 떨어집니다.
///
/// 사용법 — 타이머를 가진 화면·위젯의 State에서:
/// ```dart
/// final _tick = CountdownTickCue();
///
/// @override
/// void didChangeDependencies() {
///   super.didChangeDependencies();
///   _tick.attach(context);
/// }
///
/// // 서버 마감이 정해지거나 바뀔 때마다
/// _tick.schedule(controller.turnDeadlineAt);
///
/// @override
/// void dispose() {
///   _tick.stop();
///   super.dispose();
/// }
/// ```
class CountdownTickCue {
  /// 초읽기가 시작되는 시점(마감까지 남은 시간)입니다.
  ///
  /// [AppSounds.timer]가 1초 간격 다섯 번으로 만들어져 있으므로 5초입니다.
  /// 이 값만 바꾸면 소리와 남은 초가 어긋납니다. 파일도 함께 바꾸세요.
  static const Duration leadTime = Duration(seconds: 5);

  SoundProvider? _sound;
  Timer? _startTimer;
  int? _scheduledDeadline;
  bool _isPlaying = false;

  /// 사운드 Provider를 붙잡아 둡니다. `didChangeDependencies`에서 호출하세요.
  ///
  /// `dispose`에서는 `context.read`를 쓸 수 없으므로 미리 보관해야 화면을
  /// 떠날 때 확실히 멈출 수 있습니다.
  void attach(BuildContext context) {
    _sound ??= SoundEffects.of(context);
  }

  /// [deadlineAt]의 [leadTime] 전에 초읽기가 시작되도록 예약합니다.
  ///
  /// 서버 상태가 갱신될 때마다 불러도 됩니다. 마감이 그대로면 예약을 유지해
  /// 초읽기가 중간에 끊기거나 두 번 겹치지 않습니다. 마감이 바뀌거나 null이
  /// 되면(턴 종료, 단계 전환) 재생 중인 소리도 함께 멈춥니다.
  void schedule(int? deadlineAt) {
    if (deadlineAt == _scheduledDeadline) return;

    _reset();
    _scheduledDeadline = deadlineAt;
    if (deadlineAt == null) return;

    final delay = ServerClock.remainingUntil(deadlineAt) - leadTime;
    // 이미 초읽기 구간 안이면(재접속 등) 중간부터 울리지 않습니다. 남은 초와
    // 어긋나게 들리는 초읽기는 없는 것만 못합니다.
    if (delay.isNegative) return;

    _startTimer = Timer(delay, _play);
  }

  /// 초읽기를 멈춥니다. 화면의 `dispose`에서 반드시 호출하세요.
  void stop() {
    _reset();
    _scheduledDeadline = null;
  }

  void _play() {
    final sound = _sound;
    if (sound == null) return;

    _isPlaying = true;
    _run(sound.playSustainedEffect(AppSounds.timer));
  }

  void _reset() {
    _startTimer?.cancel();
    _startTimer = null;

    if (!_isPlaying) return;
    _isPlaying = false;

    // 초읽기는 마감 전에 스스로 끝납니다. 마감이 지난 뒤의 정지 요청은 이미
    // 끝난 소리를 향한 것이므로 보내지 않습니다. 같은 채널을 쓰는 다른
    // 효과음(룰렛)이 그 사이에 시작됐다면 그것까지 끊기 때문입니다.
    final deadline = _scheduledDeadline;
    if (deadline != null && ServerClock.hasPassed(deadline)) return;

    _run(_sound?.stopSustainedEffect());
  }

  void _run(Future<void>? operation) {
    if (operation == null) return;
    unawaited(
      operation.catchError((Object error) {
        // 사운드는 보조 기능이라 실패해도 게임 진행을 막지 않습니다.
        debugPrint('초읽기 소리를 재생하지 못했습니다: $error');
      }),
    );
  }
}
