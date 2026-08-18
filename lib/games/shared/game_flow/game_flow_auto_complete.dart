import 'dart:async';

import 'package:flutter/widgets.dart';

/// 선택적 화면 애니메이션을 껐을 때 완료 콜백을 한 번 대신 호출합니다.
///
/// 카드 분배·결과 공개처럼 완료 콜백이 callable 명령을 보내는 경계에서는 Widget을
/// 단순히 제거하면 서버 phase가 영원히 다음 단계로 넘어가지 않습니다. 연출을
/// 비활성화한 경우 반드시 이 위젯처럼 완료 신호를 보존해야 합니다.
class GameFlowAutoComplete extends StatefulWidget {
  const GameFlowAutoComplete({
    super.key,
    required this.onCompleted,
    this.delay = Duration.zero,
  });

  final VoidCallback onCompleted;
  final Duration delay;

  @override
  State<GameFlowAutoComplete> createState() => _GameFlowAutoCompleteState();
}

class _GameFlowAutoCompleteState extends State<GameFlowAutoComplete> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.delay == Duration.zero) {
        widget.onCompleted();
        return;
      }
      _timer = Timer(widget.delay, () {
        if (mounted) widget.onCompleted();
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
