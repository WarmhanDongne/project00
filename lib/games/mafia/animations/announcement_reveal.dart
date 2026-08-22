import 'dart:async';

import 'package:flutter/material.dart';

//=======================발표 등장·퇴장==============================
/// 발표 내용이 **떠올랐다가 물러나는** 연출입니다.
///
/// 확정(2026-08): 안내 문구와 발표 내용이 한꺼번에 겹쳐 있지 않고 차례를
/// 지킵니다.
///
///   '아침이 되었습니다'(등장→퇴장) → 사망자 발표(등장→퇴장) → '토론을 시작합니다'
///
/// 아래에서 떠올라 들어오고, 나갈 때는 위로 물러납니다([MafiaPhaseTransition]과
/// 같은 방향이라 화면 전체가 같은 말투로 움직입니다).
///
/// [delay] 전과 퇴장이 끝난 뒤에는 아무것도 그리지 않습니다. 그래서 안내가
/// 뜨는 동안 발표 내용이 뒤에 깔려 있지 않습니다.
class MafiaAnnouncementReveal extends StatefulWidget {
  const MafiaAnnouncementReveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.visibleFor,
  });

  final Widget child;

  /// 이 시간이 지난 뒤에 떠오릅니다.
  final Duration delay;

  /// 떠오르기 시작해서 완전히 물러날 때까지의 시간입니다.
  ///
  /// null이면 물러나지 않고 그대로 남습니다(다음 단계로 넘어갈 때 화면 전환이
  /// 걷어 갑니다).
  final Duration? visibleFor;

  /// 떠오르는 시간입니다.
  ///
  /// 확정(2026-08): 안내 문구 자체가 어몽어스 추방 발표처럼 **내려찍히게**
  /// 되면서([MafiaEjectionText]) 짧게 줄였습니다. 이 겉옷이 천천히 스미면
  /// 글자가 찍히는 순간까지 반투명해 한 방이 죽습니다.
  static const Duration enterDuration = Duration(milliseconds: 260);

  /// 물러나는 시간입니다.
  static const Duration exitDuration = Duration(milliseconds: 380);

  /// 떠오르고 물러날 때 움직이는 폭입니다.
  static const double travel = 10;

  @override
  State<MafiaAnnouncementReveal> createState() =>
      _MafiaAnnouncementRevealState();
}

class _MafiaAnnouncementRevealState extends State<MafiaAnnouncementReveal>
    with TickerProviderStateMixin {
  late final AnimationController _enter;
  late final AnimationController _exit;
  Timer? _delayTimer;
  Timer? _exitTimer;

  /// 아직 차례가 오지 않았거나 이미 물러났으면 false입니다.
  bool _mountedContent = false;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: MafiaAnnouncementReveal.enterDuration,
    );
    _exit = AnimationController(
      vsync: this,
      duration: MafiaAnnouncementReveal.exitDuration,
    )..addStatusListener(_handleExitDone);

    if (widget.delay == Duration.zero) {
      _appear();
    } else {
      _delayTimer = Timer(widget.delay, _appear);
    }
  }

  void _appear() {
    if (!mounted) return;
    setState(() => _mountedContent = true);
    _enter.forward(from: 0);

    final visibleFor = widget.visibleFor;
    if (visibleFor == null) return;
    // 물러나기 시작할 시각입니다. 물러나는 시간까지 합쳐 visibleFor를 지킵니다.
    final untilExit = visibleFor - MafiaAnnouncementReveal.exitDuration;
    _exitTimer = Timer(untilExit.isNegative ? Duration.zero : untilExit, () {
      if (mounted) _exit.forward(from: 0);
    });
  }

  void _handleExitDone(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    setState(() => _mountedContent = false);
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _exitTimer?.cancel();
    _enter.dispose();
    _exit
      ..removeStatusListener(_handleExitDone)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_mountedContent) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: Listenable.merge([_enter, _exit]),
      builder: (context, child) {
        final entered = Curves.easeOutCubic.transform(_enter.value);
        final left = Curves.easeIn.transform(_exit.value);
        // 아래에서 떠올라 들어오고, 위로 물러나며 사라집니다.
        final offset = _exit.value > 0
            ? -MafiaAnnouncementReveal.travel * left
            : MafiaAnnouncementReveal.travel * (1 - entered);
        return Opacity(
          opacity: (entered * (1 - left)).clamp(0.0, 1.0),
          child: Transform.translate(offset: Offset(0, offset), child: child),
        );
      },
      child: widget.child,
    );
  }
}
