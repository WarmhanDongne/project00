import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:project00/core/layout/app_orientation.dart';
import 'package:project00/games/liars_poker/loading/liars_poker_loading.dart';
import 'package:project00/games/liars_poker/providers/liars_poker_phone_session_provider.dart';
import 'package:project00/games/liars_poker/providers/liars_poker_phone_state.dart';
import 'package:project00/games/liars_poker/screens/phone/phone_game_controller.dart';
import 'package:project00/games/liars_poker/screens/phone/phone_game_screen.dart';
import 'package:project00/games/liars_poker/widgets/phone/result.dart';
import 'package:project00/games/liars_poker/widgets/phone/spectator.dart';
import 'package:project00/games/liars_poker/services/liars_poker_service.dart';
import 'package:project00/games/liars_poker/models/player_layout_model.dart';
import 'package:project00/games/shared/widgets/game_loading_screen.dart';
import 'package:project00/gen/assets.gen.dart';

/// 기기 방향과 관계없이 하나의 Firebase 구독 컨트롤러를 유지합니다.
class PhoneGame extends ConsumerStatefulWidget {
  const PhoneGame({
    super.key,
    required this.roomCode,
    required this.gameService,
    required this.onExitRoom,
  });

  final String roomCode;
  final LiarsPokerService gameService;
  final Future<bool> Function() onExitRoom;

  @override
  ConsumerState<PhoneGame> createState() => _PhoneGameState();
}

class _PhoneGameState extends ConsumerState<PhoneGame> {
  PhoneGameController? _controller;
  LiarsPokerPhoneSessionArgs? _sessionArgs;
  ProviderSubscription<LiarsPokerPhoneState>? _sessionSubscription;
  String? _initializationError;
  bool _hasScheduledGameExit = false;
  bool _isLeavingRoom = false;
  bool _isResultDialogOpen = false;
  String? _shownWinnerUid;
  BuildContext? _resultDialogContext;
  int _resultDialogGeneration = 0;

  @override
  void initState() {
    super.initState();
    //=======================세로·가로 화면 허용==============================
    // Final Call에서 사용한 가로 고정이 남아 있더라도 Liar's Poker에
    // 진입하는 즉시 세로와 가로 회전을 모두 다시 허용합니다.
    unawaited(AppOrientation.allowLiarsPokerRotation());
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _initializationError = '게임에 참여하려면 사용자 인증이 필요합니다.';
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

  void _showResultDialog(PhoneGameController controller) {
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
          return PhoneResultDialog(
            nickname: winner.nickname,
            profileImageUrl: winner.profileImageUrl,
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
    if (!left) _isLeavingRoom = false;
    return left;
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
              _initializationError ?? '게임을 초기화하지 못했습니다.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 17),
            ),
          ),
        ),
      );
    }

    //=======================게임 진입 로딩 화면==============================
    // 서버의 첫 공개 상태와 개인 손패, 게임 이미지를 모두 준비합니다. 데이터가
    // 먼저 도착해도 공용 로딩 화면은 최소 2초간 유지된 뒤 게임을 표시합니다.
    return GameLoadingScreen(
      background: Assets
          .games
          .liarsPoker
          .images
          .background
          .backgroundLoadingPhone
          .provider(),
      tips: liarsPokerLoadingTips,
      prepare: (loadingContext) async {
        await controller.waitForInitialData();
        if (!loadingContext.mounted) return;
        await preloadLiarsPokerAssets(
          loadingContext,
          isPhone: true,
          profileImageUrls: controller.players.values.map(
            (player) => player.profileImageUrl,
          ),
        );
      },
      gameBuilder: (_) => _buildGameContent(controller),
    );
  }

  Widget _buildGameContent(PhoneGameController controller) {
    final isAlive = !controller.isEliminated;

    //=======================휴대폰 결과 배경==============================
    // 승리 결과를 발표할 때는 게임 중 손패·상단바·턴 정보·관전 요소를 모두
    // 제거하고 게임 배경 위에 결과 다이얼로그만 표시합니다.
    if (controller.isNaturalResult && !controller.isPenaltyResultVisible) {
      return const _PhoneResultBackground();
    }

    // 가드 클로즈: 살아있을 때 (게임 진행 중) 화면 우선 반환
    if (isAlive || controller.showPenaltyHandOverlay) {
      return RepaintBoundary(
        child: PhoneGameScreen(controller: controller, onExitRoom: _leaveRoom),
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
class _PhoneResultBackground extends StatelessWidget {
  const _PhoneResultBackground();

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
