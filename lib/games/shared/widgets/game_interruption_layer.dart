import 'dart:async';

import 'package:flutter/material.dart';
import 'package:project00/platform/home/room/models/room_character.dart';
import 'package:project00/core/time/server_clock.dart';
import 'package:project00/games/shared/game_flow/game_flow_copy.dart';
import 'package:project00/games/shared/game_flow/game_interruption.dart';

enum GameInterruptionPresentation { player, tabletController }

/// 연결 끊김·퇴장 시 모든 게임이 공유하는 전체 화면 중단 및 투표 레이어입니다.
///
/// 문구 전용 [GameAnnouncementLayer]와 달리 이 레이어는 게임 조작을 멈추고
/// 휴대폰 투표 또는 태블릿의 제외 진행 버튼만 입력받습니다.
class GameInterruptionLayer extends StatefulWidget {
  const GameInterruptionLayer({
    super.key,
    required this.interruption,
    required this.currentUid,
    this.presentation = GameInterruptionPresentation.player,
    this.onVote,
    this.onContinue,
    this.onFinishNow,
    this.onExpired,
    this.isSubmitting = false,
    this.scrimColor = const Color(0xE8000000),
  });

  final GameInterruption? interruption;
  final String currentUid;
  final GameInterruptionPresentation presentation;
  final Future<void> Function()? onVote;
  final Future<void> Function()? onContinue;

  /// 남은 인원이 부족해 계속할 수 없을 때 게임을 즉시 정상 종료합니다.
  ///
  /// [onExpired]와 같은 `Future<bool>` 모양이라 컨트롤러 메서드를 그대로 넘길
  /// 수 있습니다. 성공(true)이면 서버가 게임을 끝내며 화면이 곧 닫히고,
  /// 실패(false)면 버튼을 다시 켜 마감 뒤 자동 만료가 이어받게 합니다.
  final Future<bool> Function()? onFinishNow;
  final Future<bool> Function()? onExpired;
  final bool isSubmitting;
  final Color scrimColor;

  @override
  State<GameInterruptionLayer> createState() => _GameInterruptionLayerState();
}

class _GameInterruptionLayerState extends State<GameInterruptionLayer> {
  Timer? _timer;
  int _remainingSeconds = 0;
  String? _expiredInterruptionId;

  /// 즉시 종료 확인 문구를 보여 주는 중입니다.
  bool _isConfirmingFinish = false;

  /// 즉시 종료 요청이 서버로 가 있는 중입니다.
  bool _isFinishingNow = false;

  @override
  void initState() {
    super.initState();
    _syncTimer();
  }

  @override
  void didUpdateWidget(GameInterruptionLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.interruption?.id != widget.interruption?.id) {
      _expiredInterruptionId = null;
      // 새 중단은 새 판단입니다. 여기서 되돌리지 않으면 앞선 중단에서 실패한
      // 요청 때문에 다음 중단의 버튼이 영구 비활성으로 남습니다.
      _isConfirmingFinish = false;
      _isFinishingNow = false;
      _syncTimer();
    }
  }

  void _syncTimer() {
    _timer?.cancel();
    final interruption = widget.interruption;
    if (interruption == null) {
      _remainingSeconds = 0;
      return;
    }
    _updateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateRemaining();
    });
  }

  void _updateRemaining() {
    final interruption = widget.interruption;
    if (interruption == null || !mounted) return;
    final milliseconds = ServerClock.remainingUntil(
      interruption.deadlineAt,
    ).inMilliseconds;
    final seconds = (milliseconds / 1000).ceil();
    if (_remainingSeconds != seconds) {
      setState(() => _remainingSeconds = seconds);
    }
    // 즉시 종료 요청이 날아가 있는 동안에는 자동 만료를 쏘지 않습니다. 같은
    // 최종 상태를 만드는 명령을 겹쳐 보내서 얻는 것이 없습니다. 실패하면
    // _finishNow가 잠금을 풀어 다음 tick의 만료가 이어받습니다.
    if (seconds == 0 &&
        !_isFinishingNow &&
        _expiredInterruptionId != interruption.id &&
        widget.onExpired != null) {
      _expiredInterruptionId = interruption.id;
      unawaited(_expire(interruption.id));
    }
  }

  Future<void> _expire(String interruptionId) async {
    var succeeded = false;
    try {
      succeeded = await widget.onExpired?.call() ?? false;
    } catch (_) {
      succeeded = false;
    }
    if (!succeeded && mounted && widget.interruption?.id == interruptionId) {
      // callable 자체의 재전송까지 모두 실패한 경우에도 다음 timer tick에서
      // 다시 시도해 0초 화면에 영구 정지하지 않게 합니다.
      _expiredInterruptionId = null;
    }
  }

  Future<void> _finishNow() async {
    if (_isFinishingNow) return;
    final handler = widget.onFinishNow;
    if (handler == null) return;
    setState(() => _isFinishingNow = true);
    var succeeded = false;
    try {
      succeeded = await handler();
    } catch (_) {
      succeeded = false;
    }
    if (!mounted) return;
    // 성공하면 서버가 게임을 끝내며 화면이 곧 닫히므로 잠금을 유지해 닫히는
    // 동안의 추가 탭을 막습니다. 실패하면 되돌려야 다시 누를 수 있고, 마감이
    // 지났다면 다음 tick의 자동 만료가 이어받습니다.
    if (!succeeded) {
      setState(() {
        _isFinishingNow = false;
        _isConfirmingFinish = false;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final interruption = widget.interruption;
    // 이 레이어는 Stack의 Positioned 자식이라는 전제로 쓰입니다. 중단이 없을 때
    // 맨 SizedBox를 돌려주면 Stack의 유일한 non-positioned 자식이 되어, 느슨한
    // 제약(StackFit.loose)에서는 Stack 전체가 0×0으로 줄어듭니다. 그러면 배경과
    // 게임 레이어가 통째로 그려지지 않아 화면이 검게 보입니다.
    if (interruption == null) {
      return const Positioned.fill(child: SizedBox.shrink());
    }
    final canVote = interruption.canVote(widget.currentUid);
    final hasVoted = interruption.hasVoted(widget.currentUid);
    final isTabletController =
        widget.presentation == GameInterruptionPresentation.tabletController;
    final isDisconnected =
        interruption.reason == GameInterruptionReason.disconnected;
    final title = isDisconnected
        ? '${interruption.playerNickname}와의 연결이 끊어졌습니다'
        : '${interruption.playerNickname}가 게임에서 나갔습니다.';
    final description = interruption.canContinue
        ? '해당 플레이어를 제외하고 게임을 계속할까요?'
        : '남은 인원이 부족해 게임을 계속할 수 없습니다.';

    return Positioned.fill(
      child: Material(
        color: widget.scrimColor,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PlayerAvatar(
                      characterId: interruption.playerCharacterId,
                      nickname: interruption.playerNickname,
                      size: isTabletController ? 116 : 96,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      '$_remainingSeconds초',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFE5E5E5),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        height: 1.45,
                      ),
                    ),
                    // ---------------------------------------------------------
                    // 버튼 영역은 presentation이 아니라 canContinue로 **먼저**
                    // 갈립니다. 계속할 수 없는 중단은 휴대폰·태블릿이 할 수
                    // 있는 일이 같기 때문입니다(종료뿐).
                    //
                    // ⚠️ 순서를 바꾸지 마세요. 아래 태블릿 분기에서
                    // canContinue 검사를 생략할 수 있는 근거가 "이 분기가
                    // 먼저 걸러진다"는 사실입니다.
                    // ---------------------------------------------------------
                    if (!interruption.canContinue) ...[
                      const SizedBox(height: 26),
                      if (_isConfirmingFinish)
                        _FinishNowConfirm(
                          message: GameFlowCopy.interruptionFinishNowConfirm(
                            interruption.playerNickname,
                            _remainingSeconds,
                          ),
                          isSubmitting: widget.isSubmitting || _isFinishingNow,
                          onCancel: () =>
                              setState(() => _isConfirmingFinish = false),
                          onAccept: () => unawaited(_finishNow()),
                        )
                      else
                        _InterruptionActionButton(
                          label: GameFlowCopy.interruptionFinishNow,
                          isEmphasized: isTabletController,
                          onPressed:
                              widget.onFinishNow == null ||
                                  widget.isSubmitting ||
                                  _isFinishingNow
                              ? null
                              // 0초가 지난 뒤에도 활성으로 둡니다. 자동 만료가
                              // 계속 실패하는 상황에서 유일한 탈출구입니다.
                              : () =>
                                    setState(() => _isConfirmingFinish = true),
                        ),
                    ] else if (isTabletController) ...[
                      const SizedBox(height: 26),
                      _InterruptionActionButton(
                        label: '제외하고 계속하기',
                        isEmphasized: true,
                        onPressed:
                            widget.isSubmitting || widget.onContinue == null
                            ? null
                            : () => unawaited(widget.onContinue!()),
                      ),
                    ] else ...[
                      const SizedBox(height: 8),
                      Text(
                        '동의 ${interruption.voteCount} / ${interruption.requiredVotes}',
                        style: const TextStyle(
                          color: Color(0xFFCECECE),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 26),
                      if (canVote)
                        _InterruptionActionButton(
                          label: hasVoted ? '동의 완료' : '제외하고 계속하기',
                          isEmphasized: false,
                          onPressed:
                              hasVoted ||
                                  widget.isSubmitting ||
                                  widget.onVote == null
                              ? null
                              : () => unawaited(widget.onVote!()),
                        )
                      else
                        const Text(
                          '다른 플레이어의 투표를 기다리고 있습니다.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFFCECECE)),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerAvatar extends StatelessWidget {
  const _PlayerAvatar({
    required this.characterId,
    required this.nickname,
    required this.size,
  });

  final String characterId;
  final String nickname;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x55FFFFFF)),
      ),
      child: Image.asset(
        roomCharacterAssetPath(characterId),
        fit: BoxFit.contain,
      ),
    );
  }
}

/// 중단 레이어의 흰 배경 액션 버튼입니다.
///
/// [isEmphasized]는 태블릿 진행자용 강조(그림자와 진한 비활성 색)입니다.
/// 기존 두 버튼의 차이가 elevation과 비활성 색뿐이라 하나로 묶었습니다.
class _InterruptionActionButton extends StatelessWidget {
  const _InterruptionActionButton({
    required this.label,
    required this.isEmphasized,
    required this.onPressed,
  });

  final String label;
  final bool isEmphasized;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        disabledBackgroundColor: isEmphasized
            ? const Color(0xFF777777)
            : const Color(0xFFAAAAAA),
        disabledForegroundColor: isEmphasized
            ? const Color(0xFFBBBBBB)
            : const Color(0xFF444444),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        elevation: isEmphasized ? 8 : 0,
        shadowColor: Colors.black,
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }
}

/// 즉시 종료 확인 문구와 취소·종료 버튼입니다.
///
/// ⚠️ **showDialog로 만들지 마세요.** 게임 라우트 위에 다이얼로그를 쌓으면
/// 종료가 반영될 때 화면이 스스로 부르는 `maybePop`이 다이얼로그만 닫아
/// 게임 화면에 갇힙니다(`game_route_exit.dart` 참고). 같은 레이어 안에서
/// 상태만 바꾸면 라우트가 쌓이지 않아 그 사고가 구조적으로 불가능합니다.
class _FinishNowConfirm extends StatelessWidget {
  const _FinishNowConfirm({
    required this.message,
    required this.isSubmitting,
    required this.onCancel,
    required this.onAccept,
  });

  final String message;
  final bool isSubmitting;
  final VoidCallback onCancel;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton(
              onPressed: isSubmitting ? null : onCancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                disabledForegroundColor: const Color(0xFF888888),
                side: const BorderSide(color: Color(0x55FFFFFF)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
              ),
              child: const Text(
                GameFlowCopy.interruptionFinishNowCancel,
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 12),
            _InterruptionActionButton(
              label: GameFlowCopy.interruptionFinishNowAccept,
              isEmphasized: true,
              onPressed: isSubmitting ? null : onAccept,
            ),
          ],
        ),
      ],
    );
  }
}
