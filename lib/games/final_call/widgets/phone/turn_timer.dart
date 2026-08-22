import 'package:flutter/material.dart';
import 'package:project00/games/shared/sound/countdown_tick_cue.dart';
import 'package:project00/games/shared/widgets/game_turn_countdown.dart';

/// 내 턴의 남은 시간입니다(시안: `00:초` 7세그먼트 표시).
///
/// 시간을 세는 일은 공용 [GameTurnCountdown]이 합니다. 세 게임이 각자 세면
/// 같은 함정(보정 전 0에서 굳는 문제)을 각자 다시 만들게 됩니다. 이 위젯은
/// **생김새와 초읽기 소리만** 담당합니다.
class FinalCallTimer extends StatefulWidget {
  const FinalCallTimer({super.key, required this.deadline, this.onTimeout});

  final int deadline;
  final VoidCallback? onTimeout;

  /// 화면에 보여 주는 최대 초입니다(턴 제한시간 30초).
  static const int maxSeconds = 30;

  @override
  State<FinalCallTimer> createState() => _FinalCallTimerState();
}

class _FinalCallTimerState extends State<FinalCallTimer> {
  /// 마지막 5초 초읽기 소리입니다. 이 위젯은 내 턴에만 그려지므로, 소리도
  /// 지금 행동해야 하는 사람의 기기에서만 납니다.
  final CountdownTickCue _tickCue = CountdownTickCue();

  @override
  void initState() {
    super.initState();
    _tickCue.schedule(widget.deadline);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickCue.attach(context);
  }

  @override
  void didUpdateWidget(covariant FinalCallTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deadline != widget.deadline) {
      _tickCue.schedule(widget.deadline);
    }
  }

  @override
  void dispose() {
    // 제한시간 전에 행동을 마치면 이 위젯이 사라집니다. 초읽기도 그때 멈춰야
    // 다음 사람 차례까지 소리가 이어지지 않습니다.
    _tickCue.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GameTurnCountdown(
      expiresAt: widget.deadline,
      onTimeout: widget.onTimeout,
      builder: (context, remaining) {
        // 올림으로 세어 마지막 1초가 화면에 남습니다(기존 표기 그대로).
        final seconds = ((remaining ?? Duration.zero).inMilliseconds / 1000)
            .ceil()
            .clamp(0, FinalCallTimer.maxSeconds);
        return Text(
          '00:${seconds.toString().padLeft(2, '0')}',
          style: TextStyle(
            fontFamily: 'DigitalTimer',
            color: seconds <= 10 ? Colors.red : Colors.black87,
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        );
      },
    );
  }
}
