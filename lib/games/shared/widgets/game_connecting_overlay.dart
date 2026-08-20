import 'dart:async';

import 'package:flutter/material.dart';
import 'package:project00/games/shared/game_flow/game_flow_copy.dart';

/// 첫 서버 상태가 오래 도착하지 않을 때만 나타나는 대기 안내 레이어입니다.
///
/// 연결 단계는 원래 배경만 보여 주는 것이 연출 의도지만, 서버 상태가
/// 비정상적으로 오래 오지 않으면 사용자는 화면이 멈춘 것과 구분할 수
/// 없습니다. 이 레이어는 [indicatorDelay]가 지나야 안내를 표시하고,
/// [exitDelay]가 지나면 나가기 버튼까지 제공해 영구 대기를 막습니다.
///
/// 전체 화면 `Stack`에 놓이는 레이어이므로 빈 상태에서도 항상
/// [Positioned]를 반환합니다(느슨한 Stack에서 화면이 0×0이 되는 회귀 방지).
class GameConnectingOverlay extends StatefulWidget {
  const GameConnectingOverlay({
    super.key,
    required this.isWaiting,
    this.onExit,
    this.indicatorDelay = const Duration(seconds: 6),
    this.exitDelay = const Duration(seconds: 20),
  });

  /// true인 동안 대기 중으로 간주합니다. false가 되는 즉시 사라집니다.
  final bool isWaiting;

  /// 나가기 버튼을 눌렀을 때 실행할 동작입니다. null이면 버튼을 숨깁니다.
  final VoidCallback? onExit;

  /// 이 시간 동안은 아무것도 표시하지 않아 정상 진입 연출을 가리지 않습니다.
  final Duration indicatorDelay;

  /// 대기가 이 시간을 넘기면 나가기 버튼을 함께 표시합니다.
  final Duration exitDelay;

  @override
  State<GameConnectingOverlay> createState() => _GameConnectingOverlayState();
}

class _GameConnectingOverlayState extends State<GameConnectingOverlay> {
  Timer? _indicatorTimer;
  Timer? _exitTimer;
  bool _showIndicator = false;
  bool _showExit = false;

  @override
  void initState() {
    super.initState();
    if (widget.isWaiting) _startTimers();
  }

  @override
  void didUpdateWidget(GameConnectingOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isWaiting == oldWidget.isWaiting) return;
    if (widget.isWaiting) {
      _startTimers();
    } else {
      _stopTimers();
      if (_showIndicator || _showExit) {
        setState(() {
          _showIndicator = false;
          _showExit = false;
        });
      }
    }
  }

  void _startTimers() {
    _stopTimers();
    _indicatorTimer = Timer(widget.indicatorDelay, () {
      if (mounted && widget.isWaiting) setState(() => _showIndicator = true);
    });
    _exitTimer = Timer(widget.exitDelay, () {
      if (mounted && widget.isWaiting) setState(() => _showExit = true);
    });
  }

  void _stopTimers() {
    _indicatorTimer?.cancel();
    _indicatorTimer = null;
    _exitTimer?.cancel();
    _exitTimer = null;
  }

  @override
  void dispose() {
    _stopTimers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.isWaiting && _showIndicator;
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 300),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  GameFlowCopy.waitingForGameData,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                  ),
                ),
                if (_showExit && widget.onExit != null) ...[
                  const SizedBox(height: 20),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
