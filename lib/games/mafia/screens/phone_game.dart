import 'dart:async';
import 'package:project00/games/mafia/loading/mafia_loading.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:project00/core/assets/game_asset_store.dart';
import 'package:project00/core/assets/game_image.dart';
import 'package:project00/core/layout/app_orientation.dart';
import 'package:project00/core/layout/app_system_ui.dart';
import 'package:project00/games/mafia/controllers/mafia_controller.dart';
import 'package:project00/games/mafia/providers/mafia_game_state.dart';
import 'package:project00/games/mafia/providers/mafia_session_provider.dart';
import 'package:project00/games/mafia/screens/phone/phone_game_screen.dart';
import 'package:project00/games/mafia/services/mafia_service.dart';
import 'package:project00/games/mafia/widgets/phone/mafia_phone_layout.dart';
import 'package:project00/games/mafia/widgets/phone/result_sequence.dart';
import 'package:project00/games/mafia/widgets/phone/top_bar.dart';
import 'package:project00/games/shared/game_flow/game_flow_copy.dart';
import 'package:project00/games/shared/game_flow/game_screen_phase.dart';
import 'package:project00/games/shared/game_flow/phone_game_shell.dart';
import 'package:project00/games/shared/widgets/game_interruption_layer.dart';
import 'package:project00/games/shared/widgets/phone_exit_modal.dart';
import 'package:project00/gen/assets.gen.dart';

/// 마피아 휴대폰 화면의 진입점입니다.
///
/// 서버 단계를 공용 셸의 [GameScreenPhase]로 옮기고, 실제 화면 구성은
/// [MafiaPhoneGameScreen]에 맡깁니다.
class MafiaPhoneGame extends ConsumerStatefulWidget {
  const MafiaPhoneGame({
    super.key,
    required this.roomCode,
    required this.gameService,
    required this.onExitRoom,
  });

  final String roomCode;
  final MafiaService gameService;
  final Future<bool> Function() onExitRoom;

  @override
  ConsumerState<MafiaPhoneGame> createState() => _MafiaPhoneGameState();
}

class _MafiaPhoneGameState extends ConsumerState<MafiaPhoneGame> {
  MafiaController? controller;
  ProviderSubscription<MafiaGameState>? sessionSubscription;
  String? initializationError;
  bool hasScheduledManualExit = false;
  bool _isLeavingRoom = false;
  String? previousStatus;

  @override
  void initState() {
    super.initState();
    // 게임에 들어가면 시스템 UI를 감추고 시안대로 세로로 고정합니다.
    // 플랫폼 화면으로 돌아갈 때 dispose에서 복원합니다.
    unawaited(AppSystemUi.enterGameFullscreen());
    unawaited(AppOrientation.applyPhoneGame(PhoneGameOrientation.portraitOnly));
    // 서버 에셋 도입 대비 훅입니다. 실패해도 번들 폴백으로 진행합니다.
    unawaited(GameAssetStore.instance.prepareGame('mafia').catchError((_) {}));

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      initializationError = GameFlowCopy.authenticationRequired;
      return;
    }
    final args = MafiaSessionArgs(
      roomCode: widget.roomCode,
      uid: uid,
      service: widget.gameService,
      // 휴대폰만 내 역할·조사 결과를 구독합니다.
      watchPrivate: true,
    );
    final provider = mafiaSessionProvider(args);
    sessionSubscription = ref.listenManual(provider, (_, _) => _handleState());
    controller = ref.read(provider.notifier);
    // 첫 조작이 콜드스타트로 늦지 않게 서버를 미리 깨웁니다.
    unawaited(controller!.warmUp());
    // 첫 화면(P1) 이미지와 효과음을 미리 준비합니다. context가 필요한
    // 작업이라 첫 프레임 뒤로 미룹니다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(preloadMafiaAssets(context, isPhone: true));
    });
  }

  void _handleState() {
    final game = controller;
    if (game == null || !mounted) return;
    if (previousStatus == 'finished' && !game.isFinished) {
      hasScheduledManualExit = false;
    }
    previousStatus = game.status;

    // 나가야 할 종료 사유를 나열하지 않고 '정상 결과가 아니면 나간다'로 뒤집어
    // 판단합니다. 사유 목록 방식은 서버에 사유가 하나만 늘어도 휴대폰이 결과
    // 화면에 갇힙니다.
    if (game.isFinished && !game.isNaturalResult) {
      if (_isLeavingRoom || hasScheduledManualExit) return;
      hasScheduledManualExit = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
      return;
    }
    hasScheduledManualExit = false;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    sessionSubscription?.close();
    unawaited(AppOrientation.lockPlatformPortrait());
    unawaited(AppSystemUi.showPlatformSystemBars());
    super.dispose();
  }

  //=======================단계 번역 — 한곳에서만==============================
  GameScreenPhase _resolvePhase(MafiaController game) {
    // 1. 첫 공개 상태를 기다립니다. 배경만 보여 줍니다.
    if (game.loading) return GameScreenPhase.connecting;
    // 2. 정상 승부가 아닌 종료는 결과 화면을 만들지 않습니다. 로딩 검사보다
    //    먼저 두어야 수동 종료 직후 연결 화면으로 잘못 돌아가지 않습니다.
    if (game.isFinished && !game.isNaturalResult) {
      return GameScreenPhase.closing;
    }
    // 3. 승부가 확정되면 결과입니다.
    if (game.isFinished) return GameScreenPhase.result;
    // 마피아는 GAME START·ROUND N 연출이 없습니다. 시안에 그 화면이 없고,
    // 밤/낮 전환 발표는 태블릿이 담당합니다.
    return GameScreenPhase.playing;
  }

  @override
  Widget build(BuildContext context) {
    final error = initializationError;
    if (error != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(error, style: const TextStyle(color: Colors.white)),
        ),
      );
    }
    final game = controller;
    if (game == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final phase = _resolvePhase(game);
    final closingMessage = switch (game.finishReason) {
      'interruptionVoteExpired' => GameFlowCopy.interruptionVoteExpired,
      'insufficientPlayers' => GameFlowCopy.insufficientPlayers,
      _ => GameFlowCopy.gameFinished,
    };

    return Stack(
      fit: StackFit.expand,
      children: [
        PhoneGameShell(
          phase: phase,
          roundNumber: game.round,
          closingMessage: closingMessage,
          introTextColor: Colors.black,
          // 연결·종료 단계에서 보이는 바탕입니다. 진행 화면은 각 시안 위젯이
          // 자기 배경을 그립니다.
          background: MafiaPhoneBackground(isNight: game.isNight),
          onIntroCompleted: () {},
          onRoundIntroCompleted: () {},
          onConnectingExit: () => unawaited(_leaveRoom()),
          topBar: MafiaPhoneTopBar(
            onExitRoom: () => unawaited(_leaveRoom()),
            onRulesPressed: (origin) => showMafiaRules(context, origin),
          ),
          // 확정(2026-08): 승리 그림 2초 → 전원 신분 명단.
          result: game.isNaturalResult
              ? MafiaPhoneResultSequence(
                  winner: game.winnerFaction,
                  players: game.orderedPlayers,
                  revealedRoles: {
                    for (final player in game.orderedPlayers)
                      player.uid: game.revealedRoleOf(player.uid),
                  },
                  myRole: game.myRole,
                )
              : const SizedBox.shrink(),
          content: Stack(
            fit: StackFit.expand,
            children: [
              RepaintBoundary(child: MafiaPhoneGameScreen(controller: game)),
              if (game.commandInFlight)
                const Positioned(
                  right: 14,
                  bottom: 14,
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
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
    );
  }

  Future<void> _leaveRoom() async {
    final leave = await SharedPhoneExitModal.show(
      context,
      // 마피아 전용 모달 그림이 없어 나가기 아이콘을 그대로 씁니다.
      doorImage: Assets.games.mafia.images.icons.iconOut.game.image(
        fit: BoxFit.contain,
      ),
      surfaceColor: Colors.white,
      titleColor: Colors.black,
      descriptionColor: Colors.black,
      primaryColor: const Color(0xFF212730),
    );
    if (leave != true || !mounted) return;
    if (_isLeavingRoom) return;
    _isLeavingRoom = true;
    final left = await widget.onExitRoom();
    if (!mounted) return;
    if (left) {
      // 서버 퇴장 성공 뒤에 게임 라우트를 먼저 닫습니다. 방향 복원을 먼저
      // 기다리면 회전 응답이 지연될 때 화면에 갇힐 수 있습니다.
      Navigator.of(context).pop(true);
      return;
    }
    _isLeavingRoom = false;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text(GameFlowCopy.leaveFailed)));
  }
}
