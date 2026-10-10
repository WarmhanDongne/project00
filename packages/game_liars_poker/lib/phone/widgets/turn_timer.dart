// [turn_timer.dart] 서버의 턴 마감 시간을 기준으로
// 휴대폰에 남은 시간을 표시하고 타임아웃을 알리는 파일이다.

// ========================[ import ]==========================
import 'package:flutter/material.dart';
import 'package:game_kit/shared/widgets/game_turn_countdown_face.dart';
import 'package:game_liars_poker/shared/widgets/noir_ui.dart';

// ============================================================

/// 내 턴의 남은 시간을 큰 원형 링으로 보여 줍니다.
///
/// 시간 계산과 초읽기 소리 수명주기는 공용 [GameTurnCountdownFace]가 합니다.
/// 세 게임이 각자 세면 같은 함정(보정 전 0에서 굳는 문제, 남의 차례까지 소리가
/// 새는 문제)을 각자 다시 만들게 됩니다. 이 위젯은 **생김새만** 담당합니다.
class PhoneTimer extends StatelessWidget {
  const PhoneTimer({
    super.key,
    required this.expiresAt,
    required this.window,
    this.onTimeout,
    this.size = 128,
  });

  final int expiresAt;

  /// 이번 차례에 주어진 전체 시간입니다. 링의 남은 비율을 계산합니다.
  final Duration window;
  final VoidCallback? onTimeout;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GameTurnCountdownFace(
      expiresAt: expiresAt,
      onTimeout: onTimeout,
      builder: (context, remaining) {
        final left = remaining ?? Duration.zero;
        return RepaintBoundary(
          child: NoirTimerRing(
            size: size,
            seconds: (left.inMilliseconds / 1000).ceil(),
            fraction: left.inMilliseconds / window.inMilliseconds,
          ),
        );
      },
    );
  }
}
