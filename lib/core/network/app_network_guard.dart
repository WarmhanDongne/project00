import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:project00/core/network/network_unavailable_modal.dart';
import 'package:project00/core/network/realtime_connection_monitor.dart';

/// 플랫폼과 모든 게임 위에 동일한 네트워크 연결 모달을 제공하는 앱 루트 레이어입니다.
///
/// Firebase RTDB의 `.info/connected`는 단순 Wi-Fi 연결 여부가 아니라 앱이 실제로
/// Firebase 서버와 통신 가능한지를 알려줍니다. 앱 루트에서 한 번만 구독해 개별
/// 화면이나 게임이 별도 연결 구독을 만들지 않도록 합니다.
class AppNetworkGuard extends StatefulWidget {
  const AppNetworkGuard({
    super.key,
    required this.child,
    this.database,
    this.connectionChanges,
    this.onRetry,
    this.showDelay = const Duration(seconds: 2),
  });

  final Widget child;
  final FirebaseDatabase? database;
  final Stream<bool>? connectionChanges;
  final Future<void> Function()? onRetry;
  final Duration showDelay;

  @override
  State<AppNetworkGuard> createState() => _AppNetworkGuardState();
}

class _AppNetworkGuardState extends State<AppNetworkGuard> {
  StreamSubscription<bool>? _subscription;
  Timer? _showTimer;
  bool _isConnected = true;
  bool _isModalVisible = false;
  bool _isRetrying = false;
  // 앱 시작 시 .info/connected는 항상 false를 먼저 방출합니다(Firebase SDK 스펙).
  // 한 번도 연결된 적 없는 초기화 단계의 false 이벤트와 실제 연결 끊김을
  // 구분하기 위해 최초 연결 여부를 추적합니다.
  bool _everConnected = false;

  FirebaseDatabase get _database =>
      widget.database ?? FirebaseDatabase.instance;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(AppNetworkGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.database != widget.database ||
        oldWidget.connectionChanges != widget.connectionChanges) {
      _subscribe();
    }
  }

  void _subscribe() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    try {
      final stream =
          widget.connectionChanges ??
          RealtimeConnectionMonitor.instance.watch(_database);
      _subscription = stream.listen(
        _handleConnectionChanged,
        onError: (_) => _handleConnectionChanged(false),
      );
    } catch (_) {
      // Firebase가 없는 순수 위젯 테스트 환경에서는 앱 화면을 그대로 유지합니다.
    }
  }

  void _handleConnectionChanged(bool isConnected) {
    _isConnected = isConnected;
    if (isConnected) {
      _everConnected = true; // 최초 연결 성공 기록
      _showTimer?.cancel();
      _showTimer = null;
      if (mounted && (_isModalVisible || _isRetrying)) {
        setState(() {
          _isModalVisible = false;
          _isRetrying = false;
        });
      }
      return;
    }

    // 한 번도 연결된 적 없으면(앱 시작 초기화 중) false 이벤트 무시.
    // Firebase SDK는 첫 서버 연결 수립 전 항상 false를 먼저 방출합니다.
    if (!_everConnected) return;

    if (_isModalVisible || _showTimer != null) return;
    _showTimer = Timer(widget.showDelay, () {
      _showTimer = null;
      if (mounted && !_isConnected) {
        setState(() => _isModalVisible = true);
      }
    });
  }

  Future<void> _retry() async {
    if (_isRetrying) return;
    setState(() => _isRetrying = true);
    try {
      if (widget.onRetry != null) {
        await widget.onRetry!();
      } else {
        await _database.goOnline();
      }
    } catch (_) {
      // 연결 상태 스트림이 성공/실패 여부를 확정하므로 모달은 그대로 유지합니다.
    } finally {
      if (mounted && !_isConnected) {
        setState(() => _isRetrying = false);
      }
    }
  }

  @override
  void dispose() {
    _showTimer?.cancel();
    unawaited(_subscription?.cancel());
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
              onBypass: () {
                setState(() {
                  _isModalVisible = false;
                  _isConnected = true; // 강제로 true로 설정해 타이머 방지
                });
              },
            ),
          ),
      ],
    );
  }
}
