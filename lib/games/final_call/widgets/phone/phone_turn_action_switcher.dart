import 'package:flutter/material.dart';
import 'package:project00/games/final_call/models/final_call_models.dart';

/// 휴대폰 내 턴 조작부와 다른 플레이어 턴 정보를 같은 자리에서 교체합니다.
class FinalCallTurnActionSwitcher extends StatelessWidget {
  const FinalCallTurnActionSwitcher({
    super.key,
    required this.isMyTurn,
    required this.turnPlayer,
    required this.action,
    this.callMessage,
  });

  final bool isMyTurn;
  final FinalCallPlayer? turnPlayer;
  final Widget action;
  final Widget? callMessage;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 420),
          switchOutCurve: Curves.easeInCubic,
          switchInCurve: Curves.easeOutCubic,
          layoutBuilder: (currentChild, previousChildren) => Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [...previousChildren, ?currentChild],
          ),
          transitionBuilder: (child, animation) {
            final entering =
                child.key == ValueKey(isMyTurn ? 'action' : turnPlayer?.uid);
            final offset = Tween<Offset>(
              begin: entering ? const Offset(0, 0.55) : const Offset(0, -0.55),
              end: Offset.zero,
            ).animate(animation);
            return SlideTransition(position: offset, child: child);
          },
          child: isMyTurn
              ? SizedBox(key: const ValueKey('action'), child: action)
              : _TurnPlayerIndicator(
                  key: ValueKey(turnPlayer?.uid ?? 'turn-empty'),
                  player: turnPlayer,
                ),
        ),
        if (callMessage != null)
          Positioned(
            left: -36,
            top: -26,
            child: IgnorePointer(
              child: SizedBox(width: 100, height: 54, child: callMessage),
            ),
          ),
      ],
    );
  }
}

class _TurnPlayerIndicator extends StatelessWidget {
  const _TurnPlayerIndicator({super.key, required this.player});
  final FinalCallPlayer? player;

  @override
  Widget build(BuildContext context) {
    if (player == null) return const SizedBox.shrink();
    final profile = player!.profileImageUrl;
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 78,
                height: 78,
                child: profile.isEmpty
                    ? const ColoredBox(
                        color: Colors.black12,
                        child: Icon(Icons.person),
                      )
                    : Image.network(
                        profile,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const ColoredBox(
                          color: Colors.black12,
                          child: Icon(Icons.person),
                        ),
                      ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 118),
          child: Text(
            player!.nickname,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        const Text(
          '님 차례입니다',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
