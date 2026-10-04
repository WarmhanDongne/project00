// [critical_network_guard.dart] 는 여러 게임이 함께 사용하는 게임 화면에서 반복 사용하는 공통 UI를 구성하는 파일이다.
//
// - [Package] : 게임 공통 기반
// - [RecoveryWidget] : 중요한 네트워크 작업 중 연결 단절을 처리함
//
// 즉, 같은 표시와 조작 방식을 여러 화면에서 재사용하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'package:flutter/material.dart';
import 'package:game_kit/recovery/widgets/app_network_guard.dart';
import 'package:game_kit/models/game_room_context.dart';

// ============================================================

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
