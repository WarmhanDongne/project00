import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:project00/core/layout/app_orientation.dart';
import 'package:project00/games/liars_poker/loading/liars_poker_loading.dart';
import 'package:project00/games/liars_poker/providers/liars_poker_phone_session_provider.dart';
import 'package:project00/games/liars_poker/providers/liars_poker_phone_state.dart';
import 'package:project00/games/liars_poker/controllers/liars_poker_phone_controller.dart';
import 'package:project00/games/liars_poker/screens/phone/phone_game_screen.dart';
import 'package:project00/games/shared/widgets/phone_result_dialog.dart';
import 'package:project00/games/liars_poker/widgets/phone/spectator.dart';
import 'package:project00/games/liars_poker/services/liars_poker_service.dart';
import 'package:project00/games/shared/animations/game_entry_unroll.dart';
import 'package:project00/games/shared/game_flow/game_flow_copy.dart';
import 'package:project00/games/shared/player_layouts/player_layout_model.dart';
import 'package:project00/gen/assets.gen.dart';
import 'package:project00/games/shared/widgets/game_interruption_layer.dart';

/// 기기 방향과 관계없이 하나의 Firebase 구독 컨트롤러를 유지합니다.
class LiarsPokerPhoneGame extends ConsumerStatefulWidget {
  const LiarsPokerPhoneGame({
    super.key,
    required this.roomCode,
    required this.gameService,
    required this.onExitRoom,
  });

  final String roomCode;
  final LiarsPokerService gameService;
  final Future<bool> Function() onExitRoom;

  @override
  ConsumerState<LiarsPokerPhoneGame> createState() =>
      _LiarsPokerPhoneGameState();
}

class _LiarsPokerPhoneGameState extends ConsumerState<LiarsPokerPhoneGame> {
  LiarsPokerPhoneController? _controller;
  LiarsPokerPhoneSessionArgs? _sessionArgs;
  ProviderSubscription<LiarsPokerPhoneState>? _sessionSubscription;
  String? _initializationError;
  bool _hasScheduledGameExit = false;
  bool _isLeavingRoom = false;
  bool _hasEnteredGame = false;
  bool _isResultDialogOpen = false;
  String? _shownWinnerUid;
  BuildContext? _resultDialogContext;
  int _resultDialogGeneration = 0;

  @override
  void initState() {
    super.initState();
    //=======================휴대폰 게임 방향 정책==============================
    // Liar's Poker 휴대폰은 세로와 양쪽 가로를 모두 지원합니다.
    // 태블릿에는 이 정책을 적용하지 마세요. 모든 태블릿 게임은 가로 고정입니다.
    unawaited(
      AppOrientation.applyPhoneGame(PhoneGameOrientation.portraitAndLandscape),
    );
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _initializationError = GameFlowCopy.authenticationRequired;
      return;
    }

    final args = LiarsPokerPhoneSessionArgs(
      roomCode: widget.roomCode,
      uid: uid,
      service: widget.gameService,
    );
    _sessionArgs = args;
    final provider = liarsPokerPhoneSessionProvider(args);
    _sessionSubscription = ref.listenManual(provider, (_, _) {
      _handleGameStateChanged();
    });
    _controller = ref.read(provider.notifier);
    unawaited(_warmUpAssets());
  }

  /// 매트가 풀리는 배경 위에서 조용히 이미지를 준비합니다. 별도 로딩 화면을
  /// 보여주지 않으므로 실패해도 게임 진행을 막지 않습니다.
  Future<void> _warmUpAssets() async {
    final controller = _controller;
    if (controller == null) return;
    await controller.waitForInitialData();
    if (!mounted) return;
    await preloadLiarsPokerAssets(
      context,
      isPhone: true,
      profileImageUrls: controller.players.values.map(
        (player) => player.profileImageUrl,
      ),
    );
  }

  /// 컨트롤러 알림은 이 화면 한 곳에서만 수신합니다.
  ///
  /// 태블릿에서 게임을 종료하면 휴대폰 게임 화면을 한 번만 닫고, 그 외
  /// 서버 상태 변경은 한 번의 [setState]로 하위 화면에 전달합니다.
  void _handleGameStateChanged() {
    final controller = _controller;
    if (controller == null || !mounted) return;

    if (!controller.isFinished) {
      _hasScheduledGameExit = false;
      _closeResultDialog();
      return;
    }

    // 정상 승리는 화면을 닫지 않고 결과 다이얼로그를 유지합니다. 태블릿의
    // 다시하기 상태를 같은 RTDB 구독으로 받아 즉시 새 게임으로 전환합니다.
    if (controller.isNaturalResult) {
      // 마지막 룰렛으로 승자가 결정된 경우에도 생존/탈락 결과를 먼저
      // 보여준 뒤 우승자 발표 다이얼로그를 엽니다.
      if (!controller.isPenaltyResultVisible) {
        _showResultDialog(controller);
      }
      return;
    }

    // 퇴장 요청으로 게임이 끝난 경우에는 callable 완료 후 홈까지 직접 닫습니다.
    if (_isLeavingRoom) return;

    _closeResultDialog();

    if (_hasScheduledGameExit) return;

    _hasScheduledGameExit = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).maybePop();
    });
  }

  void _showResultDialog(LiarsPokerPhoneController controller) {
    final winnerUid = controller.winnerUid;
    final winner = controller.players[winnerUid];
    if (winnerUid == null || winner == null) return;
    if (_isResultDialogOpen && _shownWinnerUid == winnerUid) return;

    _isResultDialogOpen = true;
    _shownWinnerUid = winnerUid;
    final generation = ++_resultDialogGeneration;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || generation != _resultDialogGeneration) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: const Color(0xC7000000),
        builder: (dialogContext) {
          _resultDialogContext = dialogContext;
          // 우승자 발표는 뒤로 가기로 닫지 않습니다. 이 제한은 다이얼로그
          // 라우트에만 걸어야 합니다. PhoneResultDialog 안에 두면 파이널콜처럼
          // 화면에 직접 그리는 게임에서 게임 라우트가 잠겨 버립니다.
          return PopScope(
            canPop: false,
            child: PhoneResultDialog(
              nickname: winner.nickname,
              profileImageUrl: winner.profileImageUrl,
            ),
          );
        },
      );

      if (generation == _resultDialogGeneration) {
        _resultDialogContext = null;
        _isResultDialogOpen = false;
        _shownWinnerUid = null;
      }
    });
  }

  void _closeResultDialog() {
    _resultDialogGeneration += 1;
    final dialogContext = _resultDialogContext;
    _resultDialogContext = null;
    _isResultDialogOpen = false;
    _shownWinnerUid = null;

    if (dialogContext != null && dialogContext.mounted) {
      Navigator.of(dialogContext).pop();
    }
  }

  Future<bool> _leaveRoom() async {
    if (_isLeavingRoom) return false;
    _isLeavingRoom = true;
    final left = await widget.onExitRoom();
    if (!left) {
      _isLeavingRoom = false;
      return false;
    }

    //=======================퇴장 후 화면 전환==============================
    // 서버 퇴장이 끝나면 게임 라우트를 먼저 닫습니다. 화면 방향 복원을 먼저
    // 기다리면 iOS의 회전 Future가 지연될 때 이미 퇴장한 게임 화면에 갇힐 수
    // 있습니다. 세로 복원은 dispose와 상위 대기 화면이 비동기로 처리합니다.
    if (!mounted) return true;
    Navigator.of(context).pop(true);
    return true;
  }

  @override
  void dispose() {
    _resultDialogGeneration += 1;
    _sessionSubscription?.close();
    //=======================플랫폼 세로 화면 복원==============================
    unawaited(AppOrientation.lockPlatformPortrait());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final args = _sessionArgs;
    if (args != null) ref.watch(liarsPokerPhoneSessionProvider(args));
    final controller = args == null
        ? null
        : ref.read(liarsPokerPhoneSessionProvider(args).notifier);
    _controller = controller;
    if (controller == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _initializationError ?? GameFlowCopy.gameOpenFailed,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 17),
            ),
          ),
        ),
      );
    }

    //=======================게임 진입==============================
    // 별도 로딩 화면 없이, 태블릿에서 테이블이 확대되는 순간과 맞춰 매트가
    // 풀리며 게임 배경이 드러납니다. 서버 데이터는 그 뒤에서 채워지고,
    // 준비되기 전까지는 배경만 보여 연출이 끊기지 않습니다.
    //
    // 첫 진입에만 적용하는 빗장입니다. isEntryDataReady는 라운드마다 분배
    // 단계에서 다시 false가 되므로, 그대로 쓰면 게임 도중에도 화면이 배경만
    // 남고 하위 화면이 사라집니다.
    _hasEnteredGame |= controller.isEntryDataReady;

    return GameEntryUnroll(
      child: Stack(
        fit: StackFit.expand,
        children: [
          _hasEnteredGame
              ? _buildGameContent(controller)
              : const _PhoneGameBackground(),
          GameInterruptionLayer(
            interruption: controller.interruption,
            currentUid: FirebaseAuth.instance.currentUser?.uid ?? '',
            isSubmitting: controller.isCommandInFlight,
            onVote: () async {
              await controller.voteToContinueInterruption();
            },
            onExpired: controller.expireInterruption,
          ),
        ],
      ),
    );
  }

  Widget _buildGameContent(LiarsPokerPhoneController controller) {
    final isAlive = !controller.isEliminated;

    //=======================휴대폰 결과 배경==============================
    // 승리 결과를 발표할 때는 게임 중 손패·상단바·턴 정보·관전 요소를 모두
    // 제거하고 게임 배경 위에 결과 다이얼로그만 표시합니다.
    if (controller.isNaturalResult && !controller.isPenaltyResultVisible) {
      return const _PhoneGameBackground();
    }

    // 가드 클로즈: 살아있을 때 (게임 진행 중) 화면 우선 반환
    //
    // 나가기 처리 중(_isLeavingRoom)에는 서버가 플레이어 상태를 'eliminated'로
    // 바꾸더라도 관전 화면으로 전환하지 않습니다. 그렇지 않으면 이 화면이
    // PhoneSpectator로 바뀌면서 나가기 모달·pop 로직을 쥐고 있던
    // LiarsPokerPhoneGameScreen이 사라져, 실제로는 방을 나갔는데도 화면 전환 없이
    // 관전 화면에 머무르는 문제가 있었습니다.
    if (isAlive || controller.showPenaltyHandOverlay || _isLeavingRoom) {
      return RepaintBoundary(
        child: LiarsPokerPhoneGameScreen(
          controller: controller,
          onExitRoom: _leaveRoom,
        ),
      );
    }

    // 관전 모드: 죽은 상태 (isAlive == false)
    final survivors = controller.players.values
        .where((p) => p.status != 'eliminated')
        .toList();

    final survivorPlayers = survivors
        .map(
          (p) => PlayerLayoutPlayer(
            uid: p.uid,
            nickname: p.nickname,
            profileImageUrl: p.profileImageUrl, // 실제 프로필 이미지 연결
            seatIndex: 0,
          ),
        )
        .toList();

    return PhoneSpectator(players: survivorPlayers);
  }
}

/// 결과 다이얼로그 뒤에 다른 게임 요소가 남지 않게 하는 전용 배경입니다.
class _PhoneGameBackground extends StatelessWidget {
  const _PhoneGameBackground();

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final background = isLandscape
        ? Assets.games.liarsPoker.images.background.background
        : Assets.games.liarsPoker.images.background.backgroundPhone;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox.expand(
        child: background.image(
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}
