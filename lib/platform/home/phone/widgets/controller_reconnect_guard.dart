import 'package:flutter/material.dart';
import 'package:project00/games/shared/widgets/game_reconnect_screen.dart';
import 'package:project00/games/shared/widgets/game_route_exit.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';

/// 태블릿 진행 기기가 잠시 사라졌을 때 현재 게임 화면과 상태를 보존한 채
/// 참가자 입력만 차단합니다.
class ControllerReconnectGuard extends StatefulWidget {
  const ControllerReconnectGuard({
    super.key,
    required this.provider,
    required this.child,
    required this.onExit,
  });

  final RoomProvider provider;
  final Widget child;
  final VoidCallback onExit;

  @override
  State<ControllerReconnectGuard> createState() =>
      _ControllerReconnectGuardState();
}

class _ControllerReconnectGuardState extends State<ControllerReconnectGuard> {
  bool _observedGameSession = false;
  bool _exitScheduled = false;

  bool get _hasGameSession =>
      (widget.provider.selectedGameId?.isNotEmpty ?? false) ||
      widget.provider.roomStatus == 'playing' ||
      widget.provider.roomStatus == 'finished';

  bool get _isAuthoritativelyBackInWaitingRoom =>
      _observedGameSession &&
      widget.provider.roomCode != null &&
      widget.provider.roomStatus == 'waiting' &&
      !(widget.provider.selectedGameId?.isNotEmpty ?? false);

  void _scheduleFinishedGameExit(BuildContext gameContext) {
    if (_exitScheduled || !_isAuthoritativelyBackInWaitingRoom) return;
    _exitScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !gameContext.mounted) return;
      if (!_isAuthoritativelyBackInWaitingRoom) {
        _exitScheduled = false;
        return;
      }
      exitGameRoute(gameContext);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.provider,
      child: widget.child,
      builder: (context, child) {
        if (_hasGameSession) _observedGameSession = true;
        _scheduleFinishedGameExit(context);
        final reconnecting =
            widget.provider.isServerConnected &&
            widget.provider.controllerPresenceState ==
                ControllerPresenceState.reconnecting;
        return Stack(
          fit: StackFit.expand,
          children: [
            ?child,
            if (reconnecting)
              Positioned.fill(
                child: GameReconnectScreen(
                  title: '태블릿에 다시 연결하는 중',
                  message: '일시적인 연결 문제라면 나가지 않고 재연결을 기다릴 수 있어요',
                  homeLabel: '게임과 그룹 나가기',
                  onHome: widget.onExit,
                ),
              ),
          ],
        );
      },
    );
  }
}
