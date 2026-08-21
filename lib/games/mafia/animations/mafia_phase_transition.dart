import 'package:flutter/material.dart';

//=======================단계 전환 연출==============================
/// 단계가 바뀔 때 **있던 요소가 빠지고 새 요소가 들어오는** 전환입니다.
///
/// 확정(2026-08): 단계마다 화면이 따로 렌더되어 뚝 끊기는 느낌 대신, 이전
/// 내용이 먼저 물러나고 새 내용이 들어옵니다.
///
///   이전 내용 사라짐(0.22초) → 새 내용 들어옴(0.32초)
///
/// 두 겹을 동시에 흐리게 겹치지(크로스페이드) 않는 이유는, 같은 배경 그림을
/// 두 화면이 함께 그릴 때 겹치는 순간 배경이 한 번 어두워지기 때문입니다.
/// 그래서 **배경·상단 아이콘·보관 카드처럼 단계가 바뀌어도 그대로 있는
/// 요소는 이 위젯 밖(셸)에 두고**, 바뀌는 내용만 여기에 넣습니다.
///
/// [child]에는 **단계마다 다른 key**를 주어야 합니다. key가 같으면 같은 화면이
/// 갱신된 것으로 보아 전환 없이 그대로 그립니다(연출 도중 상태가 바뀌어도
/// 처음부터 다시 시작하지 않습니다).
class MafiaPhaseTransition extends StatefulWidget {
  const MafiaPhaseTransition({super.key, required this.child});

  final Widget child;

  /// 이전 내용이 물러나는 시간입니다.
  static const Duration exitDuration = Duration(milliseconds: 220);

  /// 새 내용이 들어오는 시간입니다.
  static const Duration enterDuration = Duration(milliseconds: 320);

  /// 들어오고 나갈 때 위아래로 움직이는 폭입니다(논리 픽셀).
  static const double slideDistance = 18;

  @override
  State<MafiaPhaseTransition> createState() => _MafiaPhaseTransitionState();
}

class _MafiaPhaseTransitionState extends State<MafiaPhaseTransition>
    with TickerProviderStateMixin {
  late final AnimationController _exit;
  late final AnimationController _enter;

  /// 지금 화면에 있는 내용입니다.
  late Widget _current;

  /// 이전 내용이 물러나는 동안 기다리는 다음 내용입니다.
  Widget? _pending;

  @override
  void initState() {
    super.initState();
    _current = widget.child;
    _exit = AnimationController(
      vsync: this,
      duration: MafiaPhaseTransition.exitDuration,
    )..addStatusListener(_handleExitDone);
    _enter = AnimationController(
      vsync: this,
      duration: MafiaPhaseTransition.enterDuration,
      // 첫 화면은 전환 없이 바로 보입니다.
      value: 1,
    );
  }

  void _handleExitDone(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    final next = _pending;
    if (next == null || !mounted) return;
    setState(() {
      _current = next;
      _pending = null;
    });
    _exit.value = 0;
    _enter.forward(from: 0);
  }

  @override
  void didUpdateWidget(MafiaPhaseTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 같은 화면이 갱신된 것뿐이면 그대로 이어 그립니다.
    if (Widget.canUpdate(_current, widget.child)) {
      setState(() => _current = widget.child);
      return;
    }
    // 물러나는 중에 또 바뀌면 마지막 것만 기다리게 둡니다.
    _pending = widget.child;
    if (!_exit.isAnimating) _exit.forward(from: 0);
  }

  @override
  void dispose() {
    _exit
      ..removeStatusListener(_handleExitDone)
      ..dispose();
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_exit, _enter]),
      builder: (context, _) {
        // 물러나는 중이면 이전 내용을, 아니면 들어오는 새 내용을 그립니다.
        final isLeaving = _pending != null || _exit.isAnimating;
        final progress = isLeaving
            ? Curves.easeIn.transform(_exit.value)
            : Curves.easeOutCubic.transform(_enter.value);

        // 물러날 때는 위로 밀려 사라지고, 들어올 때는 아래에서 올라옵니다.
        final opacity = isLeaving ? 1 - progress : progress;
        final offset = isLeaving
            ? -MafiaPhaseTransition.slideDistance * progress
            : MafiaPhaseTransition.slideDistance * (1 - progress);

        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, offset),
            child: _current,
          ),
        );
      },
    );
  }
}
