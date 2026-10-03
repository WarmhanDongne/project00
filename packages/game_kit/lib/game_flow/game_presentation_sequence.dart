import 'package:flutter/material.dart';
import 'game_presentation_clock.dart';

/// 서버 phase 안에서만 진행되는 화면의 한 박자입니다. 규칙/서버 상태는 바꾸지 않습니다.
class GamePresentationBeat {
  const GamePresentationBeat({required this.hold, required this.child});
  final Duration hold;
  final Widget child;
}

/// 중단 가능한 발표 순서입니다. 마지막 장면은 서버 상태가 바뀔 때까지 유지합니다.
/// 새 게임/라운드/발표에는 다른 key를 주어 이전 발표를 재사용하지 않습니다.
class GamePresentationSequence extends StatefulWidget {
  const GamePresentationSequence({
    super.key,
    required this.beats,
    this.completed,
  });
  final List<GamePresentationBeat> beats;
  final Widget? completed;

  @override
  State<GamePresentationSequence> createState() =>
      _GamePresentationSequenceState();
}

class _GamePresentationSequenceState extends State<GamePresentationSequence>
    with GamePresentationState {
  int _index = 0;
  PresentationTimer? _timer;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  void _schedule() {
    if (_index >= widget.beats.length) return;
    _timer = presentationTimer(widget.beats[_index].hold, () {
      if (!mounted) return;
      setState(() => _index++);
      _schedule();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.beats.isEmpty) {
      return widget.completed ?? const SizedBox.shrink();
    }
    final completed = _index >= widget.beats.length;
    final index = completed ? widget.beats.length - 1 : _index;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      child: KeyedSubtree(
        key: ValueKey(completed && widget.completed != null ? -1 : index),
        child: completed && widget.completed != null
            ? widget.completed!
            : widget.beats[index].child,
      ),
    );
  }
}
