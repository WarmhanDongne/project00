import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:project00/core/layout/app_orientation.dart';
import 'package:project00/core/layout/app_system_ui.dart';
import 'package:project00/games/liars_poker/liars_poker_flow_config.dart';
import 'package:project00/games/liars_poker/loading/liars_poker_loading.dart';
import 'package:project00/games/liars_poker/providers/liars_poker_session_provider.dart';
import 'package:project00/games/liars_poker/providers/liars_poker_game_state.dart';
import 'package:project00/games/liars_poker/controllers/liars_poker_controller.dart';
import 'package:project00/games/liars_poker/screens/phone/phone_game_screen.dart';
import 'package:project00/games/shared/widgets/phone_result_dialog.dart';
import 'package:project00/games/liars_poker/widgets/phone/spectator.dart';
import 'package:project00/games/liars_poker/services/liars_poker_service.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';
import 'package:project00/games/shared/animations/game_entry_unroll.dart';
import 'package:project00/games/shared/game_feedback.dart';
import 'package:project00/games/shared/game_flow/game_flow_copy.dart';
import 'package:project00/games/shared/player_layouts/player_layout_model.dart';
import 'package:project00/gen/assets.gen.dart';
import 'package:project00/games/shared/widgets/game_connecting_overlay.dart';
import 'package:project00/games/shared/widgets/game_interruption_layer.dart';
import 'package:project00/core/assets/game_image.dart';

/// 기기 방향과 관계없이 하나의 Firebase 구독 컨트롤러를 유지합니다.
class LiarsPokerPhoneGame extends ConsumerStatefulWidget {
  const LiarsPokerPhoneGame({
    super.key,
    required this.roomCode,
    required this.provider,
    required this.gameService,
    required this.onExitRoom,
  });

  final String roomCode;
  final RoomProvider provider;
  final LiarsPokerService gameService;
  final Future<bool> Function() onExitRoom;

  @override
  ConsumerState<LiarsPokerPhoneGame> createState() =>
      _LiarsPokerPhoneGameState();
}

class _LiarsPokerPhoneGameState extends ConsumerState<LiarsPokerPhoneGame> {
  LiarsPokerController? _controller;
  LiarsPokerSessionArgs? _sessionArgs;
  ProviderSubscription<LiarsPokerGameState>? _sessionSubscription;
  String? _initializationError;
  bool _hasScheduledGameExit = false;
  bool _isLeavingRoom = false;
  bool _hasEnteredGame = false;
  bool _isResultDialogOpen = false;
  String? _shownWinnerUid;
  BuildContext? _resultDialogContext;
  int _resultDialogGeneration = 0;
  bool _wasMyTurn = false;
  bool _wasPenaltyPhase = false;
  String? _previousTurnUid;

  @override
  void initState() {
    super.initState();
    // ========================================================================
    // 게임 진입 환경
    // ========================================================================
    // 게임 중 시스템 UI를 숨기되 Liar's Poker 휴대폰은 가로·세로를 모두
    // 허용합니다. 이 화면은 방향 전환 중 State를 보존하기 위해 자체 슬롯
    // 레이아웃을 사용하며 PhoneGameShell로 강제 이전하지 않습니다.
    unawaited(AppSystemUi.enterGameFullscreen());
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

    final args = LiarsPokerSessionArgs(
      roomCode: widget.roomCode,
      uid: uid,
      service: widget.gameService,
      watchPrivateHand: true,
    );
    _sessionArgs = args;
    final provider = liarsPokerSessionProvider(args);
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
    try {
      // 첫 스냅샷이 오지 않거나 구독이 에러로 끝나도 사전 로딩 대기가
      // unhandled exception이나 영구 대기로 남지 않게 합니다. 실제 화면
      // 전환은 컨트롤러 상태 구독이 계속 담당합니다.
      await controller.waitForInitialData().timeout(
        const Duration(seconds: 12),
      );
    } catch (_) {
      // 프로필 이미지 없이도 나머지 에셋은 준비할 수 있습니다.
    }
    if (!mounted) return;
    await preloadLiarsPokerAssets(
      context,
      isPhone: true,
      characterIds: controller.players.values.map(
        (player) => player.characterId,
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

    _notifyTurnAndLiarFeedback(controller);

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

  /// 내 턴 시작과 다른 플레이어의 LIAR 선언을 진동으로 알립니다.
  ///
  /// 컨트롤러 알림은 판정 문구 타이머 같은 로컬 커밋에도 오므로, 직전 값과의
  /// 전이를 비교해 각각 한 번만 울립니다. penalty 전환 직전의 turnUid가 LIAR를
  /// 외친 플레이어이며, 선언한 본인은 버튼을 누를 때 이미 declare 진동을
  /// 받았으므로 제외합니다.
  void _notifyTurnAndLiarFeedback(LiarsPokerController controller) {
    final wasMyTurn = _wasMyTurn;
    final wasPenaltyPhase = _wasPenaltyPhase;
    final previousTurnUid = _previousTurnUid;
    _wasMyTurn = controller.isMyTurn;
    _wasPenaltyPhase = controller.phase == 'penalty';
    _previousTurnUid = controller.turnUid;

    if (controller.isFinished) return;

    // 내 턴이 시작되면 화면을 보고 있지 않아도 알 수 있게 진동을 울립니다.
    if (!wasMyTurn && controller.isMyTurn) {
      GameFeedback.alert();
      return;
    }

    if (!wasPenaltyPhase &&
        controller.phase == 'penalty' &&
        previousTurnUid != null &&
        previousTurnUid != controller.uid) {
      GameFeedback.alert();
    }
  }

  void _showResultDialog(LiarsPokerController controller) {
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
              characterId: winner.characterId,
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

    // ---------------------------------------------------------------------------
    // 명시적 퇴장 후 화면 전환
    // ---------------------------------------------------------------------------
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
    // ---------------------------------------------------------------------------
    // 게임 종료 후 플랫폼 화면 정책 복원
    // ---------------------------------------------------------------------------
    unawaited(AppOrientation.restorePlatform());
    unawaited(AppSystemUi.showPlatformSystemBars());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final args = _sessionArgs;
    if (args != null) ref.watch(liarsPokerSessionProvider(args));
    final controller = args == null
        ? null
        : ref.read(liarsPokerSessionProvider(args).notifier);
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

    // ============================================================================
    // 1. 게임 진입 및 서버 데이터 연결
    // ============================================================================
    //
    // 시점/status:
    // - 첫 game/public과 개인 손패가 준비되기 전
    //
    // 화면/문구/연출:
    // - GameEntryUnroll 아래에 게임 배경만 표시
    // - 별도 준비 문구, Scrim, 로딩 스피너는 표시하지 않음
    // - 매트 연출 시간은 GameEntryUnroll의 공용 설정을 사용
    //
    // 입력/전환:
    // - 게임 UI가 없어 입력할 수 없음
    // - 서버 데이터가 한 번 준비되면 _hasEnteredGame을 유지함
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
          // 서버 상태 갱신마다 화면 전체를 다시 전환하면 관전자 화면이 계속
          // 번쩍입니다. 일반 게임 단계는 모두 같은 key를 쓰고 관전 화면만 다른
          // key를 사용하므로, 관전 화면이 등장하거나 사라질 때만 한 번 페이드합니다.
          AnimatedSwitcher(
            duration: LiarsPokerFlowTiming.phoneSpectatorTransition,
            reverseDuration: LiarsPokerFlowTiming.phoneSpectatorTransition,
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            layoutBuilder: (currentChild, previousChildren) => Stack(
              fit: StackFit.expand,
              children: [...previousChildren, ?currentChild],
            ),
            // 양쪽 화면을 동시에 반투명하게 만들면 중간 프레임에서 뒤의 검은
            // 바탕이 비쳐 화면이 한 번 어두워집니다. 이전 화면은 완전히 유지하고
            // 새 화면만 그 위에서 나타나게 해 밝기 변화 없는 전환을 만듭니다.
            transitionBuilder: _buildSpectatorTransition,
            child: _hasEnteredGame
                ? _buildGameContent(controller)
                : const KeyedSubtree(
                    key: ValueKey('liars-poker-game'),
                    child: _PhoneGameBackground(),
                  ),
          ),
          GameInterruptionLayer(
            interruption: controller.interruption,
            currentUid: FirebaseAuth.instance.currentUser?.uid ?? '',
            isSubmitting: controller.isCommandInFlight,
            failureMessage: controller.errorMessage,
            onVote: () async {
              await controller.voteToContinueInterruption();
            },
            onFinishNow: controller.finishInterruptedGameNow,
            onExpired: controller.expireInterruption,
          ),
          // 첫 서버 상태가 오래 오지 않으면 배경만 남는 화면 대신 대기 안내와
          // 나가기 버튼을 표시해 영구 대기를 막습니다.
          GameConnectingOverlay(
            isWaiting: !_hasEnteredGame,
            onExit: () => unawaited(_leaveRoom()),
          ),
        ],
      ),
    );
  }

  Widget _buildGameContent(LiarsPokerController controller) {
    final isAlive = !controller.isEliminated;

    // ============================================================================
    // 6. 최종 결과
    // ============================================================================
    //
    // 정상 승자가 확정되고 마지막 벌칙 결과까지 끝나면 게임 요소를 제거하고
    // 공용 PhoneResultDialog만 표시합니다. 결과 닫기/다시하기는 서버 상태를
    // 기다리며, 이 배경 자체는 게임 상태를 변경하지 않습니다.
    // 승리 결과를 발표할 때는 게임 중 손패·상단바·턴 정보·관전 요소를 모두
    // 제거하고 게임 배경 위에 결과 다이얼로그만 표시합니다.
    if (controller.isNaturalResult && !controller.isPenaltyResultVisible) {
      return const KeyedSubtree(
        key: ValueKey('liars-poker-game'),
        child: _PhoneGameBackground(),
      );
    }

    // ============================================================================
    // 2~5. 준비 → 카드 분배 → 플레이 → 판정/벌칙
    // ============================================================================
    //
    // 상세 단계는 LiarsPokerPhoneGameScreen이 담당합니다.
    // - 서버 dealing: ROUND N 및 손패 수신/공개 연출
    // - 서버 playing: 카드 선택·제출·LIAR 입력
    // - lastCardChallenge: 잔여카드 보유자가 정확히 한 명일 때 제출을 잠그고
    //   LIAR/FOLD만 허용
    // - penalty/result 표시: 진실/거짓 판정과 벌칙 결과
    //
    // 안내 문구는 하위 화면의 공용 GameAnnouncementLayer 한 슬롯에서 표시하고,
    // 연출 완료는 서버 판정과 분리합니다.
    //
    // 다음 가드는 살아있는 플레이어의 진행 화면을 우선 반환합니다.
    //
    // 나가기 처리 중(_isLeavingRoom)에는 서버가 플레이어 상태를 'eliminated'로
    // 바꾸더라도 관전 화면으로 전환하지 않습니다. 그렇지 않으면 이 화면이
    // PhoneSpectator로 바뀌면서 나가기 모달·pop 로직을 쥐고 있던
    // LiarsPokerPhoneGameScreen이 사라져, 실제로는 방을 나갔는데도 화면 전환 없이
    // 관전 화면에 머무르는 문제가 있었습니다.
    if (isAlive || controller.showPenaltyHandOverlay || _isLeavingRoom) {
      return KeyedSubtree(
        key: const ValueKey('liars-poker-game'),
        child: RepaintBoundary(
          child: LiarsPokerPhoneGameScreen(
            controller: controller,
            provider: widget.provider,
            onExitRoom: _leaveRoom,
            // 탈락자가 진실/거짓 판정과 벌칙 결과를 보는 동안에도 나갈 수
            // 있도록 관전자용 공용 상단바를 유지합니다.
            showSpectatorTopBar: !isAlive,
          ),
        ),
      );
    }

    // ============================================================================
    // 5. 탈락 후 관전
    // ============================================================================
    // 서버에서 eliminated가 확정되고 벌칙 결과 표시도 끝난 뒤 관전 화면으로
    // 전환합니다. 관전자는 게임 명령을 보낼 수 없고 생존자 상태만 구독합니다.
    final survivors = controller.players.values
        .where((p) => p.status != 'eliminated')
        .toList();

    final survivorPlayers = survivors
        .map(
          (p) => PlayerLayoutPlayer(
            uid: p.uid,
            nickname: p.nickname,
            characterId: p.characterId,
            seatIndex: 0,
          ),
        )
        .toList();

    return PhoneSpectator(
      key: const ValueKey('liars-poker-spectator'),
      players: survivorPlayers,
      table: controller.table,
      provider: widget.provider,
      onExitRoom: _leaveRoom,
    );
  }

  Widget _buildSpectatorTransition(Widget child, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, transitionChild) {
        final isOutgoing = animation.status == AnimationStatus.reverse;
        return Opacity(
          opacity: isOutgoing ? 1 : animation.value,
          child: transitionChild,
        );
      },
    );
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
        ? Assets.games.liarsPoker.images.background.background.game
        : Assets.games.liarsPoker.images.background.backgroundPhone.game;

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
