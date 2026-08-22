import 'package:flutter/material.dart';
import 'package:project00/games/shared/sound/countdown_tick_cue.dart';
import 'package:project00/games/shared/widgets/game_turn_countdown.dart';

/// 내 턴의 남은 시간입니다(시안: `분.초` 7세그먼트 표시).
///
/// 시간을 세는 일은 공용 [GameTurnCountdown]이 합니다. 세 게임이 각자 세면
/// 같은 함정(보정 전 0에서 굳는 문제)을 각자 다시 만들게 됩니다. 이 위젯은
/// **생김새와 초읽기 소리만** 담당합니다.
class PhoneTimer extends StatefulWidget {
  const PhoneTimer({super.key, required this.expiresAt, this.onTimeout});

  final int expiresAt;
  final VoidCallback? onTimeout;

  @override
  State<PhoneTimer> createState() => _PhoneTimerState();
}

class _PhoneTimerState extends State<PhoneTimer> {
  /// 마지막 5초 초읽기 소리입니다. 이 위젯은 내 턴에만 그려지므로, 소리도
  /// 지금 패를 내야 하는 사람의 기기에서만 납니다.
  final CountdownTickCue _tickCue = CountdownTickCue();

  @override
  void initState() {
    super.initState();
    _tickCue.schedule(widget.expiresAt);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickCue.attach(context);
  }

  @override
  void didUpdateWidget(PhoneTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expiresAt != oldWidget.expiresAt) {
      _tickCue.schedule(widget.expiresAt);
    }
  }

  @override
  void dispose() {
    // 제한시간 전에 패를 내면 이 위젯이 사라집니다. 초읽기도 그때 멈춰야
    // 다음 사람 차례까지 소리가 이어지지 않습니다.
    _tickCue.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GameTurnCountdown(
      expiresAt: widget.expiresAt,
      onTimeout: widget.onTimeout,
      builder: (context, remaining) => _buildFace(remaining ?? Duration.zero),
    );
  }

  Widget _buildFace(Duration remaining) {
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    final isUrgent = remaining <= const Duration(seconds: 10);

    final formattedMinutes = minutes.toString().padLeft(2, '0');
    final formattedSeconds = seconds.toString().padLeft(2, '0');

    return RepaintBoundary(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isUrgent ? const Color(0xFF2A1010) : const Color(0xFF0F1B14),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isUrgent ? const Color(0xFFB83434) : Colors.black,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: isUrgent ? const Color(0x665E0D0D) : Colors.black54,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 220),
          style: TextStyle(
            fontFamily: 'DigitalTimer',
            color: isUrgent ? const Color(0xFFFF4B4B) : const Color(0xFF5CE3A6),
            fontSize: 28,
            height: 1.1,
            letterSpacing: 2.0,
          ),
          child: Text(
            '$formattedMinutes.$formattedSeconds',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
