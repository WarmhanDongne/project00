// [game_interruption_layer.dart] 는 여러 게임이 함께 사용하는 게임 화면에서 반복 사용하는 공통 UI를 구성하는 파일이다.
//
// - [Package] : 게임 공통 기반
// - [RecoveryWidget] : 플레이어 이탈 중 재접속 대기와 계속 진행 선택을 표시함
//
// 즉, 같은 표시와 조작 방식을 여러 화면에서 재사용하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:game_kit/core/time/server_clock.dart';
import 'package:game_kit/game_flow/game_flow_copy.dart';
import 'package:game_kit/mosi_ui/mosi_connection.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:game_kit/recovery/models/game_interruption.dart';

// ============================================================

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
    this.failureMessage,
    this.isSubmitting = false,
    this.scrimColor = const Color(0xE8000000),
  });

  final GameInterruption? interruption;
  final String currentUid;
  final GameInterruptionPresentation presentation;
  final Future<void> Function()? onVote;

  /// 태블릿 진행자가 중단된 참가자를 제외하고 게임을 계속합니다.
  ///
  /// [onFinishNow]와 같은 `Future<bool>` 모양입니다. 컨트롤러가 실패를 예외가
  /// 아니라 false로 알리므로(`_run`·`_runMenuCommand` 모두 catch합니다), 반환값을
  /// 받지 않으면 실패를 감지할 방법이 없습니다.
  final Future<bool> Function()? onContinue;

  /// 남은 인원이 부족해 계속할 수 없을 때 게임을 즉시 정상 종료합니다.
  ///
  /// [onExpired]와 같은 `Future<bool>` 모양이라 컨트롤러 메서드를 그대로 넘길
  /// 수 있습니다. 성공(true)이면 서버가 게임을 끝내며 화면이 곧 닫히고,
  /// 실패(false)면 버튼을 다시 켜 마감 뒤 자동 만료가 이어받게 합니다.
  final Future<bool> Function()? onFinishNow;
  final Future<bool> Function()? onExpired;

  /// 즉시 종료 또는 제외하고 계속하기가 실패했을 때 레이어 안에 보여 줄 문구입니다.
  ///
  /// 이 레이어는 `Positioned.fill` + scrim으로 화면 전체를 덮으므로, 그 아래에
  /// 그린 오류 표시는 사용자에게 보이지 않습니다. 실패를 알리려면 레이어 안에서
  /// 그려야 합니다.
  ///
  /// null이면 실패해도 아무것도 표시하지 않습니다. 화면이 이미 다른 방법으로
  /// 알리고 있으면(라이어스 포커 태블릿의 SnackBar) 넘기지 마세요.
  final String? failureMessage;

  final bool isSubmitting;

  /// 예전 반투명 가림막 색입니다. 시안(연결 끊김)은 불투명 남색 장면이라
  /// 지금은 쓰지 않지만, 부르는 쪽 호환을 위해 남겨 둡니다.
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

  /// 제외하고 계속하기 요청이 서버로 가 있는 중입니다.
  bool _isContinuing = false;

  /// 이 중단에서 마지막으로 보낸 요청이 실패했습니다.
  ///
  /// 실패 문구를 화면 전체가 아니라 이 레이어 안에서 보여 주기 위한 상태입니다.
  /// 다음 시도를 시작할 때와 중단이 바뀔 때 지웁니다.
  bool _actionFailed = false;

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
      _isContinuing = false;
      _actionFailed = false;
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
    setState(() {
      _isFinishingNow = true;
      _actionFailed = false;
    });
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
        _actionFailed = true;
      });
    }
  }

  /// 태블릿 진행자의 `제외하고 계속하기`입니다.
  ///
  /// [_finishNow]와 같은 이유로 실패를 레이어 안에서 알립니다. 성공하면 서버가
  /// 중단을 지우며 이 위젯이 사라지므로 잠금을 유지합니다.
  Future<void> _continue() async {
    if (_isContinuing) return;
    final handler = widget.onContinue;
    if (handler == null) return;
    setState(() {
      _isContinuing = true;
      _actionFailed = false;
    });
    var succeeded = false;
    try {
      succeeded = await handler();
    } catch (_) {
      succeeded = false;
    }
    if (!mounted) return;
    if (!succeeded) {
      setState(() {
        _isContinuing = false;
        _actionFailed = true;
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
    final nickname = interruption.playerNickname;
    final title = isDisconnected
        ? '$nickname 님의 연결이 끊겼어요'
        : '$nickname 님이 게임에서 나갔어요';
    final description = !interruption.canContinue
        ? '남은 인원이 부족해 게임을 계속할 수 없어요.'
        : isTabletController && isDisconnected
        ? '$nickname 님을 빼고 게임을 계속할까요?\n시간 안에 돌아오면 그대로 이어져요.'
        : '$nickname 님을 빼고 게임을 계속할까요?';
    final total = interruption.deadlineAt - interruption.startedAt;
    final remainingMs = ServerClock.remainingUntil(
      interruption.deadlineAt,
    ).inMilliseconds;

    // ---------------------------------------------------------
    // 버튼 영역은 presentation이 아니라 canContinue로 **먼저** 갈립니다.
    // 계속할 수 없는 중단은 휴대폰·태블릿이 할 수 있는 일이 같기
    // 때문입니다(종료뿐).
    //
    // ⚠️ 순서를 바꾸지 마세요. 아래 태블릿 분기에서 canContinue 검사를
    // 생략할 수 있는 근거가 "이 분기가 먼저 걸러진다"는 사실입니다.
    // ---------------------------------------------------------
    Widget? status;
    Widget? confirm;
    String? footnote;
    final actions = <Widget>[];
    if (!interruption.canContinue) {
      if (_isConfirmingFinish) {
        final isSubmitting = widget.isSubmitting || _isFinishingNow;
        confirm = Text(
          GameFlowCopy.interruptionFinishNowConfirm(
            nickname,
            _remainingSeconds,
          ),
          style: MosiFonts.sans(
            size: 15,
            weight: FontWeight.w700,
            color: MosiColors.navy,
            height: 1.5,
          ),
        );
        actions
          ..add(
            MosiConnectionButton(
              label: GameFlowCopy.interruptionFinishNowCancel,
              onPressed: isSubmitting
                  ? null
                  : () => setState(() => _isConfirmingFinish = false),
            ),
          )
          ..add(
            MosiConnectionButton(
              label: GameFlowCopy.interruptionFinishNowAccept,
              primary: true,
              loading: _isFinishingNow,
              onPressed: isSubmitting ? null : () => unawaited(_finishNow()),
            ),
          );
      } else {
        actions.add(
          MosiConnectionButton(
            label: GameFlowCopy.interruptionFinishNow,
            primary: true,
            onPressed:
                widget.onFinishNow == null ||
                    widget.isSubmitting ||
                    _isFinishingNow
                ? null
                // 0초가 지난 뒤에도 활성으로 둡니다. 자동 만료가 계속
                // 실패하는 상황에서 유일한 탈출구입니다.
                : () => setState(() => _isConfirmingFinish = true),
          ),
        );
      }
    } else if (isTabletController) {
      status = const MosiConnectionStatus(
        text: '진행자는 투표 없이 바로 정할 수 있어요',
        icon: Icons.info_outline_rounded,
      );
      actions.add(
        MosiConnectionButton(
          label: '제외하고 계속하기',
          primary: true,
          loading: _isContinuing,
          onPressed:
              widget.isSubmitting || _isContinuing || widget.onContinue == null
              ? null
              : () => unawaited(_continue()),
        ),
      );
    } else {
      status = MosiConnectionStatus(
        text: canVote
            ? '제외 동의 ${interruption.voteCount} / ${interruption.requiredVotes}'
            : '다른 참가자의 투표를 기다리고 있어요',
        dots: !canVote,
        color: MosiColors.ink2,
        trailing: canVote ? _VoteMarks(interruption: interruption) : null,
      );
      if (canVote) {
        actions.add(
          MosiConnectionButton(
            label: hasVoted ? '동의 완료' : '제외하고 계속하기',
            primary: true,
            onPressed: hasVoted || widget.isSubmitting || widget.onVote == null
                ? null
                : () => unawaited(widget.onVote!()),
          ),
        );
      }
      if (isDisconnected) footnote = '$nickname 님이 돌아오면 그대로 이어져요';
    }

    return Positioned.fill(
      child: MosiConnectionLayout(
        semanticLabel: title,
        background: MosiColors.navy,
        scene: MosiPlayerWaitScene(
          characterId: interruption.playerCharacterId,
          seconds: _remainingSeconds,
          progress: total <= 0 ? 0 : remainingMs / total,
          badge: isDisconnected ? '연결 끊김' : '나감',
          caption: isDisconnected ? '돌아오기를 기다리는 중' : '결정까지 남은 시간',
        ),
        tag: isTabletController ? '참가자 연결 · 진행자' : '참가자 연결',
        tagColor: mosiConnectionPink,
        title: title,
        body: description,
        status: status,
        // 실패 안내는 버튼 분기 **밖**에 둡니다. 즉시 종료와 제외하고 계속하기가
        // 같은 자리에 같은 모양으로 알려야 하고, 분기 안에 넣으면 둘 중 하나만
        // 표시됩니다.
        extra:
            confirm == null && !(_actionFailed && widget.failureMessage != null)
            ? null
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ?confirm,
                  if (confirm != null &&
                      _actionFailed &&
                      widget.failureMessage != null)
                    const SizedBox(height: 12),
                  if (_actionFailed && widget.failureMessage != null)
                    _InterruptionFailureNotice(message: widget.failureMessage!),
                ],
              ),
        actions: actions,
        footnote: footnote,
      ),
    );
  }
}

/// 제외 동의를 보낸 사람 수만큼 채워지는 표시입니다.
///
/// 투표자 얼굴 정보는 중단 상태에 없어 동그라미로만 보여 줍니다.
class _VoteMarks extends StatelessWidget {
  const _VoteMarks({required this.interruption});

  final GameInterruption interruption;

  @override
  Widget build(BuildContext context) {
    final count = interruption.requiredVotes.clamp(0, 6);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          i < interruption.voteCount
              ? Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: MosiColors.violet,
                    shape: BoxShape.circle,
                    border: Border.all(color: MosiColors.ink, width: 2),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: MosiColors.white,
                  ),
                )
              : const SizedBox(
                  width: 26,
                  height: 26,
                  child: CustomPaint(painter: _DashedRingPainter()),
                ),
        ],
      ],
    );
  }
}

class _DashedRingPainter extends CustomPainter {
  const _DashedRingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = MosiColors.muted
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final rect = (Offset.zero & size).deflate(1);
    const dashes = 12;
    const sweep = 3.141592653589793 * 2 / dashes;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(rect, i * sweep, sweep * .55, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 중단 레이어 안에서 실패를 알리는 문구입니다.
///
/// 이 레이어는 화면 전체를 덮으므로 SnackBar 외에는 바깥에서 알릴 방법이
/// 없고, SnackBar는 몇 초 뒤 사라져 무엇이 실패했는지 남지 않습니다. 다시
/// 시도할 수 있는 버튼 바로 위에 남겨 두는 편이 읽힙니다.
///
/// 즉시 종료 확인도 showDialog로 만들지 않고 이 레이어 안에서 상태만 바꿉니다.
/// 게임 라우트 위에 다이얼로그를 쌓으면 종료가 반영될 때 화면이 스스로 부르는
/// `maybePop`이 다이얼로그만 닫아 게임 화면에 갇힙니다(`game_route_exit.dart`).
class _InterruptionFailureNotice extends StatelessWidget {
  const _InterruptionFailureNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFBE3E6),
          border: Border.all(color: MosiColors.red, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          message,
          style: MosiFonts.sans(
            size: 14,
            weight: FontWeight.w700,
            color: const Color(0xFFB02A3C),
            height: 1.4,
          ),
        ),
      ),
    );
  }
}
