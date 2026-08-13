import 'package:flutter/material.dart';
import 'package:project00/games/final_call/models/final_call_models.dart';

/// 내 턴 조작부와 다른 플레이어 턴 정보를 같은 자리에서 교체합니다.
class FinalCallTurnActionSwitcher extends StatelessWidget {
  const FinalCallTurnActionSwitcher({
    super.key,
    required this.isMyTurn,
    required this.turnPlayer,
    required this.action,
  });

  final bool isMyTurn;
  final FinalCallPlayer? turnPlayer;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      switchOutCurve: Curves.easeInCubic,
      switchInCurve: Curves.easeOutCubic,
      transitionBuilder: (child, animation) {
        final entering =
            child.key == ValueKey(isMyTurn ? 'action' : turnPlayer?.uid);
        final offset = Tween<Offset>(
          begin: entering ? const Offset(1, 0) : const Offset(-1, 0),
          end: Offset.zero,
        ).animate(animation);
        return ClipRect(
          child: SlideTransition(position: offset, child: child),
        );
      },
      child: isMyTurn
          ? SizedBox(key: const ValueKey('action'), child: action)
          : _TurnPlayerIndicator(
              key: ValueKey(turnPlayer?.uid ?? 'turn-empty'),
              player: turnPlayer,
            ),
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
                width: 62,
                height: 62,
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
        Text(
          '${player!.nickname}님\n차례입니다',
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
