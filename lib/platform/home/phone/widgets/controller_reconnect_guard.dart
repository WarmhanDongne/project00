import 'package:flutter/material.dart';
import 'package:project00/games/shared/widgets/game_reconnect_screen.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';

/// 태블릿 진행 기기가 잠시 사라졌을 때 현재 게임 화면과 상태를 보존한 채
/// 참가자 입력만 차단합니다.
class ControllerReconnectGuard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: provider,
      child: child,
      builder: (context, child) {
        final reconnecting =
            provider.controllerPresenceState ==
            ControllerPresenceState.reconnecting;
        return Stack(
          fit: StackFit.expand,
          children: [
            ?child,
            if (reconnecting)
              Positioned.fill(
                child: GameReconnectScreen(
                  title: '태블릿에 다시 연결하는 중',
                  message: '게임 상태를 안전하게 유지하고 있어요',
                  homeLabel: '게임 나가기',
                  onHome: onExit,
                ),
              ),
          ],
        );
      },
    );
  }
}
