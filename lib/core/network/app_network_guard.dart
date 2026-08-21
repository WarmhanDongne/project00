import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:project00/core/network/network_unavailable_modal.dart';

/// 서버 연결이 필수인 화면에서만 사용하는 네트워크 연결 모달 레이어입니다.
///
/// [connectionChanges]를 전달하지 않으면 아무 연결도 감시하지 않습니다. 앱 루트는
/// 이 비활성 형태를 사용해 초기 Firebase 연결 수립 과정만으로 팝업이 나타나는 것을
/// 막고, 방 대기실과 진행 중 게임처럼 실시간 연결이 실제로 필요한 화면만 스트림을
/// 전달합니다.
class AppNetworkGuard extends StatefulWidget {
  const AppNetworkGuard({
    super.key,
    required this.child,
    this.connectionChanges,
    this.onRetry,
    this.onExit,
    this.exitLabel = '홈으로',
    this.showDelay = const Duration(seconds: 10),
  });

  final Widget child;
  final Stream<bool>? connectionChanges;
  final Future<void> Function()? onRetry;
  final VoidCallback? onExit;
  final String exitLabel;
  final Duration showDelay;

  @override
  State<AppNetworkGuard> createState() => _AppNetworkGuardState();
}

class _AppNetworkGuardState extends State<AppNetworkGuard>
    with WidgetsBindingObserver {
  StreamSubscription<bool>? _subscription;
  Timer? _showTimer;
  bool _isConnected = true;
  bool _isModalVisible = false;
  bool _isRetrying = false;
  bool _isForeground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subscribe();
  }

  @override
  void didUpdateWidget(AppNetworkGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.connectionChanges != widget.connectionChanges) {
      _subscribe();
    }
  }

  void _subscribe() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    _showTimer?.cancel();
    _showTimer = null;
    final stream = widget.connectionChanges;
    if (stream == null) return;
    _subscription = stream.listen(
      _handleConnectionChanged,
      onError: (_) => _handleConnectionChanged(false),
    );
  }

  void _handleConnectionChanged(bool isConnected) {
    if (!mounted) return;
    _log('connection_changed', {'connected': isConnected});
    _isConnected = isConnected;
    if (isConnected) {
      _showTimer?.cancel();
      _showTimer = null;
      if (_isModalVisible && widget.onRetry != null) {
        if (!_isRetrying) unawaited(_retry());
        return;
      }
      if (mounted && (_isModalVisible || _isRetrying)) {
        setState(() {
          _isModalVisible = false;
          _isRetrying = false;
        });
      }
      return;
    }

    if (!_isForeground || _isModalVisible || _showTimer != null) return;
    _showTimer = Timer(widget.showDelay, () {
      _showTimer = null;
      if (mounted && !_isConnected) {
        _log('modal_shown', {'delayMs': widget.showDelay.inMilliseconds});
        setState(() => _isModalVisible = true);
      }
    });
  }

  Future<void> _retry() async {
    if (_isRetrying) return;
    _log('recovery_started');
    setState(() => _isRetrying = true);
    var recovered = false;
    try {
      await widget.onRetry?.call();
      recovered = true;
      _log('recovery_succeeded');
    } catch (error) {
      _log('recovery_failed', {'errorType': error.runtimeType.toString()});
      // 연결 상태 스트림이 성공/실패 여부를 확정하므로 모달은 그대로 유지합니다.
    } finally {
      if (mounted) {
        setState(() {
          _isRetrying = false;
          if (recovered && _isConnected) _isModalVisible = false;
        });
      }
    }
  }

  void _log(String event, [Map<String, Object?> fields = const {}]) {
    if (!kDebugMode) return;
    final details = fields.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join(' ');
    debugPrint(
      '[network_guard] event=$event${details.isEmpty ? '' : ' $details'}',
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isForeground = state == AppLifecycleState.resumed;
    if (!_isForeground) {
      _showTimer?.cancel();
      _showTimer = null;
      return;
    }
    if (!_isConnected && !_isModalVisible) {
      _handleConnectionChanged(false);
    }
  }

  @override
  void dispose() {
    _showTimer?.cancel();
    unawaited(_subscription?.cancel());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_isModalVisible)
          Positioned.fill(
            child: NetworkUnavailableModal(
              isRetrying: _isRetrying,
              onRetry: () => unawaited(_retry()),
              onExit: widget.onExit,
              exitLabel: widget.exitLabel,
            ),
          ),
      ],
    );
  }
}
