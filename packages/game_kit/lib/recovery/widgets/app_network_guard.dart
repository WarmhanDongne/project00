// [app_network_guard.dart] 는 여러 게임이 함께 사용하는 네트워크 연결 상태와 재연결 흐름을 관리하는 파일이다.
//
// - [Package] : 게임 공통 기반
// - [RecoveryWidget] : 앱 범위의 연결 단절과 복구 UI를 관리함
//
// 즉, 통신이 끊겨도 연결 문제를 안내하고 안전하게 복구하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:game_kit/recovery/widgets/network_unavailable_modal.dart';

// ============================================================

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
    this.noticeDelay = const Duration(seconds: 3),
    this.showDelay = const Duration(seconds: 10),
  });

  final Widget child;
  final Stream<bool>? connectionChanges;
  final Future<void> Function()? onRetry;
  final VoidCallback? onExit;
  final String exitLabel;

  /// 이 시간 이전에는 안내를 숨깁니다. 게임 입력은 연결 단절 즉시 보호합니다.
  final Duration noticeDelay;

  /// 단절부터 모달까지의 시간입니다. 작은 안내 이후 추가 시간이 아닙니다.
  final Duration showDelay;

  @override
  State<AppNetworkGuard> createState() => _AppNetworkGuardState();
}

class _AppNetworkGuardState extends State<AppNetworkGuard>
    with WidgetsBindingObserver {
  StreamSubscription<bool>? _subscription;
  Timer? _showTimer;
  Timer? _noticeTimer;
  bool _isConnected = true;
  bool _needsRecovery = false;
  bool _isNoticeVisible = false;
  bool _isModalVisible = false;
  bool _isRetrying = false;
  bool _isForeground = true;
  int _subscriptionGeneration = 0;
  int _connectionGeneration = 0;
  bool _hasParentGuard = false;
  bool _didSubscribe = false;

  // RTDB 연결은 SDK가 복구합니다. 이 간격은 연결 후 세션 복구 실패에만 적용하며
  // 카드 제출/CALL 등 게임 행동을 새 명령으로 재전송하지 않습니다.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _isForeground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final hasParent =
        context.dependOnInheritedWidgetOfExactType<_NetworkGuardScope>() !=
        null;
    if (!_didSubscribe || _hasParentGuard != hasParent) {
      _didSubscribe = true;
      _hasParentGuard = hasParent;
      _subscribe();
    }
  }

  @override
  void didUpdateWidget(AppNetworkGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.connectionChanges != widget.connectionChanges) {
      _subscribe();
    } else if ((oldWidget.showDelay != widget.showDelay ||
            oldWidget.noticeDelay != widget.noticeDelay) &&
        _needsRecovery &&
        _isForeground &&
        !_isModalVisible) {
      _showTimer?.cancel();
      _showTimer = null;
      _noticeTimer?.cancel();
      _noticeTimer = null;
      _scheduleNotices();
    }
  }

  void _subscribe() {
    final generation = ++_subscriptionGeneration;
    unawaited(_subscription?.cancel());
    _subscription = null;
    _connectionGeneration++;
    _showTimer?.cancel();
    _showTimer = null;
    _noticeTimer?.cancel();
    _noticeTimer = null;
    _isConnected = true;
    _needsRecovery = false;
    _isNoticeVisible = false;
    _isModalVisible = false;
    final stream = widget.connectionChanges;
    // 앱 루트 가드가 비활성이면 자식이 담당하고, 활성 부모가 있으면 중복하지 않습니다.
    if (stream == null || _hasParentGuard) return;
    _subscription = stream.listen(
      (isConnected) {
        if (generation == _subscriptionGeneration) {
          _handleConnectionChanged(isConnected);
        }
      },
      onError: (_) {
        if (generation == _subscriptionGeneration) {
          _handleConnectionChanged(false);
        }
      },
      onDone: () {
        if (generation == _subscriptionGeneration) {
          _handleConnectionChanged(false);
        }
      },
    );
  }

  void _handleConnectionChanged(bool isConnected) {
    if (!mounted) return;
    _log('connection_changed', {'connected': isConnected});
    if (_isConnected != isConnected) _connectionGeneration++;
    _isConnected = isConnected;
    if (isConnected) {
      if (_needsRecovery && !_isRetrying) unawaited(_retry());
      return;
    }

    setState(() => _needsRecovery = true);
    _scheduleNotices();
  }

  // 연결이 반복해서 끊기거나 세션 복구만 실패해도 안내 시간을 초기화하지 않습니다.
  void _scheduleNotices() {
    if (!_isForeground || !_needsRecovery) return;
    if (!_isNoticeVisible && _noticeTimer == null) {
      _noticeTimer = Timer(widget.noticeDelay, () {
        _noticeTimer = null;
        if (mounted && _needsRecovery) {
          setState(() => _isNoticeVisible = true);
        }
      });
    }
    if (!_isForeground || _isModalVisible || _showTimer != null) return;
    _showTimer = Timer(widget.showDelay, () {
      _showTimer = null;
      if (mounted && _needsRecovery) {
        _log('modal_shown', {'delayMs': widget.showDelay.inMilliseconds});
        setState(() => _isModalVisible = true);
      }
    });
  }

  Future<void> _retry() async {
    // 오프라인에는 callable을 반복 호출하지 않고 SDK의 연결 복구를 기다립니다.
    if (!_isForeground || !_needsRecovery || _isRetrying || !_isConnected) {
      return;
    }
    final subscriptionGeneration = _subscriptionGeneration;
    final connectionGeneration = _connectionGeneration;
    _log('recovery_started');
    setState(() => _isRetrying = true);
    var recovered = false;
    try {
      await widget.onRetry?.call();
      recovered = true;
    } catch (error) {
      _log('recovery_failed', {'errorType': error.runtimeType.toString()});
      // 실패 횟수만으로 게임을 종료하거나 홈으로 이동하지 않습니다.
    } finally {
      if (mounted) {
        setState(() {
          _isRetrying = false;
        });
        // 이전 연결의 늦은 응답이 새 연결의 입력 잠금을 풀지 못하도록 합니다.
        if (recovered &&
            _isConnected &&
            subscriptionGeneration == _subscriptionGeneration &&
            connectionGeneration == _connectionGeneration) {
          _completeRecovery();
        } else {
          if (_isConnected && connectionGeneration != _connectionGeneration) {
            unawaited(_retry());
          }
        }
      }
    }
  }

  void _completeRecovery() {
    _log('recovery_succeeded');
    _showTimer?.cancel();
    _showTimer = null;
    _noticeTimer?.cancel();
    _noticeTimer = null;
    setState(() {
      _needsRecovery = false;
      _isNoticeVisible = false;
      _isModalVisible = false;
    });
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
      _noticeTimer?.cancel();
      _noticeTimer = null;
      return;
    }
    // 백그라운드 시간만으로 새 모달을 띄우지 않고 복귀 시 다시 복구를 시도합니다.
    if (_needsRecovery) {
      _scheduleNotices();
      unawaited(_retry());
    }
  }

  @override
  void dispose() {
    _subscriptionGeneration += 1;
    _showTimer?.cancel();
    _noticeTimer?.cancel();
    unawaited(_subscription?.cancel());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasParentGuard || widget.connectionChanges == null) {
      return widget.child;
    }
    return _NetworkGuardScope(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 화면은 유지하되 오래된 손패/턴을 보고 행동하지 못하도록 입력을 보호합니다.
          // 서버의 턴 시간과 이미 전송된 명령은 이 레이어가 중지하지 않습니다.
          AbsorbPointer(
            absorbing: _needsRecovery,
            child: ExcludeFocus(excluding: _needsRecovery, child: widget.child),
          ),
          if (_isNoticeVisible && !_isModalVisible)
            const Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: SafeArea(
                child: IgnorePointer(
                  child: Center(
                    child: Material(
                      color: Color(0xDD252535),
                      borderRadius: BorderRadius.all(Radius.circular(20)),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        child: Text(
                          '연결 확인 중…',
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (_isModalVisible)
            Positioned.fill(
              child: NetworkUnavailableModal(
                isRetrying: _isRetrying,
                retryEnabled: _isConnected,
                onRetry: () => unawaited(_retry()),
                onExit: widget.onExit,
                exitLabel: widget.exitLabel,
                title: '인터넷 연결이 끊겼어요',
                description: '게임 화면은 그대로 있어요.\n와이파이나 모바일 데이터를 확인해 주세요.',
              ),
            ),
        ],
      ),
    );
  }
}

/// 같은 위젯 트리의 플랫폼/게임 가드가 안내와 복구를 중복 실행하지 않게 합니다.
class _NetworkGuardScope extends InheritedWidget {
  const _NetworkGuardScope({required super.child});

  @override
  bool updateShouldNotify(_NetworkGuardScope oldWidget) => false;
}
