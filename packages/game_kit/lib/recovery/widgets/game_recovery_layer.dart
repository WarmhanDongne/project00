import 'package:flutter/material.dart';
import 'package:game_kit/recovery/models/game_interruption.dart';
import 'package:game_kit/recovery/models/game_recovery_context.dart';
import 'package:game_kit/recovery/widgets/game_interruption_layer.dart';
import 'package:game_kit/recovery/widgets/game_request_notice.dart';

export 'package:game_kit/recovery/widgets/game_interruption_layer.dart'
    show GameInterruptionPresentation;

/// 초기 준비는 게임 화면을 유지하고, 복구 중단과 실패는 기존 안내로 표시합니다.
///
/// 각 게임이 전달한 준비·중단 원인과 콜백으로 화면만 구성합니다.
/// 서버 상태와 게임 규칙은 변경하지 않습니다.
class GameRecoveryLayer extends StatelessWidget {
  const GameRecoveryLayer({
    super.key,
    this.request,
    this.connection,
    this.interruption,
    this.session,
    this.onExit,
    required this.child,
  });

  final Widget child;
  final GameRequestRecovery? request;
  final GameConnectionRecovery? connection;
  final GameInterruptionRecovery? interruption;
  final GameRecoverySession? session;
  final VoidCallback? onExit;

  @override
  Widget build(BuildContext context) {
    final live = session;
    if (live != null) {
      return AnimatedBuilder(
        animation: live,
        builder: (context, _) => _build(context),
      );
    }
    return _build(context);
  }

  Widget _build(BuildContext context) {
    final interruption = this.interruption;
    final waiting =
        connection?.isWaiting == true || (session != null && !session!.canSend);
    final state = interruption?.state;
    final interrupted =
        state != null &&
        (state.pauseId != null ||
            state.causes.isNotEmpty ||
            state.playerUid.isNotEmpty);
    final playerInterruption =
        interrupted &&
        interruption?.presentation == GameInterruptionPresentation.player;
    return Stack(
      fit: StackFit.expand,
      children: [
        // 메뉴·나가기는 계속 사용할 수 있어야 합니다. 플레이 입력은 게임
        // content와 명령 서비스의 canSend 검사에서 차단합니다.
        child,
        // 실제 중단의 오류는 중단 안내 한 곳에서만 표시합니다.
        if (request case final request?)
          if (request.visible && !interrupted)
            GameRequestNotice(
              busy: request.busy && !waiting,
              message: request.message,
              onRetry: waiting
                  ? connection?.onRetry ?? session?.retry
                  : request.onRetry,
              busyMessage: request.busyMessage,
            ),
        if (playerInterruption)
          GameRequestNotice(
            message:
                interruption?.failureMessage ??
                request?.message ??
                '게임을 잠시 멈췄어요. 연결과 화면 준비를 기다리고 있어요.',
            onRetry:
                session != null &&
                    (!session!.localUsable || !session!.serverConfirmed) &&
                    request?.message != null
                ? connection?.onRetry ?? session?.retry
                : null,
          ),
        if (interrupted && !playerInterruption && interruption != null)
          GameInterruptionLayer(
            interruption: interruption.state,
            currentUid: interruption.currentUid,
            presentation: interruption.presentation,
            isSubmitting: interruption.isSubmitting,
            failureMessage: interruption.failureMessage,
            onContinue: interruption.onContinue,
            onFinishNow: interruption.onFinishNow,
            onExpired: interruption.onExpired,
            onWaitMore: interruption.onWaitMore,
          ),
      ],
    );
  }
}

/// 일반 게임 명령의 전송 중·실패 표시 설정입니다.
@immutable
class GameRequestRecovery {
  const GameRequestRecovery({
    this.visible = true,
    this.busy = false,
    this.message,
    this.onRetry,
    this.busyMessage = '서버 응답을 기다리고 있습니다…',
  });

  final bool visible;
  final bool busy;
  final String? message;
  final VoidCallback? onRetry;
  final String busyMessage;
}

/// 데이터 준비 대기와 실제 실패의 재시도 설정입니다. 정상 대기는 UI를 띄우지 않습니다.
@immutable
class GameConnectionRecovery {
  const GameConnectionRecovery({
    required this.isWaiting,
    this.exitDelay = const Duration(seconds: 10),
    this.message,
    this.onExit,
    this.onRetry,
  });

  final bool isWaiting;
  // 기존 호출부 호환용입니다. 대기 시간·문구·나가기 버튼을 별도로 표시하지 않습니다.
  final Duration exitDelay;
  final String? message;
  final VoidCallback? onExit;
  final VoidCallback? onRetry;
}

/// 다른 플레이어의 단절·퇴장으로 서버가 게임을 중단한 상황의 설정입니다.
@immutable
class GameInterruptionRecovery {
  const GameInterruptionRecovery({
    required this.state,
    required this.currentUid,
    this.presentation = GameInterruptionPresentation.player,
    this.isSubmitting = false,
    this.failureMessage,
    this.onVote,
    this.onContinue,
    this.onFinishNow,
    this.onExpired,
    this.onWaitMore,
  });

  final GameInterruption? state;
  final String currentUid;
  final GameInterruptionPresentation presentation;
  final bool isSubmitting;
  final String? failureMessage;
  final Future<void> Function()? onVote;
  final Future<bool> Function()? onContinue;
  final Future<bool> Function()? onFinishNow;
  final Future<bool> Function()? onExpired;
  final Future<bool> Function()? onWaitMore;
}
