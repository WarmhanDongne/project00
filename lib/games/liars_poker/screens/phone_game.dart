import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:project00/games/liars_poker/screens/phone/phone_game_controller.dart';
import 'package:project00/games/liars_poker/screens/phone/phone_game_screen.dart';
import 'package:project00/games/liars_poker/widgets/phone/result.dart';
import 'package:project00/games/liars_poker/widgets/phone/spectator.dart';
import 'package:project00/games/liars_poker/services/liars_poker_service.dart';
import 'package:project00/games/liars_poker/models/player_layout_model.dart';

/// 기기 방향과 관계없이 하나의 Firebase 구독 컨트롤러를 유지합니다.
class PhoneGame extends StatefulWidget {
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
  State<PhoneGame> createState() => _PhoneGameState();
}

class _PhoneGameState extends State<PhoneGame> {
  PhoneGameController? _controller;
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
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _initializationError = '게임에 참여하려면 사용자 인증이 필요합니다.';
      return;
    }

    final controller = PhoneGameController(
      roomCode: widget.roomCode,
      uid: uid,
      gameService: widget.gameService,
    );
    _controller = controller;
    controller.addListener(_handleGameStateChanged);
    controller.initialize();
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
      setState(() {});
      return;
    }

    // 정상 승리는 화면을 닫지 않고 결과 다이얼로그를 유지합니다. 태블릿의
    // 다시하기 상태를 같은 RTDB 구독으로 받아 즉시 새 게임으로 전환합니다.
    if (controller.isNaturalResult) {
      setState(() {});
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
    _controller
      ?..removeListener(_handleGameStateChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
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

    final isAlive = !controller.isEliminated;

    // 가드 클로즈: 살아있을 때 (게임 진행 중) 화면 우선 반환
    if (isAlive || controller.showPenaltyHandOverlay) {
      return Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: PhoneGameScreen(
              controller: controller,
              onExitRoom: _leaveRoom,
            ),
          ),
          if (controller.isCommandInFlight) const _CommandLoadingIndicator(),
        ],
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

/// 서버 재요청 중 게임 화면을 가리지 않고 연결 상태만 작게 표시합니다.
class _CommandLoadingIndicator extends StatelessWidget {
  const _CommandLoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: IgnorePointer(
          child: RepaintBoundary(
            child: Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xB818211C),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0x338CA695)),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.cloud_sync_outlined,
                        size: 15,
                        color: Color(0xFFD8E2DB),
                      ),
                      SizedBox(width: 8),
                      Text(
                        '연결 확인 중',
                        style: TextStyle(
                          color: Color(0xFFD8E2DB),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
