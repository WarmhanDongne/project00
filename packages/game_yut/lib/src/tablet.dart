import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_kit/models/game_room_context.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:game_kit/sound/game_background_music.dart';
import 'package:game_kit/sound/sound_effects.dart';
import 'package:game_kit/tablet/widgets/game_menu_overlay.dart';
import 'package:game_kit/tablet/widgets/game_rulebook_dialog.dart';
import 'package:game_kit/tablet/widgets/game_settings_dialog.dart';
import 'package:game_yut/src/board.dart';
import 'package:game_yut/src/service.dart';
import 'package:game_yut/src/session.dart';
import 'package:game_yut/src/theme.dart';
import 'package:game_yut/src/view.dart';
import 'package:game_yut/src/widgets.dart';
import 'package:game_yut/game_sounds.dart';

/// 공개 연출을 보여 주는 시간입니다. 이보다 오래된 결과는 다시 보여 주지 않습니다.
const _revealDuration = Duration(milliseconds: 2200);
const _ribbonDuration = Duration(milliseconds: 2800);

class YutTabletScreen extends ConsumerStatefulWidget {
  const YutTabletScreen({
    super.key,
    required this.roomCode,
    required this.provider,
    required this.gameId,
  });
  final String roomCode;
  final GameRoomContext provider;
  final String gameId;

  @override
  ConsumerState<YutTabletScreen> createState() => _YutTabletScreenState();
}

class _YutTabletScreenState extends ConsumerState<YutTabletScreen> {
  late final _service = YutService();
  final _backgroundMusic = GameBackgroundMusic();
  Timer? _timeoutTimer;
  String? _timeoutKey;
  bool _reportedReady = false;
  bool _soundPrepared = false;
  bool _hasObservedRollState = false;
  bool _busy = false;
  int _revealedAt = 0;
  int _captureAt = 0;
  int _revealEndsAt = 0;
  Timer? _revealTimer;
  Timer? _captureTimer;

  String get _uid => ref.read(yutUidProvider);
  YutSessionArgs get _args =>
      YutSessionArgs(roomCode: widget.roomCode, uid: _uid, watchPrivate: false);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _backgroundMusic.attach(context);
    if (!_soundPrepared) {
      _soundPrepared = true;
      final sound = SoundEffects.of(context);
      if (sound != null) {
        unawaited(
          sound.preloadEffects(
            YutSounds.preloadTargets,
            solo: true,
            scope: 'yut',
          ),
        );
      }
    }
    unawaited(
      YutImages.precache(
        context,
        edition: widget.gameId == 'strategy_yut_edition',
      ),
    );
  }

  @override
  void dispose() {
    _backgroundMusic.stop();
    _timeoutTimer?.cancel();
    _revealTimer?.cancel();
    _captureTimer?.cancel();
    super.dispose();
  }

  /// 마감 시각에 맞춰 한 번만 시간 초과 명령을 보냅니다(진행용 태블릿 전용).
  void _scheduleTimeout(YutGameView game) {
    final key = '${game.phase}:${game.round}:${game.deadlineAt}';
    if (game.finished || game.paused || game.deadlineAt <= 0) {
      _timeoutTimer?.cancel();
      _timeoutKey = null;
      return;
    }
    if (_timeoutKey == key) return;
    _timeoutKey = key;
    _timeoutTimer?.cancel();
    final wait = game.deadlineAt - DateTime.now().millisecondsSinceEpoch + 400;
    _timeoutTimer = Timer(Duration(milliseconds: math.max(0, wait)), () {
      if (!mounted) return;
      unawaited(
        ref
            .read(yutSessionProvider(_args).notifier)
            .execute(() => _service.command.timeout(widget.roomCode)),
      );
    });
  }

  /// 새 윷 결과·잡기를 받으면 잠시 연출을 띄웁니다.
  void _trackOverlays(YutGameView game) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final roll = game.lastRoll;
    if (roll != null && roll.createdAt > _revealedAt) {
      _revealedAt = roll.createdAt;
      // 실시간 결과는 수신 즉시 재생합니다. 첫 연결의 오래된 결과는
      // 재생하지 않으며, 애니메이션과 입력 잠금은 같은 종료 시각을 씁니다.
      final remaining = _hasObservedRollState
          ? _revealDuration.inMilliseconds
          : (_revealDuration.inMilliseconds - (now - roll.createdAt)).clamp(
              0,
              _revealDuration.inMilliseconds,
            );
      _revealEndsAt = now + remaining;
      _revealTimer?.cancel();
      if (remaining > 0) {
        if (_hasObservedRollState) {
          SoundEffects.play(context, YutSounds.throwSticks);
        }
        _revealTimer = Timer(Duration(milliseconds: remaining), () {
          if (mounted) setState(() {});
        });
      }
    }
    if (game.loaded) _hasObservedRollState = true;
    final move = game.lastMove;
    if (move != null &&
        move.extraThrow &&
        move.createdAt > _captureAt &&
        now - move.createdAt < _ribbonDuration.inMilliseconds + 1500) {
      _captureAt = move.createdAt;
      _captureTimer?.cancel();
      _captureTimer = Timer(
        Duration(
          milliseconds:
              move.createdAt + _ribbonDuration.inMilliseconds + 1500 - now,
        ),
        () {
          if (mounted) setState(() {});
        },
      );
    }
  }

  bool _showingReveal(YutGameView game) {
    final roll = game.lastRoll;
    return roll != null &&
        roll.createdAt == _revealedAt &&
        DateTime.now().millisecondsSinceEpoch < _revealEndsAt;
  }

  bool _showingCapture(YutGameView game) {
    final move = game.lastMove;
    return move != null &&
        move.extraThrow &&
        move.createdAt == _captureAt &&
        DateTime.now().millisecondsSinceEpoch - move.createdAt <
            _ribbonDuration.inMilliseconds + 1500;
  }

  /// 판에 놓은 말에 나온 윷을 차례대로 씁니다. 두 개를 합친 칸이면 두 번 보냅니다.
  Future<void> _move(int pieceId, List<int> chips) async {
    if (_busy || chips.isEmpty) return;
    setState(() => _busy = true);
    final notifier = ref.read(yutSessionProvider(_args).notifier);
    final used = <int>[];
    for (final chip in chips) {
      // 앞에서 쓴 윷이 빠지면 뒤 번호가 하나씩 당겨집니다.
      final index = chip - used.where((value) => value < chip).length;
      final ok = await notifier.execute(
        () => _service.command.move(widget.roomCode, pieceId, index),
      );
      if (!ok) break;
      used.add(chip);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _restart() async {
    await ref
        .read(yutSessionProvider(_args).notifier)
        .execute(
          () => _service.command.startGame(
            widget.roomCode,
            widget.gameId,
            restart: true,
          ),
        );
  }

  Future<void> _endAndExit(YutGameView game) async {
    if (!game.finished) {
      final ended = await ref
          .read(yutSessionProvider(_args).notifier)
          .execute(() => _service.command.endGame(widget.roomCode));
      if (!ended) return;
    }
    if (mounted) await Navigator.of(context).maybePop();
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
    if (game.loaded && !game.finished && !game.paused) {
      _backgroundMusic.start(YutSounds.background);
    } else {
      _backgroundMusic.stop();
    }
    _scheduleTimeout(game);
    _trackOverlays(game);
    final edition = game.edition;
    final reveal = _showingReveal(game);
    final capture = _showingCapture(game);
    return Scaffold(
      backgroundColor: edition ? YutColors.night : YutColors.paper,
      body: YutBackground(
        edition: edition,
        tablet: true,
        child: LayoutBuilder(
          builder: (context, box) {
            final unit = box.maxHeight / 1024;
            final boardSide = math.min(940 * unit, box.maxWidth - 340 * unit);
            final columnWidth = (box.maxWidth - boardSide) / 2;
            return Stack(
              children: [
                if (!game.loaded)
                  Center(
                    child: CircularProgressIndicator(
                      color: edition ? YutColors.lilac : YutColors.blue,
                    ),
                  ),
                if (game.loaded && !game.strategy)
                  Positioned.fill(
                    child: _ClassicTable(
                      game: game,
                      unit: unit,
                      reveal: reveal,
                      busy: _busy,
                      onMove: game.moving && !reveal ? _move : null,
                    ),
                  ),
                if (game.loaded && game.strategy) ...[
                  Positioned(
                    left: columnWidth,
                    top: (box.maxHeight - boardSide) / 2 + 8 * unit,
                    width: boardSide,
                    height: boardSide,
                    child: YutBoardView(
                      game: game,
                      busy: _busy,
                      onMove: game.moving && !reveal ? _move : null,
                      // 잡힌 말은 팀 쪽 띠(청군 왼쪽, 백군 오른쪽)로 날아갑니다.
                      stackOffset: (owner) => Offset(
                        owner == 'blue'
                            ? -columnWidth / 2
                            : boardSide + columnWidth / 2,
                        boardSide / 2,
                      ),
                    ),
                  ),
                  for (final left in [true, false])
                    Positioned(
                      left: left ? 0 : box.maxWidth - columnWidth,
                      top: 0,
                      bottom: 0,
                      width: columnWidth,
                      child: RotatedBox(
                        quarterTurns: left ? 1 : 3,
                        child: _SideStrip(
                          game: game,
                          left: left,
                          unit: unit,
                          reveal: reveal,
                          capture: capture,
                          busy: _busy,
                          pieceSize: boardSide * (edition ? .091 : .0968),
                          canDrag: game.moving && !reveal,
                        ),
                      ),
                    ),
                ],
                if (game.loaded) ...[
                  if (reveal && game.lastRoll != null)
                    Positioned.fill(
                      child: _RevealOverlay(
                        key: ValueKey(game.lastRoll!.createdAt),
                        game: game,
                        roll: game.lastRoll!,
                        endsAt: _revealEndsAt,
                        unit: unit,
                      ),
                    ),
                  if (game.paused) const _PauseBanner(),
                  if (game.finished)
                    Positioned.fill(
                      child: _TabletResult(
                        game: game,
                        onRestart: _restart,
                        onHome: () => _endAndExit(game),
                      ),
                    ),
                ],
                if (!game.strategy && game.seated.length >= 4)
                  _CornerMenu(
                    visible: game.loaded && !game.finished,
                    roleDialogBuilder: (_) => TabletGameRulebookDialog(
                      title: YutCopy.gameTitle(widget.gameId),
                      markdown: YutCopy.rulesMarkdown(widget.gameId),
                    ),
                    settingDialogBuilder: (_) => TabletGameSettingsDialog(
                      provider: widget.provider,
                      onRestartGame: () => unawaited(_restart()),
                      onEndGame: () => unawaited(_endAndExit(game)),
                    ),
                  )
                else
                  TabletGameMenuOverlay(
                    visible: game.loaded && !game.finished,
                    roleIcon: Image(image: YutImages.book),
                    settingIcon: Image(image: YutImages.coin),
                    roleDialogBuilder: (_) => TabletGameRulebookDialog(
                      title: YutCopy.gameTitle(widget.gameId),
                      markdown: YutCopy.rulesMarkdown(widget.gameId),
                    ),
                    settingDialogBuilder: (_) => TabletGameSettingsDialog(
                      provider: widget.provider,
                      onRestartGame: () => unawaited(_restart()),
                      onEndGame: () => unawaited(_endAndExit(game)),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 일반 윷놀이 판(시안 `보통 윷놀이 · 태블릿 2~4인`)입니다. 가운데 700px
/// 나무판을 두고, 모시겜 자리 배치대로 각 플레이어 쪽에 남은 말 더미·이름·
/// 마지막 결과를 그 사람을 향하게 돌려 놓습니다.
class _ClassicTable extends StatelessWidget {
  const _ClassicTable({
    required this.game,
    required this.unit,
    required this.reveal,
    required this.busy,
    required this.onMove,
  });
  final YutGameView game;
  final double unit;
  final bool reveal;
  final bool busy;
  final void Function(int pieceId, List<int> chips)? onMove;

  /// 시안(1366×1024)의 자리 중심(판 중심 기준)과 회전 각도입니다.
  static List<(Offset, double)> seatAnchors(int count) => switch (count) {
    2 => const [(Offset(-533, 0), 90), (Offset(533, 0), -90)],
    3 => const [
      (Offset(0, -420), 180),
      (Offset(467, 288), -60),
      (Offset(-467, 288), 60),
    ],
    _ => const [
      (Offset(-503, -342), 135),
      (Offset(503, -342), -135),
      (Offset(503, 342), -45),
      (Offset(-503, 342), 45),
    ],
  };

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final center = box.biggest.center(Offset.zero);
      final side = 700 * unit;
      final seats = game.seated;
      final anchors = seatAnchors(seats.length.clamp(2, 4));
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: center.dx - side / 2,
            top: center.dy - side / 2,
            width: side,
            height: side,
            child: YutBoardView(
              game: game,
              busy: busy,
              onMove: onMove,
              // 잡힌 말은 주인 자리의 남은 말 더미로 날아갑니다.
              stackOffset: (owner) {
                final index = seats.indexWhere((seat) => seat.uid == owner);
                if (index < 0 || index >= anchors.length) return null;
                final at = _seatPoint(center, box.biggest, anchors[index].$1);
                return at - Offset(center.dx - side / 2, center.dy - side / 2);
              },
            ),
          ),
          for (var i = 0; i < seats.length && i < anchors.length; i++)
            _place(
              center,
              box.biggest,
              anchors[i].$1,
              anchors[i].$2,
              _ClassicSeat(
                game: game,
                player: seats[i],
                unit: unit,
                reveal: reveal,
                pieceSize: side * .0968,
                canDrag:
                    game.turnUid == seats[i].uid && !busy && onMove != null,
              ),
            ),
        ],
      );
    },
  );

  Offset _seatPoint(Offset center, Size screen, Offset design) {
    final margin = 90 * unit;
    return Offset(
      (center.dx + design.dx * unit).clamp(margin, screen.width - margin),
      (center.dy + design.dy * unit).clamp(margin, screen.height - margin),
    );
  }

  Widget _place(
    Offset center,
    Size screen,
    Offset design,
    double degrees,
    Widget child,
  ) {
    final at = _seatPoint(center, screen, design);
    return Positioned(
      left: at.dx,
      top: at.dy,
      child: FractionalTranslation(
        translation: const Offset(-.5, -.5),
        child: Transform.rotate(angle: degrees * math.pi / 180, child: child),
      ),
    );
  }
}

/// 한 사람의 자리: 남은 말 더미(숫자), 이름, 방금 던진 결과.
class _ClassicSeat extends StatelessWidget {
  const _ClassicSeat({
    required this.game,
    required this.player,
    required this.unit,
    required this.reveal,
    required this.pieceSize,
    required this.canDrag,
  });
  final YutGameView game;
  final YutPlayerView player;
  final double unit;
  final bool reveal;
  final double pieceSize;
  final bool canDrag;

  @override
  Widget build(BuildContext context) {
    final s = unit.clamp(.7, 1.3);
    final style = YutTeamStyle.of(player.team);
    final pieces = game.piecesOf(player.uid);
    final ready = pieces.where((piece) => piece.ready).toList();
    final active = game.turnUid == player.uid && !game.finished;
    final disc = 74.0 * s;
    final canEnter =
        canDrag &&
        game.moving &&
        !reveal &&
        ready.isNotEmpty &&
        game.pool.any((chip) => chip.result.steps > 0);
    final roll = game.lastRoll;
    final showResult =
        roll != null &&
        roll.actorUid == player.uid &&
        (game.moving || game.rolling) &&
        game.turnUid == player.uid &&
        !reveal;
    final stack = SizedBox(
      width: disc + 12 * s,
      height:
          disc + 16 * s + math.max(0, math.min(ready.length, 4) - 1) * 12 * s,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (ready.isEmpty)
            Positioned(
              left: 0,
              bottom: 0,
              child: Opacity(
                opacity: .25,
                child: YutPieceToken(
                  team: player.team,
                  label: '',
                  size: disc,
                  edition: false,
                  characterId: player.characterId,
                ),
              ),
            ),
          for (var k = 0; k < ready.length && k < 4; k++)
            Positioned(
              left: 0,
              bottom: k * 12 * s,
              child: YutPieceToken(
                team: player.team,
                label: '',
                size: disc,
                edition: false,
                characterId: player.characterId,
                glow: active && k == math.min(ready.length, 4) - 1,
              ),
            ),
          Positioned(
            right: -10 * s,
            top: -6 * s,
            child: Container(
              constraints: BoxConstraints(minWidth: 28 * s),
              height: 28 * s,
              padding: EdgeInsets.symmetric(horizontal: 6 * s),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: YutColors.ink,
                borderRadius: BorderRadius.circular(14 * s),
                border: Border.all(color: YutColors.paper, width: 2),
              ),
              child: Text(
                '${ready.length}',
                style: YutFonts.text(
                  15 * s,
                  color: Colors.white,
                  weight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              button: canEnter,
              label: yutText(
                '${player.nickname} 남은 말 ${ready.length}개',
                '${player.nickname}: ${ready.length} waiting',
                '${player.nickname} 待出 ${ready.length}',
                '${player.nickname} 待出 ${ready.length}',
              ),
              // 더미에서 바로 끌어 판에 놓으면 출발부터 한 칸씩 갑니다.
              child: YutStackDraggable(
                game: game,
                owner: player.uid,
                pieceId: ready.isEmpty ? -1 : ready.last.id,
                pieceSize: pieceSize,
                enabled: canEnter,
                child: stack,
              ),
            ),
            SizedBox(height: 6 * s),
            Text(
              player.nickname,
              style: YutFonts.title(24 * s, color: YutColors.ink, height: 1),
            ),
          ],
        ),
        if (showResult) ...[
          SizedBox(width: 24 * s),
          Padding(
            padding: EdgeInsets.only(bottom: 28 * s),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${YutCopy.result(roll.result)}!',
                  style: YutFonts.title(
                    56 * s,
                    color: style.fill,
                    height: 1,
                    shadows: const [
                      Shadow(color: Color(0xCCFFFFFF), offset: Offset(0, 3)),
                    ],
                  ),
                ),
                SizedBox(height: 2 * s),
                Text(
                  YutCopy.steps(roll.result),
                  style: YutFonts.text(
                    16 * s,
                    color: style.fill,
                    weight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                if (game.pool.length > 1) ...[
                  SizedBox(height: 8 * s),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final chip in game.pool)
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 2 * s),
                          child: YutChipButton(
                            result: chip.result,
                            team: player.team,
                            edition: false,
                            scale: .62 * s,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// 네 모서리가 모두 자리인 4인 판에서는 규칙·설정 버튼을 오른쪽 가운데에 세로로 둡니다.
class _CornerMenu extends StatelessWidget {
  const _CornerMenu({
    required this.visible,
    required this.roleDialogBuilder,
    required this.settingDialogBuilder,
  });
  final bool visible;
  final WidgetBuilder roleDialogBuilder;
  final WidgetBuilder settingDialogBuilder;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    Widget button(ImageProvider image, String label, WidgetBuilder builder) =>
        Semantics(
          button: true,
          label: label,
          child: GestureDetector(
            onTapUp: (details) => showMosiDialog<void>(
              context: context,
              origin: Rect.fromCenter(
                center: details.globalPosition,
                width: 1,
                height: 1,
              ),
              builder: builder,
            ),
            child: SizedBox(width: 62, height: 84, child: Image(image: image)),
          ),
        );
    return Positioned(
      right: 18,
      top: 0,
      bottom: 0,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            button(YutImages.book, YutCopy.rules, roleDialogBuilder),
            const SizedBox(height: 18),
            button(YutImages.coin, YutCopy.settings, settingDialogBuilder),
          ],
        ),
      ),
    );
  }
}

/// 태블릿 한쪽(옆에 앉은 팀) 띠입니다. 남은 말, 상태 리본, 나온 윷이 있습니다.
class _SideStrip extends StatelessWidget {
  const _SideStrip({
    required this.game,
    required this.left,
    required this.unit,
    required this.reveal,
    required this.capture,
    required this.busy,
    required this.pieceSize,
    required this.canDrag,
  });
  final YutGameView game;
  final bool left;
  final double unit;
  final bool reveal;
  final bool capture;
  final bool busy;
  final double pieceSize;
  final bool canDrag;

  @override
  Widget build(BuildContext context) {
    final owners = _owners();
    final turnOwner = game.turnOwner;
    final active = owners.contains(turnOwner);
    final team = game.strategy
        ? (left ? YutTeam.blue : YutTeam.white)
        : game.player(turnOwner)?.team;
    final ribbon = _ribbonText(active);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 40 * unit),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 16 * unit,
                runSpacing: 8 * unit,
                children: [
                  for (final owner in owners)
                    _ReadyStack(
                      game: game,
                      owner: owner,
                      unit: unit,
                      canDrag: owner == turnOwner && canDrag,
                      pieceSize: pieceSize,
                      busy: busy,
                    ),
                ],
              ),
            ),
          ),
          if (ribbon != null)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: YutRibbon(
                key: ValueKey('$ribbon$capture'),
                text: ribbon,
                team: team,
                edition: game.edition,
                alert: capture && game.lastMove?.owner != null,
                fontSize: 25 * unit.clamp(.7, 1.2),
              ),
            ),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: active && game.pool.isNotEmpty && !reveal
                  ? _PoolRow(game: game, team: team, unit: unit)
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  /// 이 띠가 보여 줄 말 묶음입니다. 일반판은 왼쪽 0·1번, 오른쪽 2·3번 자리입니다.
  List<String> _owners() {
    if (game.strategy) return [left ? 'blue' : 'white'];
    final seats = game.seated;
    return [
      for (final player in seats)
        if ((player.seatIndex < 2) == left) player.uid,
    ];
  }

  String? _ribbonText(bool active) {
    if (game.finished) return null;
    final turn = game.player(game.turnUid);
    final turnTeam = game.strategy ? game.turnTeam : turn?.team;
    if (capture) {
      return yutText(
        '잡았다! ${game.strategy ? YutCopy.teamName(turnTeam) : turn?.nickname ?? ''} 한 번 더',
        'Captured! One more',
        '吃子！再来一次',
        '吃子！再來一次',
      );
    }
    if (reveal) {
      return yutText('윷 던지는 중…', 'Throwing…', '掷柶中…', '擲柶中…');
    }
    if (game.strategy) {
      if (game.selecting) {
        return yutText(
          '${YutCopy.teamName(left ? YutTeam.blue : YutTeam.white)} · 윷 고르는 중 ${game.choiceCount}/4',
          '${YutCopy.teamName(left ? YutTeam.blue : YutTeam.white)} · choosing ${game.choiceCount}/4',
          '${YutCopy.teamName(left ? YutTeam.blue : YutTeam.white)} · 选择中 ${game.choiceCount}/4',
          '${YutCopy.teamName(left ? YutTeam.blue : YutTeam.white)} · 選擇中 ${game.choiceCount}/4',
        );
      }
      if (game.moving) {
        return active
            ? yutText(
                '말을 꾹 눌러 끌어 놓아요',
                'Press and drag a piece',
                '长按并拖动棋子',
                '長按並拖動棋子',
              )
            : yutText(
                '${YutCopy.teamName(turnTeam)}이 옮기는 중…',
                '${YutCopy.teamName(turnTeam)} is moving…',
                '${YutCopy.teamName(turnTeam)}移动中…',
                '${YutCopy.teamName(turnTeam)}移動中…',
              );
      }
      return null;
    }
    if (!left) return null;
    final name = turn?.nickname ?? '';
    if (game.rolling) {
      return yutText(
        '$name 차례 · 휴대폰을 흔들어요',
        "$name's turn · shake the phone",
        '$name的回合 · 摇动手机',
        '$name的回合 · 搖動手機',
      );
    }
    if (game.moving) {
      return yutText(
        '$name · 말을 꾹 눌러 끌어 놓아요',
        '$name · press and drag a piece',
        '$name · 长按并拖动棋子',
        '$name · 長按並拖動棋子',
      );
    }
    return null;
  }
}

/// 아직 출발하지 않은 말 더미와 낸 말 수입니다. 내 차례면 끌어서 판에 놓습니다.
class _ReadyStack extends StatelessWidget {
  const _ReadyStack({
    required this.game,
    required this.owner,
    required this.unit,
    required this.canDrag,
    required this.pieceSize,
    required this.busy,
  });
  final YutGameView game;
  final String owner;
  final double unit;
  final bool canDrag;
  final double pieceSize;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final pieces = game.piecesOf(owner);
    final ready = pieces.where((piece) => piece.ready).toList();
    final finished = pieces.where((piece) => piece.finished).length;
    final team = game.teamOfOwner(owner);
    final size = 64 * unit.clamp(.7, 1.2);
    final canEnter =
        canDrag && !busy && game.pool.any((chip) => chip.result.steps > 0);
    final edition = game.edition;
    final player = game.strategy ? null : game.player(owner);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (player != null) ...[
              MosiFace(characterId: player.characterId, size: 26 * unit + 8),
              SizedBox(width: 6 * unit),
            ],
            Text(
              player?.nickname ?? YutCopy.teamName(team),
              style: YutFonts.title(
                22 * unit.clamp(.8, 1.2),
                color: edition ? YutColors.moon : YutColors.ink,
              ),
            ),
            SizedBox(width: 8 * unit),
            Text(
              yutText(
                '남은 말 ${ready.length} · 난 말 $finished',
                'Waiting ${ready.length} · Home $finished',
                '待出 ${ready.length} · 到家 $finished',
                '待出 ${ready.length} · 到家 $finished',
              ),
              style: YutFonts.text(
                16 * unit.clamp(.8, 1.2),
                color: edition ? YutColors.haze : YutColors.muted,
                weight: FontWeight.w700,
              ),
            ),
          ],
        ),
        SizedBox(height: 6 * unit),
        SizedBox(
          height: size * 1.2,
          width: size + math.max(0, ready.length - 1) * size * .62 + 8,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (var i = 0; i < ready.length; i++)
                Positioned(
                  left: i * size * .62,
                  top: 0,
                  // 더미에서 바로 끌어 판에 놓습니다.
                  child: YutStackDraggable(
                    game: game,
                    owner: owner,
                    pieceId: ready[i].id,
                    pieceSize: pieceSize,
                    enabled: canEnter,
                    child: Container(
                      decoration: canEnter
                          ? BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      (edition
                                              ? YutColors.lilac
                                              : YutColors.blue)
                                          .withValues(alpha: .3),
                                  blurRadius: 14,
                                  spreadRadius: 2,
                                ),
                              ],
                            )
                          : null,
                      child: YutPieceToken(
                        team: team,
                        label:
                            game.pieceKeeper(owner, ready[i].id)?.initial ?? '',
                        size: size,
                        edition: edition,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 이번 차례에 나온 윷(아직 쓰지 않은 것)입니다.
class _PoolRow extends StatelessWidget {
  const _PoolRow({required this.game, required this.team, required this.unit});
  final YutGameView game;
  final YutTeam? team;
  final double unit;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Text(
        yutText('나온 윷', 'Results', '结果', '結果'),
        style: YutFonts.text(
          14 * unit.clamp(.8, 1.2),
          weight: FontWeight.w800,
          color: game.edition ? YutColors.haze : YutColors.muted,
        ),
      ),
      SizedBox(height: 6 * unit),
      Wrap(
        spacing: 8 * unit,
        children: [
          for (final chip in game.pool)
            YutChipButton(
              result: chip.result,
              team: team,
              edition: game.edition,
              scale: unit.clamp(.75, 1.15),
            ),
        ],
      ),
    ],
  );
}

/// 윷가락이 던져져 흩어졌다가 가운데 모이고 결과 도장이 찍히는 연출입니다.
class _RevealOverlay extends StatefulWidget {
  const _RevealOverlay({
    super.key,
    required this.game,
    required this.roll,
    required this.endsAt,
    required this.unit,
  });
  final YutGameView game;
  final YutRollView roll;
  final int endsAt;
  final double unit;

  @override
  State<_RevealOverlay> createState() => _RevealOverlayState();
}

class _RevealOverlayState extends State<_RevealOverlay>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: _revealDuration,
  );

  @override
  void initState() {
    super.initState();
    final elapsed =
        _revealDuration.inMilliseconds -
        (widget.endsAt - DateTime.now().millisecondsSinceEpoch);
    _controller.forward(
      from: (elapsed / _revealDuration.inMilliseconds).clamp(0.0, 1.0),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 사람마다 하나씩(전략) 또는 던진 사람의 윷 네 개(일반)입니다.
  List<
    ({
      String? characterId,
      String? name,
      bool front,
      YutTeam? team,
      bool marked,
    })
  >
  _sticks() {
    final game = widget.game;
    final roll = widget.roll;
    if (game.strategy && roll.revealed.isNotEmpty) {
      final players = game.seated.toList()
        ..sort((a, b) {
          final teamOrder = (a.team == YutTeam.blue ? 0 : 1).compareTo(
            b.team == YutTeam.blue ? 0 : 1,
          );
          return teamOrder != 0
              ? teamOrder
              : a.seatIndex.compareTo(b.seatIndex);
        });
      return [
        for (final player in players)
          if (roll.revealed.containsKey(player.uid))
            (
              characterId: player.characterId,
              name: player.nickname,
              front: roll.revealed[player.uid]!,
              team: player.team,
              marked: false,
            ),
      ];
    }
    final thrower = game.player(roll.actorUid);
    return [
      for (var i = 0; i < roll.stickUps.length; i++)
        (
          characterId: thrower?.characterId,
          name: null,
          front: roll.stickUps[i],
          team: thrower?.team,
          marked: i == 0,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final edition = game.edition;
    final sticks = _sticks();
    final unit = widget.unit * 1.3;
    final stickWidth = 92 * unit;
    final gap = 110 * unit;
    final again = widget.roll.result.throwsAgain;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value * _revealDuration.inMilliseconds;
          final trayIn = Curves.easeOut.transform((t / 220).clamp(0.0, 1.0));
          final fadeOut = 1 - ((t - 1900) / 300).clamp(0.0, 1.0);
          final align = Curves.easeInOutCubic.transform(
            ((t - 700) / 350).clamp(0.0, 1.0),
          );
          final stamp = ((t - 1100) / 250).clamp(0.0, 1.0);
          return Opacity(
            opacity: fadeOut,
            child: LayoutBuilder(
              builder: (context, box) {
                final center = box.biggest.center(Offset.zero);
                final trayW = 510 * unit;
                final trayH = 478 * unit;
                final rowTop = center.dy - trayH / 2 + 31 * unit;
                return Stack(
                  children: [
                    Positioned.fill(
                      child: ColoredBox(
                        color:
                            (edition ? Colors.black : const Color(0xFF2E2A26))
                                .withValues(alpha: .18 * trayIn),
                      ),
                    ),
                    Positioned(
                      left: center.dx - trayW / 2,
                      top: center.dy - trayH / 2 + (1 - trayIn) * 40,
                      width: trayW,
                      height: trayH,
                      child: Opacity(
                        opacity: trayIn,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: edition
                                ? YutColors.nightPanel.withValues(alpha: .94)
                                : const Color(0xE6F4F2EE),
                            borderRadius: BorderRadius.circular(26 * unit),
                            border: Border.all(
                              color: edition
                                  ? YutColors.lilac
                                  : const Color(0xFF7E828B),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: edition
                                    ? Colors.black
                                    : const Color(0xFFA3A7AF),
                                offset: const Offset(0, 9),
                              ),
                              const BoxShadow(
                                color: Color(0x4728282E),
                                offset: Offset(14, 26),
                                blurRadius: 26,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    for (var i = 0; i < sticks.length; i++)
                      _stick(
                        i,
                        sticks,
                        t,
                        align,
                        center,
                        rowTop,
                        stickWidth,
                        gap,
                        box.biggest,
                      ),
                    if (stamp > 0)
                      Positioned(
                        left: center.dx - 70 * unit,
                        top: center.dy + 100 * unit,
                        child: Opacity(
                          opacity: stamp,
                          child: Transform.scale(
                            scale:
                                1.6 - .6 * Curves.easeOutBack.transform(stamp),
                            child: YutResultStamp(
                              result: widget.roll.result,
                              size: 140 * unit,
                              edition: edition,
                              caption: again
                                  ? yutText(
                                      '${widget.roll.result.steps}칸 · 한 번 더',
                                      '${widget.roll.result.steps} · again',
                                      '${widget.roll.result.steps}格 · 再来',
                                      '${widget.roll.result.steps}格 · 再來',
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    if (stamp >= 1 && again)
                      Positioned(
                        left: 0,
                        right: 0,
                        top: center.dy - trayH / 2 - 70 * widget.unit,
                        child: Center(
                          child: YutRibbon(
                            text: yutText(
                              '${YutCopy.result(widget.roll.result)}! 한 번 더',
                              '${YutCopy.result(widget.roll.result)}! One more',
                              '${YutCopy.result(widget.roll.result)}！再来一次',
                              '${YutCopy.result(widget.roll.result)}！再來一次',
                            ),
                            team: null,
                            edition: edition,
                            alert: true,
                            fontSize: 30 * widget.unit,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _stick(
    int i,
    List<
      ({
        String? characterId,
        String? name,
        bool front,
        YutTeam? team,
        bool marked,
      })
    >
    sticks,
    double t,
    double align,
    Offset center,
    double rowTop,
    double width,
    double gap,
    Size screen,
  ) {
    final stick = sticks[i];
    final count = sticks.length;
    final rowLeft = center.dx + (i - (count - 1) / 2) * gap - width / 2;
    final fromLeft = widget.game.strategy
        ? stick.team == YutTeam.blue
        : i.isEven;
    // 던지는 쪽에서 날아와 흩어진 자리에 멈춥니다.
    final scatter = Offset(
      (i - (count - 1) / 2) * gap * 1.25 + math.sin(i * 2.1) * 30,
      math.cos(i * 1.7) * 60 + 20,
    );
    final start = Offset(
      fromLeft ? -width * 2 : screen.width + width,
      center.dy,
    );
    final fly = Curves.easeOutCubic.transform(
      ((t - i * 35) / 500).clamp(0.0, 1.0),
    );
    final scattered = Offset.lerp(start, center + scatter, fly)!;
    final rowPoint = Offset(
      rowLeft + width / 2,
      rowTop + width * YutStick.aspect / 2,
    );
    final point = Offset.lerp(scattered, rowPoint, align)!;
    final spin =
        (1 - fly) * (fromLeft ? -4 : 4) + (1 - align) * math.sin(i * 1.3) * .6;
    final labelOpacity = ((t - 1000) / 250).clamp(0.0, 1.0);
    final height = width * YutStick.aspect;
    return Positioned(
      left: point.dx - width / 2,
      top: point.dy - height / 2,
      child: Column(
        children: [
          Transform.rotate(
            angle: spin,
            child: YutStick(
              front: stick.front,
              width: width,
              edition: widget.game.edition,
              characterId: stick.characterId,
              marked: stick.marked,
            ),
          ),
          SizedBox(height: 6 * widget.unit),
          Opacity(
            opacity: labelOpacity,
            child: Column(
              children: [
                Text(
                  stick.front ? YutCopy.front : YutCopy.back,
                  style: YutFonts.stamp(
                    26 * widget.unit,
                    color: widget.game.edition
                        ? (stick.front ? YutColors.lilac : YutColors.haze)
                        : (stick.front
                              ? YutColors.red
                              : const Color(0xFF5A564F)),
                  ),
                ),
                if (stick.name != null)
                  Text(
                    stick.name!,
                    style: YutFonts.text(
                      14 * widget.unit,
                      weight: FontWeight.w800,
                      color: widget.game.edition
                          ? YutColors.moon
                          : YutColors.ink,
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

class _PauseBanner extends StatelessWidget {
  const _PauseBanner();

  @override
  Widget build(BuildContext context) => Positioned(
    left: 0,
    right: 0,
    top: 0,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      color: const Color(0xE68A5C21),
      alignment: Alignment.center,
      child: Text(
        yutText(
          '참가자 기기 연결을 확인하고 있어요. 잠시 기다려 주세요.',
          'Waiting for player devices to reconnect.',
          '正在确认玩家设备连接，请稍候。',
          '正在確認玩家裝置連線，請稍候。',
        ),
        style: YutFonts.text(16, color: Colors.white, weight: FontWeight.w700),
      ),
    ),
  );
}

/// 경기 결과(다시 하기 / 로비로 나가기)입니다.
class _TabletResult extends StatelessWidget {
  const _TabletResult({
    required this.game,
    required this.onRestart,
    required this.onHome,
  });
  final YutGameView game;
  final VoidCallback onRestart;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final edition = game.edition;
    final natural = game.finishReason == 'winner';
    final winnerTeam = game.winningTeam;
    final winner = game.player(game.winnerUid);
    final headline = !natural
        ? yutText('경기가 끝났어요', 'Game over', '游戏结束', '遊戲結束')
        : game.strategy
        ? yutText(
            '${YutCopy.teamName(winnerTeam)} 승리!',
            '${YutCopy.teamName(winnerTeam)} wins!',
            '${YutCopy.teamName(winnerTeam)}获胜！',
            '${YutCopy.teamName(winnerTeam)}獲勝！',
          )
        : yutText(
            '${winner?.nickname ?? ''} 승리!',
            '${winner?.nickname ?? ''} wins!',
            '${winner?.nickname ?? ''}获胜！',
            '${winner?.nickname ?? ''}獲勝！',
          );
    final groups = game.strategy
        ? [
            for (final team in [YutTeam.blue, YutTeam.white])
              (
                owner: team.name,
                title: YutCopy.teamName(team),
                players: game.teamPlayers(team),
                team: team,
              ),
          ]
        : [
            for (final player in game.seated)
              (
                owner: player.uid,
                title: player.nickname,
                players: [player],
                team: player.team,
              ),
          ];
    groups.sort((a, b) {
      final aw =
          natural &&
          (a.owner == game.winnerUid || a.team == winnerTeam && game.strategy);
      final bw =
          natural &&
          (b.owner == game.winnerUid || b.team == winnerTeam && game.strategy);
      return (bw ? 1 : 0) - (aw ? 1 : 0);
    });
    return YutBackground(
      edition: edition,
      tablet: true,
      child: Stack(
        children: [
          if (natural)
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
                count: 34,
              ),
            ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, box) {
                final unit = box.maxHeight / 1024;
                return Column(
                  children: [
                    SizedBox(height: 60 * unit),
                    edition
                        ? YutHoloText(
                            headline,
                            style: YutFonts.title(84 * unit + 8),
                          )
                        : Text(
                            headline,
                            style: YutFonts.title(
                              84 * unit + 8,
                              color: natural && winnerTeam != YutTeam.white
                                  ? YutTeamStyle.of(winnerTeam).fill
                                  : YutColors.ink,
                            ),
                          ),
                    const Spacer(),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 28 * unit,
                      runSpacing: 20 * unit,
                      children: [
                        for (final group in groups)
                          _ResultPanel(
                            game: game,
                            owner: group.owner,
                            title: group.title,
                            players: group.players,
                            team: group.team,
                            won:
                                natural &&
                                (group.owner == game.winnerUid ||
                                    (game.strategy &&
                                        group.team == winnerTeam)),
                            unit: unit,
                          ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _ResultButton(
                          label: yutText('다시 하기', 'Play again', '再来一局', '再來一局'),
                          icon: Icons.refresh_rounded,
                          primary: true,
                          edition: edition,
                          onPressed: onRestart,
                        ),
                        SizedBox(width: 24 * unit),
                        _ResultButton(
                          label: yutText(
                            '로비로 나가기',
                            'Back to lobby',
                            '返回大厅',
                            '返回大廳',
                          ),
                          icon: Icons.door_front_door_outlined,
                          primary: false,
                          edition: edition,
                          onPressed: onHome,
                        ),
                      ],
                    ),
                    SizedBox(height: 56 * unit),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({
    required this.game,
    required this.owner,
    required this.title,
    required this.players,
    required this.team,
    required this.won,
    required this.unit,
  });
  final YutGameView game;
  final String owner;
  final String title;
  final List<YutPlayerView> players;
  final YutTeam? team;
  final bool won;
  final double unit;

  @override
  Widget build(BuildContext context) {
    final edition = game.edition;
    final finished = game.finishedCount(owner);
    final s = unit.clamp(.7, 1.2);
    return Container(
      width: (game.strategy ? 360 : 250) * s,
      padding: EdgeInsets.all(22 * s),
      decoration: BoxDecoration(
        color: edition ? YutColors.nightPanel : YutColors.paperLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: edition
              ? (won ? YutColors.lilac : YutColors.nightEdge)
              : YutColors.edge,
          width: won ? 3 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: edition ? Colors.black : YutColors.edgeShadow,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: YutFonts.title(
                    30 * s,
                    color: edition ? YutColors.moon : YutColors.ink,
                  ),
                ),
              ),
              SizedBox(width: 10 * s),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 12 * s,
                  vertical: 4 * s,
                ),
                decoration: BoxDecoration(
                  color: won
                      ? (edition ? null : YutColors.blue)
                      : (edition ? YutColors.nightRaised : YutColors.grey),
                  gradient: won && edition ? YutColors.holoGradient : null,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  won
                      ? yutText('승리', 'Win', '胜', '勝')
                      : yutText('패배', 'Lose', '负', '負'),
                  style: YutFonts.title(
                    17 * s,
                    color: won
                        ? (edition ? YutColors.night : Colors.white)
                        : (edition ? YutColors.haze : YutColors.muted),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16 * s),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final player in players)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10 * s),
                  child: Column(
                    children: [
                      MosiFace(
                        characterId: player.characterId,
                        size: 84 * s,
                        ring: !edition,
                      ),
                      SizedBox(height: 6 * s),
                      Text(
                        player.nickname,
                        style: YutFonts.text(
                          15 * s,
                          weight: FontWeight.w800,
                          color: edition ? YutColors.moon : YutColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          SizedBox(height: 14 * s),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 4; i++)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 3 * s),
                  child: Opacity(
                    opacity: i < finished ? 1 : .3,
                    child: YutPieceToken(
                      team: team,
                      label: YutCopy.teamMark(team),
                      size: 30 * s,
                      edition: edition,
                      characterId: game.strategy
                          ? null
                          : players.firstOrNull?.characterId,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 10 * s),
          Text(
            yutText(
              '말 $finished개 났어요',
              '$finished piece${finished == 1 ? '' : 's'} home',
              '$finished枚棋子到家',
              '$finished枚棋子到家',
            ),
            style: YutFonts.text(
              15 * s,
              weight: FontWeight.w700,
              color: edition ? YutColors.haze : YutColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultButton extends StatelessWidget {
  const _ResultButton({
    required this.label,
    required this.icon,
    required this.primary,
    required this.edition,
    required this.onPressed,
  });
  final String label;
  final IconData icon;
  final bool primary;
  final bool edition;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final fg = primary
        ? (edition ? YutColors.night : Colors.white)
        : (edition ? YutColors.moon : YutColors.ink);
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 260,
          height: 64,
          decoration: BoxDecoration(
            color: primary
                ? (edition ? null : YutColors.blue)
                : (edition ? YutColors.nightPanel : YutColors.paperLight),
            gradient: primary && edition ? YutColors.holoGradient : null,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: primary
                  ? (edition ? YutColors.night : YutColors.blueDeep)
                  : (edition ? YutColors.lilac : YutColors.edge),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: primary
                    ? (edition ? Colors.black : YutColors.blueDeep)
                    : (edition ? Colors.black : YutColors.edgeShadow),
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: fg, size: 24),
              const SizedBox(width: 8),
              Text(label, style: YutFonts.title(24, color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}
