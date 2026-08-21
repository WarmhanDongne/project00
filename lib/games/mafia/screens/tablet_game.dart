import 'dart:async';
import 'package:project00/games/mafia/loading/mafia_loading.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:project00/core/assets/game_asset_store.dart';
import 'package:project00/core/layout/app_orientation.dart';
import 'package:project00/core/layout/app_system_ui.dart';
import 'package:project00/core/sound/sound_effects.dart';
import 'package:project00/core/time/server_clock.dart';
import 'package:project00/games/mafia/controllers/mafia_controller.dart';
import 'package:project00/games/mafia/mafia_copy.dart';
import 'package:project00/games/mafia/models/mafia_roles.dart';
import 'package:project00/games/mafia/providers/mafia_game_state.dart';
import 'package:project00/games/mafia/providers/mafia_session_provider.dart';
import 'package:project00/games/mafia/screens/tablet/tablet_game_layout.dart';
import 'package:project00/games/mafia/screens/tablet/tablet_game_stage.dart';
import 'package:project00/games/mafia/services/mafia_service.dart';
import 'package:project00/games/mafia/sound/mafia_sounds.dart';
import 'package:project00/games/shared/player_layouts/player_layout_model.dart';
import 'package:project00/games/shared/sound/countdown_tick_cue.dart';
import 'package:project00/games/shared/sound/game_background_music.dart';
import 'package:project00/games/shared/widgets/game_interruption_layer.dart';
import 'package:project00/games/shared/widgets/tablet_game_rulebook_dialog.dart';
import 'package:project00/games/shared/widgets/tablet_game_settings_dialog.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';

//=======================마피아 태블릿 화면==============================
/// 태블릿은 **진행을 넘기는 쪽**입니다.
///
/// 서버는 스스로 시간을 재지 않습니다. 제한시간이 끝났거나 발표 연출이 끝났음을
/// 태블릿이 알려 줘야 다음 단계로 갑니다. 그래서 이 화면이 없으면 게임이
/// 밤에서 멈춥니다.
///
/// | 단계 | 태블릿이 하는 일 |
/// |---|---|
/// | `roleReveal` | 카드 분배 연출 → `completeRoleReveal` |
/// | `night` | 마감까지 대기 → `timeoutNight` |
/// | `morning` | 사망자 발표 → `completeMorning` |
/// | `day` | 토론 마감까지 대기 → `timeoutDay` |
/// | `voting` | 투표 마감까지 대기 → `timeoutVote` |
/// | `voteResult` | 개표·처형 발표 → `completeVoteResult` |
///
/// **개인 노드를 구독하지 않습니다.** 태블릿 화면에 신분이 흘러들면 옆에서 보는
/// 사람에게 다 드러납니다.
class MafiaTabletGame extends ConsumerStatefulWidget {
  const MafiaTabletGame({
    super.key,
    required this.roomCode,
    required this.gameService,
    required this.playerLayout,
    required this.provider,
  });

  final String roomCode;
  final MafiaService gameService;
  final PlayerLayoutModel playerLayout;
  final RoomProvider provider;

  @override
  ConsumerState<MafiaTabletGame> createState() => _MafiaTabletGameState();
}

class _MafiaTabletGameState extends ConsumerState<MafiaTabletGame> {
  MafiaController? _controller;
  ProviderSubscription<MafiaGameState>? _subscription;
  final GameBackgroundMusic _bgm = GameBackgroundMusic();

  /// 밤·토론·투표의 마지막 5초 초읽기 소리입니다.
  ///
  /// 마피아의 제한시간은 같은 순간에 모두의 휴대폰에 함께 뜹니다. 기기마다
  /// 울리면 방 안에서 여러 번 겹쳐 들리므로, 우승 발표와 같이 방 가운데
  /// 태블릿에서만 냅니다.
  final CountdownTickCue _countdownTick = CountdownTickCue();

  /// 지금 화면에 보여 주는 단계입니다. 서버 단계를 연출 단위로 옮긴 값입니다.
  MafiaTabletStage _stage = MafiaTabletStage.connecting;

  /// 이미 서버에 넘긴 단계입니다. 같은 단계를 두 번 넘기지 않게 막습니다.
  String? _advancedPhaseKey;
  Timer? _deadlineTimer;
  Timer? _stageTimer;
  bool _isNightMusic = false;

  //=======================밤 시작 안내 (확정 흐름)==============================
  // 전원 확인 → 10초 대기 → '밤이 됐습니다' 안내 2.5초 → 서버에 밤 시작.
  // 확인 제한(서버 1분)이 끝나도 같은 안내를 거쳐 넘어갑니다.
  /// 밤 총성까지의 지연입니다(배경 전환 0.9초 + 한 박자).
  static const Duration _nightGunshotDelay = Duration(milliseconds: 1500);
  Timer? _gunshotTimer;

  static const Duration _nightNoticeDelay = Duration(seconds: 10);
  static const Duration _nightNoticeHold = Duration(milliseconds: 2500);
  Timer? _nightNoticeTimer;
  bool _showsNightNotice = false;
  bool _nightNoticeScheduled = false;

  @override
  void initState() {
    super.initState();
    unawaited(AppSystemUi.enterGameFullscreen());
    unawaited(AppOrientation.lockTabletGameLandscape());
    unawaited(GameAssetStore.instance.prepareGame('mafia').catchError((_) {}));
    // 배경·달·새 등 첫 연출 이미지를 미리 디코딩합니다. context가 필요한
    // 작업이라 첫 프레임 뒤로 미룹니다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(preloadMafiaAssets(context, isPhone: false));
    });

    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final args = MafiaSessionArgs(
      roomCode: widget.roomCode,
      uid: uid,
      service: widget.gameService,
      // 태블릿은 신분을 받지 않습니다.
      watchPrivate: false,
    );
    final provider = mafiaSessionProvider(args);
    _subscription = ref.listenManual(provider, (_, _) => _handleState());
    _controller = ref.read(provider.notifier);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bgm.attach(context);
    _countdownTick.attach(context);
  }

  @override
  void dispose() {
    _deadlineTimer?.cancel();
    _stageTimer?.cancel();
    _nightNoticeTimer?.cancel();
    _gunshotTimer?.cancel();
    _bgm.stop();
    _countdownTick.stop();
    _subscription?.close();
    unawaited(AppOrientation.lockPlatformPortrait());
    unawaited(AppSystemUi.showPlatformSystemBars());
    super.dispose();
  }

  //=======================단계 해석 — 한곳에서만==============================
  void _handleState() {
    final game = _controller;
    if (game == null || !mounted) return;

    final nextStage = resolveMafiaTabletStage(game);
    if (nextStage != _stage) {
      _stage = nextStage;
      _onStageEntered(game, nextStage);
      // 단계가 바뀌면 밤 안내 상태를 처음으로 돌립니다(재시작 대비).
      _nightNoticeTimer?.cancel();
      _showsNightNotice = false;
      _nightNoticeScheduled = false;
    }
    _maybeScheduleNightNotice(game);
    _syncBackgroundMusic(game);
    _scheduleDeadlineCheck(game);
    // 제한시간이 있는 단계(밤·토론·투표)에서만 초읽기를 겁니다. 역할 확인은
    // 마감이 있어도 화면에 남은 시간을 보여 주지 않으므로 제외합니다.
    _countdownTick.schedule(_stage.hasDeadline ? game.turnDeadlineAt : null);
    setState(() {});
  }

  /// 단계에 처음 들어온 순간 한 번만 하는 일입니다.
  void _onStageEntered(MafiaController game, MafiaTabletStage stage) {
    _stageTimer?.cancel();
    _gunshotTimer?.cancel();
    if (stage == MafiaTabletStage.night) {
      // 확정(2026-08): 밤이 되면 마피아의 총성이 태블릿에서 울립니다.
      // 배경 라디얼 와이프(0.9초)가 끝나고 한 박자 쉰 뒤에 울립니다.
      _gunshotTimer = Timer(_nightGunshotDelay, () {
        if (!mounted || _stage != MafiaTabletStage.night) return;
        SoundEffects.play(context, MafiaSounds.gunshot);
      });
    }
    final hold = stage.announcementHold;
    if (hold == null) return;

    // 발표 연출은 정해진 시간만 보여 준 뒤 서버에 완료를 알립니다.
    _stageTimer = Timer(hold, () {
      if (!mounted) return;
      _advance(game, stage);
    });
  }

  /// 낮·밤에 따라 곡을 갈아 끼웁니다.
  void _syncBackgroundMusic(MafiaController game) {
    if (game.isFinished) {
      _bgm.stop();
      return;
    }
    final wantsNight = game.isNight;
    if (_bgm.isPlaying && wantsNight == _isNightMusic) return;
    _bgm.stop();
    _isNightMusic = wantsNight;
    _bgm.start(
      wantsNight ? MafiaSounds.nightBackground : MafiaSounds.background,
    );
  }

  /// 전원이 역할을 확인하면 10초 뒤 밤 안내를 예약합니다(확정 흐름).
  void _maybeScheduleNightNotice(MafiaController game) {
    if (_stage != MafiaTabletStage.roleDeal || _nightNoticeScheduled) return;
    final total = game.players.length;
    if (total == 0 || game.roleConfirmedCount < total) return;

    _nightNoticeScheduled = true;
    _nightNoticeTimer = Timer(_nightNoticeDelay, _showNightNotice);
  }

  /// '밤이 됐습니다'를 잠시 보여 준 뒤 서버에 밤 시작을 알립니다.
  void _showNightNotice() {
    if (!mounted || _stage != MafiaTabletStage.roleDeal) return;
    setState(() => _showsNightNotice = true);
    _nightNoticeTimer = Timer(_nightNoticeHold, () {
      if (!mounted) return;
      final game = _controller;
      if (game != null) _advance(game, MafiaTabletStage.roleDeal);
    });
  }

  /// 마감이 있는 단계는 시간이 지났을 때 서버에 알립니다.
  ///
  /// 서버는 스스로 시간을 재지 않으므로 이 호출이 없으면 그 단계에서 멈춥니다.
  /// 마감 전 호출은 서버가 무시하므로 조금 늦게 불러도 안전합니다.
  void _scheduleDeadlineCheck(MafiaController game) {
    _deadlineTimer?.cancel();
    final deadline = game.turnDeadlineAt;
    final stage = _stage;
    // 역할 확인의 제한시간(서버 1분)이 끝나면 곧바로 넘기지 않고 같은
    // '밤이 됐습니다' 안내를 거칩니다.
    if (stage == MafiaTabletStage.roleDeal) {
      if (deadline == null || _nightNoticeScheduled) return;
      if (ServerClock.hasPassed(deadline)) {
        _nightNoticeScheduled = true;
        _showNightNotice();
        return;
      }
      _deadlineTimer = Timer(
        ServerClock.remainingUntil(deadline) +
            const Duration(milliseconds: 250),
        () {
          if (!mounted || _nightNoticeScheduled) return;
          _nightNoticeScheduled = true;
          _showNightNotice();
        },
      );
      return;
    }
    if (deadline == null || !stage.hasDeadline) return;

    if (ServerClock.hasPassed(deadline)) {
      _advance(game, stage);
      return;
    }
    final remaining = ServerClock.remainingUntil(deadline);
    _deadlineTimer = Timer(remaining + const Duration(milliseconds: 250), () {
      if (!mounted) return;
      _advance(game, _stage);
    });
  }

  /// 서버에 다음 단계로 넘기라고 알립니다. 같은 단계는 한 번만 넘깁니다.
  void _advance(MafiaController game, MafiaTabletStage stage) {
    final key = '${stage.name}_${game.round}';
    if (_advancedPhaseKey == key) return;
    _advancedPhaseKey = key;
    final command = stage.advance(game);
    if (command == null) return;
    unawaited(
      command().then((success) {
        // 실패하면 다시 시도할 수 있게 표시를 풀어 줍니다.
        if (!success && mounted && _advancedPhaseKey == key) {
          _advancedPhaseKey = null;
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final game = _controller;
    if (game == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 낮·밤 배경입니다. 태블릿용 가로 고해상도 파일을 씁니다.
          MafiaTabletBackground(isNight: game.isNight),
          MafiaTabletStageView(
            stage: _stage,
            controller: game,
            playerLayout: widget.playerLayout,
            remainingSeconds: _remainingSeconds(game),
            showsNightNotice: _showsNightNotice,
            onRulebookPressed: _openRulebook,
            onSettingsPressed: () => _openSettings(game),
            onRestart: () => unawaited(game.restartGame()),
            onHome: () => unawaited(_endGameAndLeave(game)),
          ),
          GameInterruptionLayer(
            interruption: game.interruption,
            currentUid: FirebaseAuth.instance.currentUser?.uid ?? '',
            isSubmitting: game.commandInFlight,
            onVote: () async {
              await game.voteToContinueInterruption();
            },
            onExpired: game.expireInterruption,
          ),
        ],
      ),
    );
  }

  /// 남은 시간(초)입니다. 마감이 없는 단계면 null입니다.
  int? _remainingSeconds(MafiaController game) {
    final deadline = game.turnDeadlineAt;
    if (deadline == null) return null;
    final remaining = ServerClock.remainingUntil(deadline);
    return remaining.isNegative ? 0 : remaining.inSeconds;
  }

  //=======================룰북·설정==============================
  void _openRulebook() {
    showDialog<void>(
      context: context,
      builder: (_) => TabletGameRulebookDialog(
        title: '마피아',
        markdown: MafiaCopy.tabletRulebook,
        // 역할 카드를 함께 보여 줍니다. 규칙을 읽으며 카드를 대조할 수 있습니다.
        cardImages: [
          for (final role in MafiaRoles.implemented)
            if (role.card != null) role.card!,
        ],
      ),
    );
  }

  void _openSettings(MafiaController game) {
    showDialog<void>(
      context: context,
      builder: (_) => TabletGameSettingsDialog(
        provider: widget.provider,
        onRestartGame: () {
          Navigator.of(context).pop();
          unawaited(game.restartGame());
        },
        onEndGame: () {
          Navigator.of(context).pop();
          unawaited(_endGameAndLeave(game));
        },
      ),
    );
  }

  /// 게임을 끝내고 화면을 즉시 닫습니다.
  ///
  /// 정리되는 모습(프로필이 사라지는 장면)을 보여 주지 않기 위해 서버 응답을
  /// 받은 뒤 곧바로 닫습니다.
  Future<void> _endGameAndLeave(MafiaController game) async {
    final ended = await game.endGame();
    if (!mounted || !ended) return;
    Navigator.of(context).maybePop();
  }
}
