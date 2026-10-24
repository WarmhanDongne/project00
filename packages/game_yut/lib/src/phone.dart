import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_kit/models/game_room_context.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:game_kit/phone/widgets/exit_modal.dart';
import 'package:game_kit/phone/widgets/ripple_dialog.dart';
import 'package:game_kit/phone/widgets/rulebook_dialog.dart';
import 'package:game_yut/src/timing.dart';
import 'package:game_yut/src/service.dart';
import 'package:game_yut/src/session.dart';
import 'package:game_yut/src/theme.dart';
import 'package:game_yut/src/view.dart';
import 'package:game_yut/src/widgets.dart';

class YutPhoneScreen extends ConsumerStatefulWidget {
  const YutPhoneScreen({
    super.key,
    required this.roomCode,
    required this.provider,
    required this.gameId,
    required this.onExitRoom,
  });
  final String roomCode;
  final GameRoomContext provider;
  final String gameId;
  final Future<bool> Function() onExitRoom;

  @override
  ConsumerState<YutPhoneScreen> createState() => _YutPhoneScreenState();
}

class _YutPhoneScreenState extends ConsumerState<YutPhoneScreen>
    with WidgetsBindingObserver {
  static const _motionChannel = EventChannel('mosigame/yut_motion/events');
  late final _service = YutService();
  StreamSubscription<dynamic>? _motionSubscription;

  /// 흔들 때 화면 속 윷을 움직이기 위한 가속도 흐름입니다.
  final _motionKicks = StreamController<Offset>.broadcast();
  Timer? _shakeStopTimer;
  DateTime? _shakeStartedAt;
  DateTime? _lastHapticAt;
  bool _motionListening = false;
  bool _motionAvailable = true;
  bool _isShaking = false;
  bool _throwing = false;
  int? _throwRollAt;
  String? _sendingChoiceKey;
  bool _busy = false;
  bool _reportedReady = false;
  bool _exitOpen = false;
  bool _leaving = false;

  /// 아직 제출하지 않은 앞·뒤 선택입니다. 차례가 바뀌면 앞면으로 돌아갑니다.
  bool _front = true;
  String _choiceKey = '';

  String get _uid => ref.read(yutUidProvider);
  YutSessionArgs get _args =>
      YutSessionArgs(roomCode: widget.roomCode, uid: _uid, watchPrivate: true);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    unawaited(
      YutImages.precache(
        context,
        edition: widget.gameId == 'strategy_yut_edition',
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _setMotionListening(false);
    } else if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _shakeStopTimer?.cancel();
    _motionSubscription?.cancel();
    _motionKicks.close();
    super.dispose();
  }

  void _setMotionListening(bool shouldListen) {
    if (_motionListening == shouldListen) return;
    _motionListening = shouldListen;
    _shakeStopTimer?.cancel();
    _shakeStartedAt = null;
    _lastHapticAt = null;
    if (!shouldListen) {
      _motionSubscription?.cancel();
      _motionSubscription = null;
      if (mounted && _isShaking) setState(() => _isShaking = false);
      return;
    }
    try {
      _motionSubscription = _motionChannel.receiveBroadcastStream().listen(
        _onMotion,
        onError: (_) {
          _motionAvailable = false;
          _setMotionListening(false);
          if (mounted) setState(() {});
        },
      );
    } catch (_) {
      _motionAvailable = false;
      _setMotionListening(false);
    }
  }

  /// 흔드는 동안 진동하고, 480ms 멈추면 서버에 한 번 던집니다.
  void _onMotion(dynamic event) {
    if (event is! List || event.length < 3 || _throwing || _busy) return;
    final x = (event[0] as num?)?.toDouble();
    final y = (event[1] as num?)?.toDouble();
    final z = (event[2] as num?)?.toDouble();
    if (x == null || y == null || z == null) return;
    // iOS(CoreMotion)는 안드로이드와 부호가 반대라 맞춰서 보냅니다.
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    _motionKicks.add(ios ? Offset(-x, -y) : Offset(x, y));
    final acceleration = (math.sqrt(x * x + y * y + z * z) - 9.81).abs();
    if (acceleration < 2.2) return;
    final now = DateTime.now();
    _shakeStartedAt ??= now;
    _shakeStopTimer?.cancel();
    if (!_isShaking && mounted) setState(() => _isShaking = true);
    if (_lastHapticAt == null ||
        now.difference(_lastHapticAt!) >= const Duration(milliseconds: 170)) {
      _lastHapticAt = now;
      HapticFeedback.mediumImpact();
    }
    _shakeStopTimer = Timer(const Duration(milliseconds: 480), () {
      final started = _shakeStartedAt;
      if (started == null ||
          DateTime.now().difference(started) <
              const Duration(milliseconds: 500)) {
        if (mounted) setState(() => _isShaking = false);
        _shakeStartedAt = null;
        return;
      }
      unawaited(_submitRoll());
    });
  }

  Future<void> _submitRoll() async {
    if (_throwing || _busy) return;
    final game = YutGameView.fromPublic(
      widget.gameId,
      ref.read(yutSessionProvider(_args)).publicState,
    );
    if (!game.rolling || game.turnUid != _uid || game.paused) return;
    _throwRollAt = game.lastRoll?.createdAt;
    _shakeStopTimer?.cancel();
    _setMotionListening(false);
    if (mounted) {
      setState(() {
        _throwing = true;
        _isShaking = false;
      });
    }
    final ok = await _run(() => _service.command.roll(widget.roomCode));
    // 성공 응답이 공개 snapshot보다 빨라도 윷이 다시 손에 나타나지 않습니다.
    if (mounted && !ok) setState(() => _throwing = false);
  }

  Future<void> _submitChoice() async {
    if (_busy || _sendingChoiceKey == _choiceKey) return;
    final key = _choiceKey;
    final front = _front;
    setState(() => _sendingChoiceKey = key);
    final ok = await _run(
      () => _service.command.choose(widget.roomCode, front),
    );
    if (mounted && !ok && _sendingChoiceKey == key) {
      setState(() => _sendingChoiceKey = null);
    }
  }

  Future<bool> _run(Future<Map<String, dynamic>> Function() action) async {
    if (_busy) return false;
    setState(() => _busy = true);
    try {
      return await ref.read(yutSessionProvider(_args).notifier).execute(action);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestExit(Offset origin) async {
    if (_leaving || _exitOpen) return;
    _exitOpen = true;
    final edition = widget.gameId == 'strategy_yut_edition';
    final leave = await SharedPhoneExitModal.show(
      context,
      origin: origin,
      doorImage: Icon(
        Icons.door_front_door_outlined,
        size: 96,
        color: edition ? YutColors.lilac : YutColors.blue,
      ),
      imageHeight: 130,
      maxWidth: 340,
      surfaceColor: edition ? YutColors.nightPanel : YutColors.paperLight,
      primaryColor: edition ? YutColors.lilac : YutColors.blue,
      titleColor: edition ? YutColors.moon : YutColors.ink,
      descriptionColor: edition ? YutColors.haze : YutColors.muted,
    );
    _exitOpen = false;
    if (leave != true || !mounted) return;
    _leaving = true;
    final left = await widget.onExitRoom();
    if (!mounted) return;
    if (left) {
      Navigator.of(context).pop(true);
      return;
    }
    _leaving = false;
  }

  void _showRules(Offset origin) {
    showPhoneRippleDialog<void>(
      context: context,
      origin: origin,
      builder: (_) => PhoneGameRulebookDialog(
        title: YutCopy.gameTitle(widget.gameId),
        markdown: YutCopy.rulesMarkdown(widget.gameId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(yutSessionProvider(_args));
    if (!_reportedReady) {
      _reportedReady = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref
              .read(yutSessionProvider(_args).notifier)
              .reportScreenReady(assetsReady: true);
        }
      });
    }
    final game = YutGameView.fromPublic(widget.gameId, session.publicState);
    final submitted = session.privateState['choiceSubmitted'] == true;
    final choiceKey = '${game.round}:${game.pool.length}:${game.phase}';
    if (submitted || game.paused || _sendingChoiceKey != choiceKey) {
      _sendingChoiceKey = null;
    }
    if (_throwing &&
        (game.lastRoll?.createdAt != _throwRollAt ||
            !game.rolling ||
            game.turnUid != _uid ||
            game.paused)) {
      _throwing = false;
    }
    if (choiceKey != _choiceKey) {
      _choiceKey = choiceKey;
      _front = true;
    }
    final canShake =
        !game.strategy &&
        game.rolling &&
        game.turnUid == _uid &&
        !game.paused &&
        !_busy &&
        !_throwing;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _setMotionListening(
          canShake &&
              WidgetsBinding.instance.lifecycleState ==
                  AppLifecycleState.resumed,
        );
      }
    });
    final edition = game.edition;
    return Scaffold(
      backgroundColor: edition ? YutColors.night : YutColors.paper,
      body: YutBackground(
        edition: edition,
        tablet: false,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    if (edition)
                      Text(
                        'SPECIAL EDITION',
                        style: const TextStyle(
                          fontFamily: 'BodoniModa',
                          fontSize: 12,
                          letterSpacing: 5,
                          fontWeight: FontWeight.w600,
                          color: YutColors.lilac,
                        ),
                      ),
                    const Spacer(),
                    YutIconButton(
                      icon: Icons.menu_book_outlined,
                      label: YutCopy.rules,
                      edition: edition,
                      onPressed: _showRules,
                    ),
                    const SizedBox(width: 10),
                    YutIconButton(
                      icon: Icons.door_front_door_outlined,
                      label: YutCopy.exit,
                      edition: edition,
                      onPressed: _requestExit,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (game.paused) ...[
                  _PhoneNotice(edition: edition),
                  const SizedBox(height: 10),
                ],
                Expanded(
                  child: !game.loaded
                      ? Center(
                          child: CircularProgressIndicator(
                            color: edition ? YutColors.lilac : YutColors.blue,
                          ),
                        )
                      : AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: KeyedSubtree(
                            key: ValueKey(_stageKey(game, submitted)),
                            child: _stage(game, submitted),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _stageKey(YutGameView game, bool submitted) {
    if (game.finished) return 'finished';
    if (game.selecting) return 'select';
    if (game.rolling && game.turnUid == _uid) return 'shake';
    return 'wait-${game.phase}-${game.turnOwner}';
  }

  Widget _stage(YutGameView game, bool submitted) {
    final me = game.player(_uid);
    if (game.finished) return _PhoneResult(game: game, meUid: _uid);
    if (game.selecting) {
      return _ChoiceStage(
        game: game,
        me: me,
        front: _front,
        submitted: submitted,
        busy: _busy || _sendingChoiceKey == _choiceKey,
        onFlip: () => setState(() => _front = !_front),
        onPick: (front) => setState(() => _front = front),
        onSubmit: _submitChoice,
      );
    }
    if (game.rolling && game.turnUid == _uid) {
      return _ShakeStage(
        game: game,
        me: me,
        shaking: _isShaking,
        throwing: _throwing,
        motionAvailable: _motionAvailable,
        busy: _busy,
        onThrow: _submitRoll,
        motion: _motionKicks.stream,
      );
    }
    return _WaitStage(game: game, meUid: _uid);
  }
}

/// 팀 색 띠와 남은 시간입니다.
class _TurnBand extends StatelessWidget {
  const _TurnBand({
    required this.game,
    required this.team,
    required this.title,
    required this.subtitle,
    this.showTimer = true,
  });
  final YutGameView game;
  final YutTeam? team;
  final String title;
  final String subtitle;
  final bool showTimer;

  @override
  Widget build(BuildContext context) {
    final edition = game.edition;
    final style = YutTeamStyle.of(team);
    final white = style.piece == 'piece_white';
    final fg = edition ? YutColors.moon : style.ink;
    final lead = showTimer && game.deadlineAt > 0
        ? YutTimerRing(
            deadlineAt: game.deadlineAt,
            total: YutTiming.turn,
            color: edition
                ? YutColors.night
                : white
                ? YutColors.inkSoft
                : style.fill,
            track: edition
                ? YutColors.nightEdge
                : white
                ? YutColors.edgeShadow
                : YutColors.blueLine,
            fill: edition ? YutColors.moon : const Color(0xFFFFFDF7),
          )
        : Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFFDF7),
              border: Border.all(
                color: edition ? YutColors.lilac : YutColors.inkSoft,
                width: 2,
              ),
            ),
            child: Icon(
              Icons.tablet_mac_rounded,
              color: edition ? YutColors.night : YutColors.inkSoft,
            ),
          );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: edition
            ? YutColors.nightPanel
            : white
            ? YutColors.paperLight
            : style.fill,
        borderRadius: BorderRadius.circular(edition ? 12 : 6),
        border: edition
            ? Border.all(color: YutColors.lilac, width: 2)
            : white
            ? Border.all(color: YutColors.edge, width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: edition ? Colors.black54 : style.shadow,
            offset: const Offset(0, 5),
          ),
          const BoxShadow(
            color: Color(0x2E3C2814),
            offset: Offset(8, 14),
            blurRadius: 16,
          ),
        ],
      ),
      child: Row(
        children: [
          lead,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                edition
                    ? YutHoloText(title, style: YutFonts.title(22))
                    : Text(title, style: YutFonts.title(22, color: fg)),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: YutFonts.text(
                    13,
                    color: edition
                        ? YutColors.haze
                        : white
                        ? YutColors.muted
                        : fg.withValues(alpha: .92),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 전략 윷놀이: 내 윷가락의 앞·뒤를 골라 제출합니다.
class _ChoiceStage extends StatelessWidget {
  const _ChoiceStage({
    required this.game,
    required this.me,
    required this.front,
    required this.submitted,
    required this.busy,
    required this.onFlip,
    required this.onPick,
    required this.onSubmit,
  });
  final YutGameView game;
  final YutPlayerView? me;
  final bool front;
  final bool submitted;
  final bool busy;
  final VoidCallback onFlip;
  final ValueChanged<bool> onPick;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final edition = game.edition;
    final myTeam = me?.team;
    final moving = game.turnTeam;
    final mine = myTeam == moving;
    final title = mine
        ? yutText(
            '우리 ${YutCopy.teamName(myTeam)} 차례예요',
            'Our ${YutCopy.teamName(myTeam)} turn',
            '轮到我们${YutCopy.teamName(myTeam)}',
            '輪到我們${YutCopy.teamName(myTeam)}',
          )
        : yutText(
            '${YutCopy.teamName(moving)} 차례 · 막아 보세요',
            '${YutCopy.teamName(moving)} turn · block it',
            '${YutCopy.teamName(moving)}回合 · 试着阻挡',
            '${YutCopy.teamName(moving)}回合 · 試著阻擋',
          );
    final subtitle = game.pool.isNotEmpty
        ? yutText(
            '한 번 더! 앞·뒤를 다시 골라요',
            'One more! Choose again',
            '再来一次！重新选择',
            '再來一次！重新選擇',
          )
        : yutText(
            '앞·뒤를 골라 두면 4명이 한꺼번에 공개돼요',
            'All four sides are revealed together',
            '四人的选择会同时公开',
            '四人的選擇會同時公開',
          );
    final locked = submitted || busy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TurnBand(
          game: game,
          team: mine ? myTeam : moving,
          title: title,
          subtitle: subtitle,
        ),
        const SizedBox(height: 14),
        _ChoiceProgress(game: game, submitted: submitted),
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              final width = math.min(
                142.0,
                (box.maxHeight - 34) / YutStick.aspect,
              );
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Semantics(
                    button: true,
                    label: yutText('윷가락 뒤집기', 'Flip the stick', '翻转柶', '翻轉柶'),
                    child: GestureDetector(
                      onTap: locked ? null : onFlip,
                      child: AnimatedSlide(
                        offset: locked ? const Offset(0, -.07) : Offset.zero,
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                        child: AnimatedScale(
                          scale: locked ? .88 : 1,
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOutCubic,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 220),
                            opacity: submitted
                                ? .55
                                : busy
                                ? .75
                                : 1,
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(end: front ? 0 : math.pi),
                              duration: const Duration(milliseconds: 550),
                              curve: const Cubic(.3, 1.4, .5, 1),
                              builder: (context, angle, _) => Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.identity()
                                  ..setEntry(3, 2, .0012)
                                  ..rotateY(angle),
                                child: YutStick(
                                  front: angle < math.pi / 2,
                                  width: width,
                                  edition: edition,
                                  characterId: me?.characterId,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        locked
                            ? Icons.lock_outline_rounded
                            : Icons.sync_rounded,
                        size: 16,
                        color: edition ? YutColors.haze : YutColors.inkSoft,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        locked
                            ? submitted
                                  ? yutText(
                                      '선택 완료',
                                      'Choice confirmed',
                                      '已确认选择',
                                      '已確認選擇',
                                    )
                                  : yutText(
                                      '선택을 보내고 있어요',
                                      'Sending your choice',
                                      '正在发送选择',
                                      '正在傳送選擇',
                                    )
                            : yutText(
                                '윷을 눌러 뒤집기',
                                'Tap the stick to flip',
                                '点击柶翻面',
                                '點擊柶翻面',
                              ),
                        style: YutFonts.text(
                          13,
                          weight: FontWeight.w700,
                          color: edition ? YutColors.haze : YutColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
        _Segment(
          edition: edition,
          front: front,
          locked: locked,
          onPick: onPick,
        ),
        const SizedBox(height: 12),
        _SubmitButton(
          edition: edition,
          submitted: submitted,
          busy: busy,
          onPressed: onSubmit,
        ),
      ],
    );
  }
}

/// 네 명 중 몇 명이 골랐는지만 보여 줍니다(무엇을 골랐는지는 숨김).
class _ChoiceProgress extends StatelessWidget {
  const _ChoiceProgress({required this.game, required this.submitted});
  final YutGameView game;
  final bool submitted;

  @override
  Widget build(BuildContext context) {
    final edition = game.edition;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 4; i++)
          Container(
            width: 26,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: i < game.choiceCount
                  ? (edition ? YutColors.lilac : YutColors.blue)
                  : (edition ? YutColors.nightEdge : const Color(0xFFD9CDB5)),
            ),
          ),
        const SizedBox(width: 8),
        Text(
          yutText(
            '${game.choiceCount}/4명 골랐어요',
            '${game.choiceCount}/4 chosen',
            '已选 ${game.choiceCount}/4',
            '已選 ${game.choiceCount}/4',
          ),
          style: YutFonts.text(
            13,
            weight: FontWeight.w700,
            color: edition ? YutColors.haze : YutColors.muted,
          ),
        ),
      ],
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.edition,
    required this.front,
    required this.locked,
    required this.onPick,
  });
  final bool edition;
  final bool front;
  final bool locked;
  final ValueChanged<bool> onPick;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: locked ? .55 : 1,
    child: Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: edition ? YutColors.nightPanel : YutColors.paperLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: edition ? YutColors.lilac : YutColors.edge,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          for (final side in [true, false])
            Expanded(
              child: Semantics(
                button: true,
                selected: front == side,
                label: side ? YutCopy.front : YutCopy.back,
                child: GestureDetector(
                  onTap: locked ? null : () => onPick(side),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: 60,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: front == side
                          ? (edition ? null : YutColors.blue)
                          : Colors.transparent,
                      gradient: front == side && edition
                          ? YutColors.holoGradient
                          : null,
                    ),
                    child: Text(
                      side ? YutCopy.front : YutCopy.back,
                      style: YutFonts.stamp(
                        30,
                        color: front == side
                            ? (edition ? YutColors.night : Colors.white)
                            : (edition ? YutColors.moon : YutColors.ink),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.edition,
    required this.submitted,
    required this.busy,
    required this.onPressed,
  });
  final bool edition;
  final bool submitted;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = submitted
        ? yutText(
            '골랐어요 · 공개를 기다려요',
            'Chosen · waiting',
            '已选择 · 等待公开',
            '已選擇 · 等待公開',
          )
        : busy
        ? yutText('선택 보내는 중…', 'Sending choice…', '正在发送…', '正在傳送…')
        : yutText('제출하기', 'Submit', '提交', '提交');
    final fg = submitted
        ? (edition ? YutColors.haze : YutColors.muted)
        : (edition ? YutColors.night : Colors.white);
    return Semantics(
      button: true,
      enabled: !submitted && !busy,
      label: label,
      child: GestureDetector(
        onTap: submitted || busy ? null : onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 58,
          decoration: BoxDecoration(
            color: submitted
                ? (edition ? YutColors.nightRaised : const Color(0xFFE6E1D6))
                : (edition ? null : YutColors.blue),
            gradient: !submitted && edition ? YutColors.holoGradient : null,
            borderRadius: BorderRadius.circular(12),
            boxShadow: submitted
                ? null
                : [
                    BoxShadow(
                      color: edition ? Colors.black : YutColors.blueDeep,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (busy && !submitted)
                SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                )
              else
                Icon(
                  submitted ? Icons.check_rounded : Icons.arrow_forward_rounded,
                  color: fg,
                  size: 20,
                ),
              const SizedBox(width: 8),
              Text(label, style: YutFonts.title(23, color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}

/// 일반 윷놀이: 휴대폰을 흔들어 네 윷을 던집니다.
class _ShakeStage extends StatefulWidget {
  const _ShakeStage({
    required this.game,
    required this.me,
    required this.shaking,
    required this.throwing,
    required this.motionAvailable,
    required this.busy,
    required this.onThrow,
    required this.motion,
  });
  final YutGameView game;
  final YutPlayerView? me;
  final bool shaking;
  final bool throwing;
  final bool motionAvailable;
  final bool busy;
  final VoidCallback onThrow;

  /// 휴대폰 가속도(화면 기준으로 정리한 x, y, m/s²)입니다.
  final Stream<Offset> motion;

  @override
  State<_ShakeStage> createState() => _ShakeStageState();
}

class _ShakeStageState extends State<_ShakeStage> with TickerProviderStateMixin {
  late final _wobble = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );

  // ── 흔들기 물리: 윷 네 개가 흔드는 방향을 따라 화면 안을 돌아다니며
  //    벽·서로에 부딪힙니다. 서 있는 채로 ±43°까지만 기울어집니다. ──
  final _random = math.Random();
  final List<Offset> _pos = List.filled(4, Offset.zero);
  final List<Offset> _vel = List.filled(4, Offset.zero);
  final List<double> _angle = List.filled(4, 0);
  final List<double> _spin = List.filled(4, 0);
  final _frame = ValueNotifier<int>(0);
  late final Ticker _ticker = createTicker(_step);
  StreamSubscription<Offset>? _motionSub;
  Duration _lastTick = Duration.zero;
  Offset _gravity = Offset.zero;
  bool _gravityReady = false;
  DateTime _lastWallHaptic = DateTime.fromMillisecondsSinceEpoch(0);

  /// 레이아웃에서 받은 무대 크기와 윷 크기입니다.
  Size _stage = Size.zero;
  double _stickW = 0;
  double get _stickH => _stickW * YutStick.aspect;
  double _slotX(int i) => (i - 1.5) * (_stickW + 12);
  double _restAngle(int i) => (i.isEven ? 1 : -1) * .05;

  @override
  void initState() {
    super.initState();
    _motionSub = widget.motion.listen(_onMotion);
  }

  @override
  void didUpdateWidget(covariant _ShakeStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.motion != widget.motion) {
      _motionSub?.cancel();
      _motionSub = widget.motion.listen(_onMotion);
    }
    if (widget.throwing && !_wobble.isAnimating) {
      _wobble.repeat(reverse: true);
    } else if (!widget.throwing && _wobble.isAnimating) {
      _wobble
        ..stop()
        ..value = 0;
    }
    if (widget.shaking) _wake();
  }

  /// 가속도에서 중력을 걸러 낸 '흔든 힘'만큼 윷을 반대쪽으로 밀어 줍니다.
  /// 휴대폰이 오른쪽으로 움직이면 안의 윷은 관성으로 왼쪽 벽에 부딪힙니다.
  void _onMotion(Offset raw) {
    if (!_gravityReady) {
      _gravity = raw;
      _gravityReady = true;
      return;
    }
    _gravity = _gravity * .82 + raw * .18;
    final linear = raw - _gravity;
    final force = linear.distance;
    if (force < 1.2 || widget.throwing) return;
    // 기기 좌표(오른쪽 +x, 위 +y) → 화면 좌표(오른쪽 +x, 아래 +y), 관성이라 반대로.
    final push = Offset(-linear.dx, linear.dy);
    for (var i = 0; i < 4; i++) {
      final scatter = .65 + _random.nextDouble() * .7;
      final jitter = Offset(
        _random.nextDouble() * 2 - 1,
        _random.nextDouble() * 2 - 1,
      );
      _vel[i] += push * (80 * scatter) + jitter * (force * 12);
      _spin[i] += (_random.nextDouble() - .5) * force * .5;
    }
    _wake();
  }

  void _wake() {
    if (!_ticker.isActive) {
      _lastTick = Duration.zero;
      _ticker.start();
    }
  }

  void _step(Duration elapsed) {
    final dt = _lastTick == Duration.zero
        ? 1 / 60
        : ((elapsed - _lastTick).inMicroseconds / 1e6).clamp(0.0, 1 / 30);
    _lastTick = elapsed;
    if (_stickW <= 0 || _stage.isEmpty) return;
    final loose = widget.shaking;
    // 흔드는 동안은 느슨하게 돌아다니고, 멈추면 제자리로 모입니다.
    final k = loose ? 5.0 : 38.0;
    final damp = loose ? 1.6 : 8.5;
    final ak = loose ? 10.0 : 30.0;
    final adamp = loose ? 3.0 : 7.0;
    var moving = false;
    var hit = 0.0;
    for (var i = 0; i < 4; i++) {
      _vel[i] += (-_pos[i] * k - _vel[i] * damp) * dt;
      _pos[i] += _vel[i] * dt;
      final da = _angle[i];
      _spin[i] += (-da * ak - _spin[i] * adamp) * dt;
      _angle[i] = (da + _spin[i] * dt).clamp(-.75, .75);

      // 화면(무대) 벽에 부딪히면 튕깁니다. 기울어진 만큼 차지하는 폭을 계산합니다.
      final a = _restAngle(i) + _angle[i];
      final halfW =
          (_stickW * math.cos(a)).abs() / 2 + (_stickH * math.sin(a)).abs() / 2;
      final halfH =
          (_stickW * math.sin(a)).abs() / 2 + (_stickH * math.cos(a)).abs() / 2;
      final maxX = _stage.width / 2 - halfW;
      final maxY = _stage.height / 2 - halfH;
      final cx = _slotX(i) + _pos[i].dx;
      final cy = _pos[i].dy;
      if (maxX > 0 && cx.abs() > maxX) {
        _pos[i] = Offset(cx.sign * maxX - _slotX(i), _pos[i].dy);
        hit = math.max(hit, _vel[i].dx.abs());
        _vel[i] = Offset(-_vel[i].dx * .55, _vel[i].dy * .9);
        _spin[i] += (_random.nextDouble() - .5) * 2;
      }
      if (maxY > 0 && cy.abs() > maxY) {
        _pos[i] = Offset(_pos[i].dx, cy.sign * maxY);
        hit = math.max(hit, _vel[i].dy.abs());
        _vel[i] = Offset(_vel[i].dx * .9, -_vel[i].dy * .55);
        _spin[i] += (_random.nextDouble() - .5) * 2;
      }
      if (_pos[i].distance > .5 ||
          _vel[i].distance > 2 ||
          _angle[i].abs() > .005 ||
          _spin[i].abs() > .02) {
        moving = true;
      }
    }
    // 윷끼리 부딪히면 옆으로 밀어내고 속도를 나눠 가집니다.
    for (var i = 0; i < 4; i++) {
      for (var j = i + 1; j < 4; j++) {
        final dx = (_slotX(j) + _pos[j].dx) - (_slotX(i) + _pos[i].dx);
        final dy = _pos[j].dy - _pos[i].dy;
        final overlap = _stickW * 1.05 - dx.abs();
        if (overlap <= 0 || dy.abs() >= _stickH * .75) continue;
        final sign = dx >= 0 ? 1.0 : -1.0;
        _pos[i] -= Offset(sign * overlap / 2, 0);
        _pos[j] += Offset(sign * overlap / 2, 0);
        final relative = _vel[j].dx - _vel[i].dx;
        if (relative * sign < 0) {
          final impulse = -relative * .4;
          _vel[i] -= Offset(impulse, 0);
          _vel[j] += Offset(impulse, 0);
          hit = math.max(hit, relative.abs());
        }
      }
    }
    // 벽에 세게 부딪힐 때마다 짧게 '딱' 진동합니다.
    if (hit > 260) {
      final now = DateTime.now();
      if (now.difference(_lastWallHaptic) > const Duration(milliseconds: 70)) {
        _lastWallHaptic = now;
        HapticFeedback.lightImpact();
      }
    }
    _frame.value++;
    if (!moving && !loose) {
      for (var i = 0; i < 4; i++) {
        _pos[i] = Offset.zero;
        _vel[i] = Offset.zero;
        _angle[i] = 0;
        _spin[i] = 0;
      }
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    _motionSub?.cancel();
    _ticker.dispose();
    _frame.dispose();
    _wobble.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final edition = game.edition;
    final pooled = game.pool.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TurnBand(
          game: game,
          team: widget.me?.team,
          title: pooled
              ? yutText('한 번 더 던져요!', 'Throw again!', '再掷一次！', '再擲一次！')
              : yutText('내 차례예요', 'Your turn', '轮到你了', '輪到你了'),
          subtitle: widget.throwing
              ? yutText(
                  '태블릿에서 결과를 확인해요',
                  'Watch the tablet for the result',
                  '请在平板上查看结果',
                  '請在平板上查看結果',
                )
              : widget.shaking
              ? yutText(
                  '좋아요! 계속 흔들어 주세요',
                  'Keep shaking!',
                  '很好！继续摇动',
                  '很好！繼續搖動',
                )
              : yutText(
                  '휴대폰을 흔들면 태블릿으로 윷이 던져져요',
                  'Shake to throw the sticks onto the tablet',
                  '摇动手机，柶会掷到平板上',
                  '搖動手機，柶會擲到平板上',
                ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              final width = math.min(
                64.0,
                (box.maxHeight - 40) / YutStick.aspect,
              );
              _stickW = width;
              _stage = Size(box.maxWidth, box.maxHeight);
              return TweenAnimationBuilder<double>(
                tween: Tween(end: widget.throwing ? 1 : 0),
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeInOutCubic,
                builder: (context, launch, _) => AnimatedBuilder(
                  animation: Listenable.merge([_wobble, _frame]),
                  builder: (context, _) => Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      Opacity(
                        opacity: launch,
                        child: Transform.translate(
                          offset: Offset(0, -4 * _wobble.value),
                          child: Icon(
                            Icons.tablet_mac_rounded,
                            size: 64,
                            color: edition ? YutColors.lilac : YutColors.blue,
                          ),
                        ),
                      ),
                      for (var i = 0; i < 4; i++)
                        Opacity(
                          opacity: 1 - launch,
                          child: Transform.translate(
                            offset:
                                Offset(_slotX(i), 0) +
                                _pos[i] +
                                Offset(
                                  (i - 1.5) * 18 * launch,
                                  -launch * box.maxHeight * .6,
                                ),
                            child: Transform.rotate(
                              angle:
                                  _restAngle(i) +
                                  _angle[i] +
                                  (i.isEven ? 1 : -1) * launch * .7,
                              child: YutStick(
                                front: i.isEven,
                                width: width,
                                edition: edition,
                                characterId: widget.me?.characterId,
                                marked: i == 1,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (!widget.motionAvailable)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              yutText(
                '흔들기 감지를 쓸 수 없어 버튼으로 던져 주세요',
                'Shake detection is unavailable. Use the button.',
                '无法检测摇动，请使用按钮',
                '無法偵測搖動，請使用按鈕',
              ),
              textAlign: TextAlign.center,
              style: YutFonts.text(12, color: YutColors.vermilion),
            ),
          ),
        _LabeledButton(
          label: widget.throwing
              ? yutText('태블릿에 던지는 중…', 'Throwing…', '正在投掷…', '正在投擲…')
              : yutText('버튼으로 던지기', 'Throw', '按钮投掷', '按鈕投擲'),
          edition: edition,
          done: widget.throwing,
          busy: widget.busy,
          onPressed: widget.onThrow,
        ),
      ],
    );
  }
}

class _LabeledButton extends StatelessWidget {
  const _LabeledButton({
    required this.label,
    required this.edition,
    required this.done,
    required this.busy,
    required this.onPressed,
  });
  final String label;
  final bool edition;
  final bool done;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final fg = done
        ? (edition ? YutColors.haze : YutColors.muted)
        : (edition ? YutColors.night : Colors.white);
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: done || busy ? null : onPressed,
        child: Container(
          height: 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: done
                ? (edition ? YutColors.nightRaised : const Color(0xFFE6E1D6))
                : (edition ? null : YutColors.blue),
            gradient: !done && edition ? YutColors.holoGradient : null,
            borderRadius: BorderRadius.circular(12),
            boxShadow: done
                ? null
                : [
                    BoxShadow(
                      color: edition ? Colors.black : YutColors.blueDeep,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Text(label, style: YutFonts.title(23, color: fg)),
        ),
      ),
    );
  }
}

/// 다른 사람이 던지거나 태블릿에서 말을 옮기는 동안의 화면입니다.
class _WaitStage extends StatefulWidget {
  const _WaitStage({required this.game, required this.meUid});
  final YutGameView game;
  final String meUid;

  @override
  State<_WaitStage> createState() => _WaitStageState();
}

class _WaitStageState extends State<_WaitStage>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final edition = game.edition;
    final me = game.player(widget.meUid);
    final turn = game.player(game.turnUid);
    final List<YutPlayerView> actors;
    final YutTeam? team;
    final String title;
    final String caption;
    String? footer;
    if (game.strategy) {
      team = game.turnTeam;
      actors = team == null ? const [] : game.teamPlayers(team);
      final mine = me?.team == team;
      title = mine
          ? yutText(
              '우리 ${YutCopy.teamName(team)}이 말 옮기는 중',
              'Our team is moving',
              '我们队正在移动',
              '我們隊正在移動',
            )
          : yutText(
              '${YutCopy.teamName(team)}이 말 옮기는 중',
              '${YutCopy.teamName(team)} is moving',
              '${YutCopy.teamName(team)}正在移动',
              '${YutCopy.teamName(team)}正在移動',
            );
      caption = mine
          ? yutText(
              '태블릿에서 말을 꾹 눌러 끌어 놓아 주세요',
              'Move a piece on the tablet',
              '请在平板上移动棋子',
              '請在平板上移動棋子',
            )
          : yutText(
              '태블릿에서 말을 옮기고 있어요',
              'Moving pieces on the tablet',
              '正在平板上移动棋子',
              '正在平板上移動棋子',
            );
      if (!mine && me?.team != null) {
        footer = yutText(
          '다음은 우리 ${YutCopy.teamName(me?.team)} 차례예요',
          'Our ${YutCopy.teamName(me?.team)} is next',
          '下一回合是我们${YutCopy.teamName(me?.team)}',
          '下一回合是我們${YutCopy.teamName(me?.team)}',
        );
      }
    } else {
      team = turn?.team;
      actors = turn == null ? const [] : [turn];
      final mine = game.turnUid == widget.meUid;
      final name = turn?.nickname ?? '';
      if (game.moving) {
        title = mine
            ? yutText('태블릿에서 말을 옮겨요', 'Move on the tablet', '在平板上移动', '在平板上移動')
            : yutText(
                '$name 님이 말 옮기는 중',
                '$name is moving',
                '$name正在移动',
                '$name正在移動',
              );
        caption = mine
            ? yutText(
                '태블릿에서 말을 꾹 눌러 끌어 놓아 주세요',
                'Press and drag a piece on the tablet',
                '请在平板上长按并拖动棋子',
                '請在平板上長按並拖動棋子',
              )
            : yutText(
                '태블릿에서 말을 옮기고 있어요',
                'Moving pieces on the tablet',
                '正在平板上移动棋子',
                '正在平板上移動棋子',
              );
      } else {
        title = yutText(
          '$name 님이 윷 던지는 중',
          '$name is throwing',
          '$name正在掷柶',
          '$name正在擲柶',
        );
        caption = yutText('잠시만 기다려 주세요', 'Please wait', '请稍候', '請稍候');
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TurnBand(
          game: game,
          team: team,
          title: title,
          subtitle: yutText(
            '잠시만 기다려 주세요',
            'Please wait a moment',
            '请稍候',
            '請稍候',
          ),
          showTimer: false,
        ),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < actors.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: _PulseFace(
                        player: actors[i],
                        pulse: _pulse,
                        delay: i * .5,
                        edition: edition,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) => Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < 3; i++)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              (edition
                                      ? const Color(0xFFA9E8F0)
                                      : YutColors.vermilion)
                                  .withValues(
                                    alpha:
                                        .3 +
                                        .7 *
                                            (math.sin(
                                                      (_pulse.value - i * .15) *
                                                          math.pi *
                                                          2,
                                                    ) *
                                                    .5 +
                                                .5),
                                  ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                caption,
                textAlign: TextAlign.center,
                style: YutFonts.title(
                  20,
                  color: edition ? YutColors.moon : YutColors.ink,
                ),
              ),
              if (game.pool.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final chip in game.pool)
                      YutChipButton(
                        result: chip.result,
                        team: team,
                        edition: edition,
                        scale: .85,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (footer != null)
          Container(
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: edition ? YutColors.nightRaised : const Color(0xFFE6E1D6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: edition ? YutColors.nightEdge : const Color(0xFF9DB0D6),
                width: 2,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: edition ? YutColors.lilac : YutColors.blue,
                ),
                const SizedBox(width: 8),
                Text(
                  footer,
                  style: YutFonts.title(
                    19,
                    color: edition ? YutColors.lilac : YutColors.blue,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PulseFace extends StatelessWidget {
  const _PulseFace({
    required this.player,
    required this.pulse,
    required this.delay,
    required this.edition,
  });
  final YutPlayerView player;
  final Animation<double> pulse;
  final double delay;
  final bool edition;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox.square(
        dimension: 140,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: pulse,
              builder: (context, _) {
                final t = (pulse.value + delay) % 1;
                return Container(
                  width: 112 + 28 * t,
                  height: 112 + 28 * t,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (edition ? YutColors.lilac : const Color(0xFFE9D6B0))
                        .withValues(alpha: (1 - t) * .7),
                  ),
                );
              },
            ),
            Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: edition ? YutColors.lilac : YutColors.edge,
                  width: 4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: edition ? Colors.black : YutColors.edgeShadow,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipOval(
                child: MosiFace(characterId: player.characterId, size: 104),
              ),
            ),
            Positioned(
              right: 10,
              bottom: 12,
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFFFDF7),
                  border: Border.all(
                    color: edition ? YutColors.lilac : YutColors.inkSoft,
                    width: 2.5,
                  ),
                ),
                child: Text(
                  YutCopy.teamMark(player.team),
                  style: YutFonts.stamp(18, color: const Color(0xFF2A2622)),
                ),
              ),
            ),
          ],
        ),
      ),
      Text(
        player.nickname,
        style: YutFonts.title(
          20,
          color: edition ? YutColors.moon : YutColors.ink,
        ),
      ),
    ],
  );
}

/// 승리·패배 화면입니다.
class _PhoneResult extends StatefulWidget {
  const _PhoneResult({required this.game, required this.meUid});
  final YutGameView game;
  final String meUid;

  @override
  State<_PhoneResult> createState() => _PhoneResultState();
}

class _PhoneResultState extends State<_PhoneResult>
    with SingleTickerProviderStateMixin {
  late final _hop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _hop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final edition = game.edition;
    final me = game.player(widget.meUid);
    final natural = game.finishReason == 'winner';
    final won =
        natural &&
        (game.strategy
            ? me?.team != null && me?.team == game.winningTeam
            : game.winnerUid == widget.meUid);
    final mates = game.strategy && me?.team != null
        ? game.teamPlayers(me!.team!)
        : [?me];
    final myOwner = me == null ? null : game.ownerKeyOf(me.uid);
    final mine = myOwner == null ? 0 : game.finishedCount(myOwner);
    final winnerName = game.strategy
        ? YutCopy.teamName(game.winningTeam)
        : game.player(game.winnerUid)?.nickname ?? '';
    final title = !natural
        ? yutText('경기가 끝났어요', 'Game over', '游戏结束', '遊戲結束')
        : won
        ? (game.strategy
              ? yutText('우리 팀 승리!', 'We win!', '我们赢了！', '我們贏了！')
              : yutText('내가 이겼어요!', 'You win!', '你赢了！', '你贏了！'))
        : yutText('아쉽게 졌어요', 'So close!', '可惜输了', '可惜輸了');
    final subtitle = !natural
        ? yutText(
            '태블릿에서 다음 진행을 기다려 주세요',
            'Wait for the tablet',
            '请等待平板操作',
            '請等待平板操作',
          )
        : won
        ? yutText(
            '말 2개가 났어요',
            'Two pieces are home',
            '2枚棋子已到家',
            '2枚棋子已到家',
          )
        : yutText(
            '$winnerName이 먼저 말 2개를 냈어요 · 우리는 $mine개',
            '$winnerName got two home first · we had $mine',
            '$winnerName先完成 · 我们$mine枚',
            '$winnerName先完成 · 我們$mine枚',
          );
    final accent = won && me?.team != YutTeam.white
        ? YutTeamStyle.of(me?.team).fill
        : YutColors.ink;
    return Stack(
      children: [
        if (won)
          Positioned.fill(
            child: YutConfetti(
              colors: edition
                  ? YutColors.holo
                  : const [
                      YutColors.vermilion,
                      YutColors.blue,
                      YutColors.gold,
                      Color(0xFF7DB59A),
                      Color(0xFFE8A3AE),
                    ],
            ),
          ),
        Column(
          children: [
            const SizedBox(height: 8),
            edition
                ? YutHoloText(title, style: YutFonts.title(won ? 54 : 46))
                : Text(
                    title,
                    style: YutFonts.title(
                      won ? 54 : 46,
                      color: won ? accent : const Color(0xFF5A564F),
                    ),
                  ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: YutFonts.text(
                15,
                color: edition ? YutColors.haze : YutColors.muted,
              ),
            ),
            Expanded(
              child: AnimatedBuilder(
                animation: _hop,
                builder: (context, _) => LayoutBuilder(
                  builder: (context, box) {
                    final width = math.min(
                      96.0,
                      (box.maxHeight - 60) / YutStick.aspect,
                    );
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: math.min(box.maxWidth, 300),
                          height: math.min(box.maxWidth, 300),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                (won
                                        ? (edition
                                              ? YutColors.lilac
                                              : YutColors.blue)
                                        : const Color(0xFF8C93A3))
                                    .withValues(alpha: .14),
                          ),
                        ),
                        if (!won && natural)
                          Positioned(
                            top: 10,
                            child: Icon(
                              Icons.cloud_rounded,
                              size: 110,
                              color: edition
                                  ? YutColors.nightEdge
                                  : const Color(0xFFC9CFD9),
                            ),
                          ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 0; i < mates.length; i++)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _resultStick(mates[i], i, width, won),
                                    const SizedBox(height: 8),
                                    Text(
                                      mates[i].nickname,
                                      style: YutFonts.text(
                                        15,
                                        weight: FontWeight.w800,
                                        color: edition
                                            ? YutColors.moon
                                            : YutColors.ink,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _resultStick(YutPlayerView player, int index, double width, bool won) {
    final t = (_hop.value + index * .32) % 1;
    final edition = widget.game.edition;
    final stick = YutStick(
      front: true,
      width: width,
      edition: edition,
      characterId: player.characterId,
      dim: !won && widget.game.finishReason == 'winner',
    );
    if (won) {
      final lift = math.sin(math.min(t / .4, 1) * math.pi) * 26;
      return Transform.translate(
        offset: Offset(0, -lift),
        child: Transform.rotate(
          angle: (index.isEven ? -1 : 1) * (.21 - lift / 26 * .1),
          child: stick,
        ),
      );
    }
    return Transform.rotate(
      angle: index.isEven ? -1.36 : -.38 + math.sin(t * math.pi * 2) * .035,
      child: stick,
    );
  }
}

class _PhoneNotice extends StatelessWidget {
  const _PhoneNotice({required this.edition});
  final bool edition;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFF8A5C21),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      yutText(
        '참가자 기기 연결을 확인하고 있어요. 잠시 기다려 주세요.',
        'Waiting for player devices to reconnect.',
        '正在确认玩家设备连接，请稍候。',
        '正在確認玩家裝置連線，請稍候。',
      ),
      textAlign: TextAlign.center,
      style: YutFonts.text(14, color: Colors.white, weight: FontWeight.w700),
    ),
  );
}
