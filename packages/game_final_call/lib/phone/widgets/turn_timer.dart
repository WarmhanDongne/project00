// [turn_timer.dart] 는 파이널콜에서 사용하는 휴대폰 게임 화면에서 재사용하는 UI를 구성하는 파일이다.
//
// - [Package] : 파이널콜
// - [PhoneWidget] : 휴대폰 게임 화면에서 재사용하는 UI를 구성함
//
// 즉, 플레이어 입력과 상태 표시를 작은 책임으로 나눠 관리하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'package:flutter/material.dart';
import 'package:game_kit/shared/widgets/game_turn_countdown_face.dart';

// ============================================================

/// 내 턴의 남은 시간입니다(시안: `00:초` 7세그먼트 표시).
///
/// 시간 계산과 초읽기 소리 수명주기는 공용 [GameTurnCountdownFace]가 합니다.
/// 이 위젯은 **생김새만** 담당합니다.
class FinalCallTimer extends StatelessWidget {
  const FinalCallTimer({super.key, required this.deadline, this.onTimeout});

  final int deadline;
  final VoidCallback? onTimeout;

  /// 화면에 보여 주는 최대 초입니다(턴 제한시간 30초).
  static const int maxSeconds = 30;

  @override
  Widget build(BuildContext context) {
    return GameTurnCountdownFace(
      expiresAt: deadline,
      onTimeout: onTimeout,
      builder: (context, remaining) {
        // 올림으로 세어 마지막 1초가 화면에 남습니다(기존 표기 그대로).
        final seconds = ((remaining ?? Duration.zero).inMilliseconds / 1000)
            .ceil()
            .clamp(0, maxSeconds);
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
