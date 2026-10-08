import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_holdem/game_copy.dart';
import 'package:game_holdem/game_sounds.dart';
import 'package:game_holdem/game_theme.dart';
import 'package:game_holdem/shared/models/game_state.dart';
import 'package:game_holdem/shared/models/presentation_timing.dart';
import 'package:game_holdem/shared/providers/game_controller.dart';
import 'package:game_holdem/shared/providers/session_provider.dart';
import 'package:game_holdem/shared/services/game_service.dart';
import 'package:game_holdem/shared/widgets/table_ui.dart';
import 'package:game_holdem/tablet/screens/table_screen.dart';
import 'package:game_kit/core/time/server_clock.dart';
import 'package:game_kit/models/game_room_context.dart';
import 'package:game_kit/player_layouts/models/player_layout.dart';
import 'package:game_kit/recovery/widgets/game_recovery_layer.dart';
import 'package:game_kit/sound/sound_effects.dart';
import 'package:game_kit/tablet/widgets/game_rulebook_dialog.dart';
import 'package:game_kit/tablet/widgets/game_menu_overlay.dart';
import 'package:game_kit/tablet/widgets/game_settings_dialog.dart';

class HoldemTabletGame extends ConsumerStatefulWidget {
  const HoldemTabletGame({
    super.key,
    required this.playerLayout,
    required this.provider,
    required this.roomCode,
    required this.gameService,
  });
  final PlayerLayoutModel playerLayout;
  final GameRoomContext provider;
  final String roomCode;
  final HoldemService gameService;

  @override
  ConsumerState<HoldemTabletGame> createState() => _HoldemTabletGameState();
}

class _HoldemTabletGameState extends ConsumerState<HoldemTabletGame> {
  HoldemSessionArgs? _args;
  Timer? _phaseTimer;
  Timer? _turnTimer;
  (String, int)? _scheduledPhase;
  int? _scheduledDeadline;
  bool _soundPreloaded = false;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _args = HoldemSessionArgs(
        roomCode: widget.roomCode,
        uid: uid,
        service: widget.gameService,
        watchPrivate: false,
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_soundPreloaded) return;
    final sound = SoundEffects.of(context);
    if (sound == null) return;
    _soundPreloaded = true;
    unawaited(
      sound.preloadEffects(
        HoldemSounds.preloadTargets,
        solo: true,
        scope: 'holdem',
      ),
    );
  }

  void _syncAutomation(HoldemGameState game, HoldemController controller) {
    final phaseKey = (game.phase, game.handNumber);
    if (_scheduledPhase != phaseKey) {
      _scheduledPhase = phaseKey;
      _phaseTimer?.cancel();
      if (game.phase == 'dealing') {
        _phaseTimer = Timer(HoldemTiming.dealing, () {
          final args = _args;
          if (mounted &&
              args != null &&
              ref.read(holdemSessionProvider(args)).phase == 'dealing') {
            unawaited(controller.completeDealing());
          }
        });
      } else if (game.phase == 'handResult') {
        _phaseTimer = Timer(HoldemTiming.handResult(game.result?.reason), () {
          final args = _args;
          if (mounted &&
              args != null &&
              ref.read(holdemSessionProvider(args)).phase == 'handResult') {
            unawaited(controller.completeResult());
          }
        });
      }
    }
    final deadline = game.turnDeadlineAt;
    if (_scheduledDeadline != deadline) {
      _scheduledDeadline = deadline;
      _turnTimer?.cancel();
      if (deadline != null) {
        final remaining = ServerClock.remainingUntil(deadline);
        _turnTimer = Timer(remaining + const Duration(milliseconds: 120), () {
          final args = _args;
          if (mounted &&
              args != null &&
              ref.read(holdemSessionProvider(args)).turnDeadlineAt ==
                  deadline) {
            unawaited(controller.timeoutTurn());
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _phaseTimer?.cancel();
    _turnTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final args = _args;
    if (args == null) {
      return const Scaffold(body: Center(child: Text('진행 기기 인증을 확인할 수 없습니다.')));
    }
    final game = ref.watch(holdemSessionProvider(args));
    final controller = ref.read(holdemSessionProvider(args).notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _syncAutomation(game, controller);
      }
    });
    return Scaffold(
      backgroundColor: HoldemColors.felt,
      body: GameRecoveryLayer(
        request: GameRequestRecovery(
          message: game.errorMessage,
          onRetry: controller.clearError,
        ),
        interruption: GameInterruptionRecovery(
          state: game.interruption,
          currentUid: args.uid,
          presentation: GameInterruptionPresentation.tabletController,
          isSubmitting: game.commandInFlight,
          failureMessage: game.errorMessage,
          onContinue: controller.excludeInterruptedPlayerAndContinue,
          onFinishNow: controller.finishInterruptedGameNow,
          onExpired: controller.expireInterruption,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (!game.loading)
              HoldemTableScreen(game: game, playerLayout: widget.playerLayout),
            if (game.loading)
              const Center(
                child: CircularProgressIndicator(color: HoldemColors.ivory),
              ),
            if (game.isFinished && game.isNaturalResult)
              _TournamentResult(
                game: game,
                onRestart: controller.restartGame,
                onHome: () => _endAndExit(controller),
              ),
            TabletGameMenuOverlay(
              visible: !game.loading && !game.isFinished,
              roleIcon: const _MenuGlyph(Icons.menu_book_rounded),
              settingIcon: const _MenuGlyph(Icons.settings_rounded),
              roleDialogBuilder: (_) => const TabletGameRulebookDialog(
                title: 'TEXAS HOLD’EM',
                markdown: HoldemCopy.tabletRules,
                cardImages: [],
              ),
              settingDialogBuilder: (_) => TabletGameSettingsDialog(
                provider: widget.provider,
                onRestartGame: () => unawaited(controller.restartGame()),
                onEndGame: () => unawaited(_endAndExit(controller)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _endAndExit(HoldemController controller) async {
    if (await controller.endGame() && mounted) Navigator.of(context).maybePop();
  }
}

class _MenuGlyph extends StatelessWidget {
  const _MenuGlyph(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.contain,
    child: Icon(
      icon,
      size: 100,
      color: HoldemColors.ivory,
      shadows: const [
        Shadow(color: Color(0xB3000000), blurRadius: 5, offset: Offset(0, 3)),
      ],
    ),
  );
}

class _TournamentResult extends StatelessWidget {
  const _TournamentResult({
    required this.game,
    required this.onRestart,
    required this.onHome,
  });
  final HoldemGameState game;
  final Future<bool> Function() onRestart;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final winner = game.players[game.winnerUid];
    final standings = game.players.values.toList()
      ..sort((a, b) => b.stack.compareTo(a.stack));
    return ColoredBox(
      color: Colors.black.withValues(alpha: .62),
      child: Center(
        child: Container(
          width: 520,
          padding: const EdgeInsets.fromLTRB(40, 44, 40, 36),
          decoration: BoxDecoration(
            color: HoldemColors.sheet,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: HoldemColors.line(.16)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .5),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _ChampionStamp(),
              const SizedBox(height: 26),
              Text(
                winner?.nickname ?? '승자',
                textAlign: TextAlign.center,
                style: HoldemFonts.text(size: 40, weight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              HoldemChipAmount(
                amount: winner?.stack ?? 0,
                chipSize: 22,
                fontSize: 40,
              ),
              const SizedBox(height: 24),
              for (final (index, player) in standings.skip(1).take(7).indexed)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 36,
                        child: Text(
                          '${index + 2}',
                          style: HoldemFonts.numbers(
                            size: 22,
                            color: HoldemColors.muted,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          player.nickname,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: HoldemFonts.text(
                            size: 16,
                            weight: FontWeight.w700,
                            color: HoldemColors.muted,
                          ),
                        ),
                      ),
                      Text(
                        holdemChips(player.stack),
                        style: HoldemFonts.numbers(
                          size: 22,
                          color: HoldemColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  HoldemPuckButton(
                    label: 'Home',
                    dark: true,
                    size: 108,
                    semanticLabel: '게임 종료하고 홈으로',
                    onPressed: onHome,
                  ),
                  HoldemPuckButton(
                    label: 'Again',
                    size: 120,
                    semanticLabel: '다시 하기',
                    onPressed: () => unawaited(onRestart()),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChampionStamp extends StatelessWidget {
  const _ChampionStamp();

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: -.14,
    child: Container(
      padding: const EdgeInsets.fromLTRB(26, 6, 26, 10),
      decoration: BoxDecoration(
        color: HoldemColors.accent.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HoldemColors.ivory, width: 5),
        boxShadow: [
          BoxShadow(
            color: HoldemColors.accent.withValues(alpha: .9),
            spreadRadius: 4,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: .45),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Text(
        'WINNER',
        style: HoldemFonts.title(
          size: 60,
          shadows: const [
            Shadow(color: Color(0x4D000000), offset: Offset(0, 4)),
          ],
        ),
      ),
    ),
  );
}
