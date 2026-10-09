// [game_connecting_overlay.dart] 는 여러 게임이 함께 사용하는 게임 화면에서 반복 사용하는 공통 UI를 구성하는 파일이다.
//
// - [Package] : 게임 공통 기반
// - [RecoveryWidget] : 게임 데이터 복구 대기와 수동 재연결을 표시함
//
// 즉, 같은 표시와 조작 방식을 여러 화면에서 재사용하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:game_kit/game_flow/game_flow_copy.dart';

// ============================================================

/// 복구 중 내 나가기를 즉시 제공하고 10초 뒤 설명과 재연결을 표시합니다.
/// 같은 대기 중 버튼 재시도는 안내 시각을 초기화하지 않습니다.
class GameConnectingOverlay extends StatefulWidget {
  const GameConnectingOverlay({
    super.key,
    required this.isWaiting,
    this.onExit,
    this.exitDelay = const Duration(seconds: 10),
    this.message,
    this.onRetry,
  });

  /// true인 동안 대기 중으로 간주합니다. false가 되는 즉시 사라집니다.
  final bool isWaiting;

  /// 나가기 버튼을 눌렀을 때 실행할 동작입니다. null이면 아무것도 표시하지
  /// 않습니다.
  final VoidCallback? onExit;

  /// 대기가 이 시간을 넘기면 설명과 재연결 버튼을 표시합니다.
  final Duration exitDelay;

  /// 필요한 게임만 긴 대기의 이유를 표시합니다. 기존 게임의 무문구 정책은 유지합니다.
  final String? message;
  final VoidCallback? onRetry;

  @override
  State<GameConnectingOverlay> createState() => _GameConnectingOverlayState();
}

class _GameConnectingOverlayState extends State<GameConnectingOverlay> {
  Timer? _exitTimer;
  bool _showExit = false;

  @override
  void initState() {
    super.initState();
    if (widget.isWaiting) _startTimer();
  }

  @override
  void didUpdateWidget(GameConnectingOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isWaiting &&
        (!oldWidget.isWaiting || oldWidget.exitDelay != widget.exitDelay)) {
      _showExit = false;
      _startTimer();
    } else if (!widget.isWaiting && oldWidget.isWaiting) {
      _stopTimer();
      _showExit = false;
    }
  }

  void _startTimer() {
    _stopTimer();
    _exitTimer = Timer(widget.exitDelay, () {
      if (mounted && widget.isWaiting) setState(() => _showExit = true);
    });
  }

  void _stopTimer() {
    _exitTimer?.cancel();
    _exitTimer = null;
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.isWaiting && (widget.onExit != null || _showExit);
    final hasDetails = _showExit;
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 300),
          // 보이지 않을 때는 트리에서도 뺍니다. 투명한 버튼이 남아 있으면
          // 접근성 트리에 잡히고, 테스트에서도 '없다'고 말할 수 없습니다.
          child: !visible
              ? const SizedBox.shrink()
              : Center(
                  child: Container(
                    margin: hasDetails
                        ? const EdgeInsets.all(24)
                        : EdgeInsets.zero,
                    padding: hasDetails
                        ? const EdgeInsets.all(20)
                        : EdgeInsets.zero,
                    decoration: hasDetails
                        ? BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(16),
                          )
                        : null,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_showExit) ...[
                          Text(
                            widget.message ?? '게임 데이터를 다시 준비하고 있습니다.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (_showExit && widget.onRetry != null)
                          TextButton(
                            onPressed: widget.onRetry,
                            child: const Text('다시 연결하기'),
                          ),
                        if (widget.onExit != null)
                          OutlinedButton(
                            onPressed: widget.onExit,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white54),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 10,
                              ),
                            ),
                            child: const Text(GameFlowCopy.leaveGame),
                          ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
