import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:game_kit/recovery/widgets/game_connection_led.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_holdem/game_assets.dart';
import 'package:game_holdem/game_theme.dart';
import 'package:game_holdem/phone/screens/game_screen.dart';
import 'package:game_holdem/phone/widgets/top_bar.dart';
import 'package:game_holdem/shared/widgets/table_ui.dart';
import 'package:game_holdem/shared/models/game_state.dart';
import 'package:game_holdem/shared/providers/session_provider.dart';
import 'package:game_holdem/shared/services/game_service.dart';
import 'package:game_kit/game_flow/game_flow_copy.dart';
import 'package:game_kit/game_flow/game_screen_phase.dart';
import 'package:game_kit/game_flow/phone_game_flow_config.dart';
import 'package:game_kit/game_flow/phone_game_shell.dart';
import 'package:game_kit/errors/widgets/leave_failure_notice.dart';
import 'package:game_kit/models/game_room_context.dart';
import 'package:game_kit/phone/widgets/exit_modal.dart';
import 'package:game_kit/recovery/widgets/game_recovery_layer.dart';

/// 화면 맨 아래 LED 연결 띠입니다(시안: 펠트보다 짙은 초록 바탕, 위쪽 금색 빛 한 줄,
/// 복구는 민트 초록).
const holdemConnectionLed = GameConnectionLedStyle(
  background: Color(0xFF07251A),
  topLineColor: Color(0x99D4AF5A),
  offColor: Color(0xFFFF4B3E),
  retryColor: Color(0xFFFFC14A),
  onColor: Color(0xFF62E6B0),
  textColor: Color(0xFFE6EFE9),
);

class HoldemPhoneGame extends ConsumerStatefulWidget {
  const HoldemPhoneGame({
    super.key,
    required this.roomCode,
    required this.provider,
    required this.gameService,
    required this.onExitRoom,
  });
  final String roomCode;
  final GameRoomContext provider;
  final HoldemService gameService;
  final Future<bool> Function() onExitRoom;

  @override
  ConsumerState<HoldemPhoneGame> createState() => _HoldemPhoneGameState();
}

class _HoldemPhoneGameState extends ConsumerState<HoldemPhoneGame> {
  /// 화면 맨 아래 LED 연결 띠가 듣는 서버 연결 상태입니다. 다시 그려도 같은 스트림을 씁니다.
  late final Stream<bool> _serverConnection = widget.provider
      .watchServerConnection();

  HoldemSessionArgs? _args;
  bool _introCompleted = false;
  int _announcedHand = 0;
  bool _isExitModalOpen = false;
  bool _isLeavingRoom = false;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _args = HoldemSessionArgs(
        roomCode: widget.roomCode,
        uid: uid,
        service: widget.gameService,
        watchPrivate: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = _args;
    if (args == null) {
      return const Scaffold(
        body: Center(child: Text('게임 참가자 인증을 확인할 수 없습니다.')),
      );
    }
    final game = ref.watch(holdemSessionProvider(args));
    final controller = ref.read(holdemSessionProvider(args).notifier);
    final stage = _stage(game);
    final closingMessage = switch (game.finishReason) {
      'interruptionVoteExpired' => GameFlowCopy.interruptionVoteExpired,
      'insufficientPlayers' => GameFlowCopy.insufficientPlayers,
      _ => GameFlowCopy.gameFinished,
    };
    final shell = PhoneGameShell<GameScreenPhase>(
      stage: stage,
      stageRole: _role(stage),
      flowConfig: buildPhoneGameFlowConfig(
        roundNumber: game.handNumber,
        closingMessage: closingMessage,
      ),
      roundNumber: game.handNumber,
      background: ColoredBox(
        color: HoldemColors.felt,
        child: HoldemAssets.phoneBackground.image(
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      ),
      content: KeyedSubtree(
        // ROUND 안내가 끝난 뒤 새 손패 State를 만들고 수령 연출을 시작합니다.
        key: ValueKey('holdem-phone-hand-$_announcedHand'),
        child: HoldemPhoneGameScreen(
          game: game,
          uid: args.uid,
          onAction: controller.act,
        ),
      ),
      topBar: HoldemPhoneTopBar(
        game: game,
        onExit: () => unawaited(_requestExit()),
      ),
      result: _TournamentResult(game: game, uid: args.uid),
      onConnectingExit: () => unawaited(_requestExit()),
      onIntroCompleted: () {
        if (!mounted) return;
        setState(() {
          _introCompleted = true;
          _announcedHand = game.handNumber;
        });
      },
      onRoundIntroCompleted: () {
        if (mounted) {
          setState(() => _announcedHand = game.handNumber);
        }
      },
    );
    return GameConnectionLedHost(
      connectionChanges: _serverConnection,
      style: holdemConnectionLed,
      child: GameRecoveryLayer(
        request: GameRequestRecovery(
          message: game.errorMessage,
          onRetry: controller.clearError,
        ),
        interruption: GameInterruptionRecovery(
          state: game.interruption,
          currentUid: args.uid,
          isSubmitting: game.commandInFlight,
          failureMessage: game.errorMessage,
          onVote: () async {
            await controller.voteToContinueInterruption();
          },
          onExpired: controller.expireInterruption,
        ),
        child: shell,
      ),
    );
  }

  Future<void> _requestExit() async {
    if (_isLeavingRoom || _isExitModalOpen) return;
    _isExitModalOpen = true;
    final leave = await SharedPhoneExitModal.show(
      context,
      doorImage: const _HoldemExitBadge(),
      imageHeight: 150,
      maxWidth: 340,
      surfaceColor: HoldemColors.ivory,
      primaryColor: HoldemColors.accent,
      titleColor: HoldemColors.ink,
      descriptionColor: HoldemColors.ink,
    );
    _isExitModalOpen = false;
    if (leave != true || !mounted) return;

    _isLeavingRoom = true;
    final left = await widget.onExitRoom();
    if (!mounted) return;
    if (left) {
      Navigator.of(context).pop(true);
      return;
    }
    _isLeavingRoom = false;
    showLeaveFailureNotice(context, widget.provider);
  }

  GameScreenPhase _stage(HoldemGameState game) {
    if (game.loading) return GameScreenPhase.connecting;
    if (game.isFinished && !game.isNaturalResult) {
      return GameScreenPhase.closing;
    }
    if (game.isFinished) return GameScreenPhase.result;
    if (!_introCompleted) return GameScreenPhase.intro;
    if (_announcedHand != game.handNumber) return GameScreenPhase.roundIntro;
    return GameScreenPhase.playing;
  }

  PhoneGameShellStageRole _role(GameScreenPhase stage) => switch (stage) {
    GameScreenPhase.connecting => PhoneGameShellStageRole.connecting,
    GameScreenPhase.intro => PhoneGameShellStageRole.intro,
    GameScreenPhase.roundIntro => PhoneGameShellStageRole.roundIntro,
    GameScreenPhase.playing => PhoneGameShellStageRole.playing,
    GameScreenPhase.result => PhoneGameShellStageRole.result,
    GameScreenPhase.closing => PhoneGameShellStageRole.closing,
  };
}

class _HoldemExitBadge extends StatelessWidget {
  const _HoldemExitBadge();

  @override
  Widget build(BuildContext context) => Container(
    color: HoldemColors.felt,
    alignment: Alignment.center,
    child: Stack(
      alignment: Alignment.center,
      children: [
        const HoldemChip(size: 72),
        Icon(
          Icons.exit_to_app_rounded,
          size: 34,
          color: HoldemColors.ivory.withValues(alpha: .95),
        ),
      ],
    ),
  );
}

class _TournamentResult extends StatelessWidget {
  const _TournamentResult({required this.game, required this.uid});
  final HoldemGameState game;
  final String uid;

  @override
  Widget build(BuildContext context) {
    final winner = game.players[game.winnerUid];
    final me = game.players[uid];
    final won = game.winnerUid == uid;
    final rank = me == null
        ? null
        : 1 +
              game.players.values
                  .where((player) => player.stack > me.stack)
                  .length;
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.rotate(
                angle: -.14,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(26, 6, 26, 10),
                  decoration: BoxDecoration(
                    color: won
                        ? HoldemColors.accent.withValues(alpha: .55)
                        : HoldemColors.panel(.7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: won ? HoldemColors.ivory : HoldemColors.line(.5),
                      width: 5,
                    ),
                    boxShadow: [
                      if (won)
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
                    won ? 'WINNER' : 'GAME OVER',
                    style: HoldemFonts.title(
                      size: won ? 60 : 48,
                      color: won ? HoldemColors.ivory : HoldemColors.muted,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 34),
              Text(
                won ? '토너먼트 우승!' : '${winner?.nickname ?? '승자'} 님 우승',
                textAlign: TextAlign.center,
                style: HoldemFonts.text(size: 22, weight: FontWeight.w900),
              ),
              if (winner != null) ...[
                const SizedBox(height: 12),
                HoldemChipAmount(
                  amount: winner.stack,
                  chipSize: 22,
                  fontSize: 44,
                ),
              ],
              if (rank != null && !won) ...[
                const SizedBox(height: 18),
                Text(
                  '내 순위 $rank위',
                  style: HoldemFonts.text(size: 15, color: HoldemColors.muted),
                ),
              ],
              const SizedBox(height: 24),
              Text(
                '태블릿에서 다시 하기를 고를 수 있어요',
                style: HoldemFonts.text(size: 13, color: HoldemColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
