// [turn_timer.dart] 서버의 턴 마감 시간을 기준으로
// 휴대폰에 남은 시간을 표시하고 타임아웃을 알리는 파일이다.

// ========================[ import ]==========================
import 'package:flutter/material.dart';
import 'package:game_kit/widgets/game_turn_countdown_face.dart';
// ============================================================

/// 내 턴의 남은 시간입니다(시안: `분.초` 7세그먼트 표시).
///
/// 시간 계산과 초읽기 소리 수명주기는 공용 [GameTurnCountdownFace]가 합니다.
/// 세 게임이 각자 세면 같은 함정(보정 전 0에서 굳는 문제, 남의 차례까지 소리가
/// 새는 문제)을 각자 다시 만들게 됩니다. 이 위젯은 **생김새만** 담당합니다.
class PhoneTimer extends StatelessWidget {
  const PhoneTimer({super.key, required this.expiresAt, this.onTimeout});

  final int expiresAt;
  final VoidCallback? onTimeout;

  @override
  Widget build(BuildContext context) {
    return GameTurnCountdownFace(
      expiresAt: expiresAt,
      onTimeout: onTimeout,
      builder: (context, remaining) => _face(remaining ?? Duration.zero),
    );
  }

  Widget _face(Duration remaining) {
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
