import 'dart:async';
import 'dart:math' as math;
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
import 'package:project00/games/mafia/sound/mafia_bgm_plan.dart';
import 'package:project00/games/mafia/sound/mafia_sounds.dart';
import 'package:project00/games/mafia/sound/mafia_night_cue_speaker.dart';
import 'package:project00/games/shared/player_layouts/player_layout_model.dart';
import 'package:project00/games/shared/sound/countdown_tick_cue.dart';
import 'package:project00/games/shared/sound/game_background_music.dart';
import 'package:project00/games/shared/widgets/game_interruption_layer.dart';
import 'package:project00/games/shared/widgets/game_turn_countdown.dart';
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

  /// 진행 명령이 실패·드롭됐을 때 다시 시도하는 타이머입니다.
  ///
  /// 아침·개표 같은 발표 단계는 마감이 없어 [_scheduleDeadlineCheck]가 아무
  /// 일도 하지 않습니다. 이 타이머가 없으면 한 번 실패한 단계는 영원히
  /// 넘어가지 않습니다(진행자가 수동 재시작해야 복구).
  Timer? _advanceRetryTimer;
  Timer? _stageTimer;

  //=======================밤 늑대 하울링 (확정 2026-08)==============================
  // 밤마다 한 번, 무작위 시각에 멀리서 늑대가 웁니다. 정해진 시각이면 몇 판만
  // 해도 박자가 읽혀 분위기가 죽습니다.
  /// 밤이 시작되고 이만큼 지난 뒤부터 울릴 수 있습니다.
  static const Duration _howlEarliest = Duration(seconds: 10);

  /// 밤이 끝나기 이만큼 전까지만 울립니다.
  ///
  /// 하울링은 약 6초입니다. 여유를 두지 않으면 소리가 아침 발표로 넘어가거나
  /// 마지막 5초 초읽기와 겹칩니다.
  static const Duration _howlLatestBeforeEnd = Duration(seconds: 12);

  Timer? _howlTimer;
  final math.Random _howlRandom = math.Random();

  /// 지금 깔아 둔 곡입니다. null이면 아무것도 깔지 않은 상태입니다.
  String? _bgmAsset;

  //=======================직업 효과음 (확정 2026-08)==============================
  // 총성 등 직업 소리는 밤이 시작될 때 자동으로 울리지 않고, 그 직업이
  // **선택을 완료한 순간** 이 태블릿에서 울립니다. 서버가 행동 종류만 담은
  // 신호를 올려 주고(`public.nightActionCue`), 여기서 소리로 옮깁니다.
  //
  // 휴대폰에서 내지 않는 이유: 그 사람의 기기에서 총성이 나면 옆 사람에게
  // 마피아가 그대로 드러납니다. 방 가운데 태블릿은 누가 냈는지 알려 주지
  // 않으면서 모두에게 같은 순간을 들려줍니다.
  /// 신호를 소리로 옮기는 규칙입니다([MafiaNightCueSpeaker]).
  final MafiaNightCueSpeaker _nightCueSpeaker = MafiaNightCueSpeaker();

  //=======================밤 시작 안내 (확정 흐름)==============================
  // 전원 확인 → 10초 대기 → '밤이 되었습니다' 안내 2.5초 → 서버에 밤 시작.
  // 확인 제한(서버 1분)이 끝나도 같은 안내를 거쳐 넘어갑니다.
  static const Duration _nightNoticeDelay = Duration(seconds: 10);
  static const Duration _nightNoticeHold = Duration(milliseconds: 2500);

  /// 진행 명령이 실패했을 때 다시 시도하기까지의 간격입니다.
  ///
  /// 서버가 '아직 마감 전'이라고 답한 경우에도 이 간격으로 다시 물어보므로,
  /// 시계 오차만큼만 짧게 반복하고 마감이 지나면 곧바로 넘어갑니다.
  static const Duration _advanceRetryDelay = Duration(seconds: 3);

  /// 서버 시각 보정을 아직 못 받았을 때 다시 확인하기까지의 간격입니다.
  static const Duration _clockSyncRecheck = Duration(milliseconds: 500);
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
    _advanceRetryTimer?.cancel();
    _stageTimer?.cancel();
    _howlTimer?.cancel();
    _nightNoticeTimer?.cancel();
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
    _playNightActionCue(game);
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
    _howlTimer?.cancel();
    if (stage == MafiaTabletStage.night) _scheduleWolfHowl(game);
    if (stage == MafiaTabletStage.finished) _playWinVoice(game);
    final hold = stage.announcementHold;
    if (hold == null) return;

    // 발표 연출은 정해진 시간만 보여 준 뒤 서버에 완료를 알립니다.
    _stageTimer = Timer(hold, () {
      if (!mounted) return;
      _advance(game, stage);
    });
  }

  /// 이번 밤의 늑대 하울링을 무작위 시각에 한 번 예약합니다.
  ///
  /// 밤은 조기 종료가 없어 마감까지 반드시 이어지므로, 마감 기준으로 잡으면
  /// 밤 길이가 바뀌어도 알아서 따라갑니다. 남은 시간이 창(窓)보다 짧으면
  /// (재접속으로 밤 끝자락에 붙은 경우) 이번 밤은 건너뜁니다.
  void _scheduleWolfHowl(MafiaController game) {
    final deadline = game.turnDeadlineAt;
    if (deadline == null) return;

    final latest = ServerClock.remainingUntil(deadline) - _howlLatestBeforeEnd;
    if (latest <= _howlEarliest) return;

    final spanMs = (latest - _howlEarliest).inMilliseconds;
    final delay =
        _howlEarliest + Duration(milliseconds: _howlRandom.nextInt(spanMs + 1));
    _howlTimer = Timer(delay, () {
      // 밤을 벗어났으면 울리지 않습니다.
      if (!mounted || _stage != MafiaTabletStage.night) return;
      SoundEffects.play(context, MafiaSounds.wolfHowl);
    });
  }

  /// 승리 발표에 이긴 진영 나레이션을 한 번 냅니다.
  ///
  /// 방 가운데 태블릿에서만 냅니다 — 휴대폰까지 같이 울리면 말이 겹칩니다.
  /// 중립 개별 승리는 아직 파일이 없어 조용히 지나갑니다.
  void _playWinVoice(MafiaController game) {
    final voice = MafiaSounds.winVoiceFor(game.winnerFaction);
    if (voice == null) return;
    SoundEffects.play(context, voice);
  }

  /// 누군가 밤 행동을 마친 순간 그 직업의 효과음을 냅니다.
  ///
  /// 낼지 말지는 [MafiaNightCueSpeaker]가 정합니다(같은 신호 두 번 금지,
  /// 붙는 순간의 신호 금지).
  void _playNightActionCue(MafiaController game) {
    final sound = _nightCueSpeaker.soundFor(game.nightActionCue);
    if (sound == null) return;
    SoundEffects.play(context, sound);
  }

  /// 단계에 맞는 곡을 깔거나 내립니다([mafiaBackgroundMusicFor]).
  ///
  /// 확정(2026-08): **밤에만** 곡이 깔립니다. 아침이 되면 서서히 작아지며
  /// 사라집니다 — 뚝 끊으면 소리만 먼저 사라져 화면 전환과 어긋납니다.
  void _syncBackgroundMusic(MafiaController game) {
    final target = mafiaBackgroundMusicFor(
      isNight: game.isNight,
      isFinished: game.isFinished,
    );
    if (target == _bgmAsset) return;
    _bgmAsset = target;

    if (target == null) {
      _bgm.fadeOut(duration: mafiaBgmFadeOut);
      return;
    }
    // 곡을 갈아 끼울 때는 지금 곡을 확실히 멈춰야 겹쳐 들리지 않습니다.
    _bgm.stop();
    _bgm.start(target);
  }

  /// 전원이 역할을 확인하면 10초 뒤 밤 안내를 예약합니다(확정 흐름).
  void _maybeScheduleNightNotice(MafiaController game) {
    if (_stage != MafiaTabletStage.roleDeal || _nightNoticeScheduled) return;
    final total = game.players.length;
    if (total == 0 || game.roleConfirmedCount < total) return;

    _nightNoticeScheduled = true;
    _nightNoticeTimer = Timer(_nightNoticeDelay, _showNightNotice);
  }

  /// '밤이 되었습니다'를 잠시 보여 준 뒤 서버에 밤 시작을 알립니다.
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
    // 서버 시각 보정이 도착하기 전의 '마감 지남' 판단은 기기 시계 오차일 수
    // 있습니다. 그 상태로 진행 명령을 보내면 서버가 아직 마감 전이라고
    // 응답하고, 그 단계는 재시도 없이 멈춥니다([ServerClock.hasSynced] 주석
    // 참고). 보정이 올 때까지 판단을 미룹니다.
    if (deadline != null && !ServerClock.hasSynced) {
      _deadlineTimer = Timer(_clockSyncRecheck, () {
        if (!mounted) return;
        final current = _controller;
        if (current != null) _scheduleDeadlineCheck(current);
      });
      return;
    }
    // 역할 확인의 제한시간(서버 1분)이 끝나면 곧바로 넘기지 않고 같은
    // '밤이 되었습니다' 안내를 거칩니다.
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
        if (success || !mounted || _advancedPhaseKey != key) return;
        // 실패·드롭·'아직 마감 전' 응답이면 표시를 풀고 다시 시도합니다.
        // 다른 명령이 진행 중이라 드롭된 경우(commandInFlight)와 발표 단계처럼
        // 마감이 없어 재시도 경로가 없는 경우를 모두 이 타이머가 받습니다.
        _advancedPhaseKey = null;
        _advanceRetryTimer?.cancel();
        _advanceRetryTimer = Timer(_advanceRetryDelay, () {
          if (!mounted || _stage != stage) return;
          final current = _controller;
          if (current != null) _advance(current, stage);
        });
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
          // 태블릿 토론 타이머도 1초마다 움직여야 합니다. 서버 상태만 보고
          // 그리면 상태가 안 바뀌는 동안 숫자가 굳습니다(2026-08 수정).
          GameTurnCountdown(
            expiresAt: game.turnDeadlineAt,
            builder: (context, remaining) => MafiaTabletStageView(
              stage: _stage,
              controller: game,
              playerLayout: widget.playerLayout,
              remainingSeconds: remaining?.inSeconds,
              showsNightNotice: _showsNightNotice,
              onRulebookPressed: _openRulebook,
              onSettingsPressed: () => _openSettings(game),
              onRestart: () => unawaited(game.restartGame()),
              onHome: () => unawaited(_endGameAndLeave(game)),
            ),
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
        // ⚠️ 여기서 다이얼로그를 닫지 마세요. 공용 설정 다이얼로그가 버튼을
        // 누른 순간 **이미 닫고 나서** 이 콜백을 부릅니다. 여기서 한 번 더
        // 닫으면 그 pop이 게임 화면을 닫아, 설정에서 재시작·종료를 누르면
        // 게임이 그대로 튕겨 나갔습니다(2026-08 수정).
        onRestartGame: () => unawaited(game.restartGame()),
        onEndGame: () => unawaited(_endGameAndLeave(game)),
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
