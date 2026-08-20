import 'package:flutter/material.dart';
import 'package:project00/core/network/app_network_guard.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';

/// 방 또는 게임 세션이 살아 있는 동안만 RTDB 연결을 감시합니다.
class CriticalNetworkGuard extends StatefulWidget {
  const CriticalNetworkGuard({
    super.key,
    required this.provider,
    required this.child,
    this.onExit,
    this.exitLabel = '홈으로',
  });

  final RoomProvider provider;
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
