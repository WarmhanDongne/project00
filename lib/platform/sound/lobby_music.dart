// [lobby_music.dart] 는 로비와 상점에서 흐르는 배경음악을 관리하는 파일이다.
//
// - [Platform] : 태블릿 로비·상점
// - [Sound] : 보이는 화면의 곡만 재생하고, 게임으로 넘어가면 멈춤
//
// 즉, 화면이 겹치고 바뀌어도 곡이 하나만 흐르게 하기 위해 필요한 파일이다.

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:game_kit/sound/providers/sound_provider.dart';
import 'package:game_kit/sound/sound_effects.dart';

/// 로비·상점 배경음악 경로입니다.
abstract final class LobbyTracks {
  static const lobby = 'assets/sounds/lobby.m4a';
  static const store = 'assets/sounds/store.m4a';
}

/// [child]가 화면에 보이는 동안 [track]을 반복 재생합니다.
///
/// - 위에 불투명 화면(게임·자리 배치)이 덮이면 멈추고, 다시 드러나면 이어서
///   재생합니다. 설정 같은 모달이 떠도 계속 흐릅니다.
/// - 상점처럼 위에 겹친 화면이 자기 곡을 가지면 가장 최근에 보인 화면의
///   곡이 이깁니다.
/// - 앱이 백그라운드로 가면 멈추고 돌아오면 다시 재생합니다.
///
/// 게임 배경음악과 같은 BGM 채널을 쓰므로 볼륨 설정을 그대로 따릅니다.
class LobbyMusic extends StatefulWidget {
  const LobbyMusic({super.key, required this.track, required this.child});

  final String track;
  final Widget child;

  @override
  State<LobbyMusic> createState() => _LobbyMusicState();
}

class _LobbyMusicState extends State<LobbyMusic> {
  late final _LobbyClaim _claim = _LobbyClaim(widget.track);
  SoundProvider? _sound;
  Animation<double>? _cover;
  bool _visible = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sound ??= SoundEffects.of(context);
    final visible = TickerMode.valuesOf(context).enabled;
    final cover = ModalRoute.of(context)?.secondaryAnimation;
    if (!identical(cover, _cover)) {
      _cover?.removeStatusListener(_handleCover);
      _cover = cover?..addStatusListener(_handleCover);
    }
    if (visible == _visible) return;
    _visible = visible;
    if (visible) {
      _claimWhenUncovered();
    } else {
      _LobbyMusicDirector.instance.release(_claim);
    }
  }

  @override
  void didUpdateWidget(LobbyMusic oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.track != widget.track) {
      _claim.track = widget.track;
      _LobbyMusicDirector.instance.refresh();
    }
  }

  /// 게임 화면이 닫히는 중이면 그 화면이 배경음악을 멈춘 뒤에 시작합니다.
  void _claimWhenUncovered() {
    final cover = _cover;
    if (cover != null && cover.status != AnimationStatus.dismissed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_visible) return;
      final sound = _sound;
      if (sound == null) return;
      _LobbyMusicDirector.instance.claim(_claim, sound);
    });
  }

  void _handleCover(AnimationStatus status) {
    if (status == AnimationStatus.dismissed && _visible) _claimWhenUncovered();
  }

  @override
  void dispose() {
    _cover?.removeStatusListener(_handleCover);
    _LobbyMusicDirector.instance.release(_claim);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _LobbyClaim {
  _LobbyClaim(this.track);

  String track;
}

/// 보이는 로비 화면들 중 가장 최근 것의 곡 하나만 재생합니다.
class _LobbyMusicDirector with WidgetsBindingObserver {
  _LobbyMusicDirector._();

  static final instance = _LobbyMusicDirector._();

  final List<_LobbyClaim> _claims = [];
  SoundProvider? _sound;
  String? _playing;
  bool _foreground = true;
  bool _observing = false;

  void claim(_LobbyClaim claim, SoundProvider sound) {
    _sound = sound;
    _claims
      ..remove(claim)
      ..add(claim);
    if (!_observing) {
      _observing = true;
      WidgetsBinding.instance.addObserver(this);
    }
    refresh();
  }

  void release(_LobbyClaim claim) {
    if (!_claims.remove(claim)) return;
    refresh();
  }

  void refresh() {
    final want = _foreground && _claims.isNotEmpty ? _claims.last.track : null;
    if (want == _playing) return;
    final sound = _sound;
    if (sound == null) return;
    _playing = want;
    _run(want == null ? sound.stopBgm() : sound.playBgm(want));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    // inactive(알림 센터 등)에서는 그대로 두고, 실제로 나갔을 때만 멈춥니다.
    if (!foreground && state == AppLifecycleState.inactive) return;
    if (foreground == _foreground) return;
    _foreground = foreground;
    refresh();
  }

  void _run(Future<void> operation) {
    unawaited(
      operation.catchError((Object error) {
        // 사운드는 보조 기능이라 실패해도 로비 사용을 막지 않습니다.
        debugPrint('로비 배경음악을 바꾸지 못했습니다: $error');
      }),
    );
  }
}
