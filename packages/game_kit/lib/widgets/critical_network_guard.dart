import 'package:flutter/material.dart';
import 'package:game_kit/core/network/app_network_guard.dart';
import 'package:game_kit/models/game_room_context.dart';

/// 게임/방 세션이 살아 있는 동안 RTDB 연결을 감시하는 계약 기반 경계입니다.
class CriticalNetworkGuard extends StatefulWidget {
  const CriticalNetworkGuard({
    super.key,
    required this.provider,
    required this.child,
    this.onExit,
    this.exitLabel = '홈으로',
  });

  final GameRoomContext provider;
  final Widget child;
  final VoidCallback? onExit;
  final String exitLabel;

  @override
  State<CriticalNetworkGuard> createState() => _CriticalNetworkGuardState();
}

class _CriticalNetworkGuardState extends State<CriticalNetworkGuard> {
  late Stream<bool> _connectionChanges;

  @override
  void initState() {
    super.initState();
    _connectionChanges = widget.provider.watchServerConnection();
  }

  @override
  void didUpdateWidget(CriticalNetworkGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.provider, widget.provider)) {
      _connectionChanges = widget.provider.watchServerConnection();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppNetworkGuard(
      connectionChanges: _connectionChanges,
      onRetry: widget.provider.retryConnectionRecovery,
      onExit: widget.onExit,
      exitLabel: widget.exitLabel,
      child: widget.child,
    );
  }
}
