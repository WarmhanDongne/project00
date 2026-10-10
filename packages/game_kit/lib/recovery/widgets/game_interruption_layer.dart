import 'dart:async';
import 'package:flutter/material.dart';
import 'package:game_kit/core/time/server_clock.dart';
import 'package:game_kit/recovery/models/game_interruption.dart';
import 'package:game_kit/recovery/widgets/game_request_notice.dart';

enum GameInterruptionPresentation { player, tabletController }

/// 실제 복구 중단은 원인이 해소된 준비 barrier까지 기존 안내로 표시합니다.
class GameInterruptionLayer extends StatefulWidget {
  const GameInterruptionLayer({
    super.key,
    required this.interruption,
    required this.currentUid,
    this.presentation = GameInterruptionPresentation.player,
    this.onContinue,
    this.onFinishNow,
    this.onExpired,
    this.onWaitMore,
    this.onExit,
    this.failureMessage,
    this.isSubmitting = false,
    this.scrimColor = const Color(0xE8000000),
  });
  final GameInterruption? interruption;
  final String currentUid;
  final GameInterruptionPresentation presentation;
  final Future<bool> Function()? onContinue, onFinishNow, onExpired, onWaitMore;
  final VoidCallback? onExit;
  final String? failureMessage;
  final bool isSubmitting;
  final Color scrimColor;
  @override
  State<GameInterruptionLayer> createState() => _GameInterruptionLayerState();
}

class _GameInterruptionLayerState extends State<GameInterruptionLayer> {
  Timer? _timer;
  bool _busy = false, _failed = false, _confirmEnd = false;
  String? _expired;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final current = widget.interruption;
      if (widget.presentation ==
              GameInterruptionPresentation.tabletController &&
          current != null &&
          (current.causes.isNotEmpty || current.playerUid.isNotEmpty) &&
          current.deadlineAt > 0 &&
          _remaining(current) == 0 &&
          _expired != current.id) {
        _expired = current.id;
        // This only marks awaitingDecision and owns one bounded callable batch.
        if (widget.onExpired != null) unawaited(widget.onExpired!());
      }
      setState(() {});
    });
  }

  @override
  void didUpdateWidget(GameInterruptionLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.interruption?.id != widget.interruption?.id) {
      _expired = null;
      _failed = false;
      _busy = false;
      _confirmEnd = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  int _remaining(GameInterruption current) =>
      (ServerClock.remainingUntil(current.deadlineAt).inMilliseconds / 1000)
          .ceil()
          .clamp(0, 60);
  Future<void> _act(Future<bool> Function()? action) async {
    if (action == null || _busy) return;
    final id = widget.interruption?.id;
    setState(() {
      _busy = true;
      _failed = false;
    });
    var success = false;
    try {
      success = await action();
    } catch (_) {
      success = false;
    }
    if (!mounted || widget.interruption?.id != id) return;
    setState(() {
      _busy = false;
      _failed = !success;
    });
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.interruption;
    if (current == null ||
        (current.pauseId == null &&
            current.causes.isEmpty &&
            current.playerUid.isEmpty)) {
      return const SizedBox.shrink();
    }
    final controller =
        widget.presentation == GameInterruptionPresentation.tabletController;
    if (!controller) {
      // 휴대폰의 기존 상단바·퇴장 모달을 유지하며 오류 안내만 재사용합니다.
      return GameRequestNotice(
        message: widget.failureMessage ?? '게임을 잠시 멈췄어요. 연결과 화면 준비를 기다리고 있어요.',
      );
    }
    final seconds = current.deadlineAt > 0 ? _remaining(current) : null;
    return Positioned.fill(
      child: Material(
        color: widget.scrimColor,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.sync, color: Colors.white, size: 48),
                    const SizedBox(height: 20),
                    const Text(
                      '게임을 잠시 멈췄어요',
                      style: TextStyle(
                        fontSize: 25,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      current.causes.isEmpty
                          ? '모든 기기의 화면 준비를 확인하고 있어요.'
                          : '연결과 화면 준비를 기다리고 있어요.',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    for (final cause in current.causes)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${cause['role'] == 'controller' ? '진행 기기' : cause['playerNickname'] ?? '참가자'} · ${cause['awaitingDecision'] == true ? '진행자 결정 대기' : '복구 중'}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    if (seconds != null)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          seconds == 0
                              ? '자동으로 제외하거나 종료하지 않아요.'
                              : '$seconds초 동안 복구를 기다려요.',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    if (_failed || widget.failureMessage != null)
                      Text(
                        widget.failureMessage ?? '요청 결과를 확인하지 못했어요. 다시 시도해주세요.',
                        style: const TextStyle(color: Colors.orangeAccent),
                      ),
                    if (controller && current.playerUid.isNotEmpty) ...[
                      if (seconds == 0 && !current.extended)
                        FilledButton(
                          onPressed: _busy || widget.isSubmitting
                              ? null
                              : () => unawaited(_act(widget.onWaitMore)),
                          child: const Text('30초 더 기다리기'),
                        ),
                      FilledButton(
                        onPressed:
                            !current.canContinue || _busy || widget.isSubmitting
                            ? null
                            : () => unawaited(_act(widget.onContinue)),
                        child: const Text('제외하고 계속하기'),
                      ),
                      if (!current.canContinue)
                        const Text(
                          '제외하면 남은 인원으로 진행할 수 없어요.',
                          style: TextStyle(color: Colors.white70),
                        ),
                    ],
                    if (controller && widget.onFinishNow != null) ...[
                      if (_confirmEnd)
                        const Text(
                          '게임을 종료할까요?',
                          style: TextStyle(color: Colors.white),
                        ),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () {
                                if (_confirmEnd) {
                                  unawaited(_act(widget.onFinishNow));
                                } else {
                                  setState(() => _confirmEnd = true);
                                }
                              },
                        child: Text(_confirmEnd ? '종료 확인' : '게임 종료'),
                      ),
                      if (_confirmEnd)
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() => _confirmEnd = false),
                          child: const Text('계속 기다리기'),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
