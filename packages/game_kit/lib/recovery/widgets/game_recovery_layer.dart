import 'package:flutter/material.dart';
import 'package:game_kit/recovery/models/game_interruption.dart';
import 'package:game_kit/recovery/models/game_recovery_context.dart';
import 'package:game_kit/recovery/widgets/game_connecting_overlay.dart';
import 'package:game_kit/recovery/widgets/game_interruption_layer.dart';
import 'package:game_kit/recovery/widgets/game_request_notice.dart';

export 'package:game_kit/recovery/widgets/game_interruption_layer.dart'
    show GameInterruptionPresentation;

/// 정상 게임 화면 위에 요청·재연결·플레이어 이탈 UI를 같은 순서로 쌓습니다.
///
/// 이 위젯은 서버 상태를 판단하지 않습니다. 각 게임의 board가 이미 계산한 상태와
/// 콜백을 전달하면 화면만 구성합니다. 따라서 게임 규칙과 복구 UI가 섞이지 않습니다.
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
    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          ignoring:
              (session != null && !session!.canSend) ||
              connection?.isWaiting == true ||
              interruption?.state != null,
          child: child,
        ),
        // 이탈 모달이 열리면 그 안에서 실패를 표시합니다. 아래 요청 안내를 함께
        // 그리면 scrim 뒤에 가려지고 같은 오류가 두 군데에서 관리됩니다.
        if (request case final request?)
          if (request.visible && interruption?.state == null && !waiting)
            GameRequestNotice(
              busy: request.busy,
              message: request.message,
              onRetry: request.onRetry,
              busyMessage: request.busyMessage,
            ),
        if (interruption?.state == null &&
            (connection != null || session != null))
          GameConnectingOverlay(
            isWaiting: waiting,
            exitDelay: connection?.exitDelay ?? const Duration(seconds: 10),
            message: connection?.message,
            onExit: onExit ?? connection?.onExit,
            onRetry: connection?.onRetry ?? session?.retry,
          ),
        if (interruption != null)
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
            onExit: onExit ?? connection?.onExit,
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

/// 게임 데이터를 다시 받는 동안의 대기·재시도·나가기 설정입니다.
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
