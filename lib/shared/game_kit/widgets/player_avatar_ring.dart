import 'package:flutter/material.dart';

class PlayerAvatarRing extends StatelessWidget {
  const PlayerAvatarRing({
    required this.child,
    this.isActive = false,
    super.key,
  });
  final Widget child;
  final bool isActive;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(
        color: isActive
            ? Theme.of(context).colorScheme.primary
            : Colors.transparent,
        width: 3,
      ),
    ),
    child: child,
  );
}
