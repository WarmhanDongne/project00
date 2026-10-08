// [turn_timer.dart] 는 파이널콜에서 사용하는 휴대폰 게임 화면에서 재사용하는 UI를 구성하는 파일이다.
//
// - [Package] : 파이널콜
// - [PhoneWidget] : 휴대폰 게임 화면에서 재사용하는 UI를 구성함
//
// 즉, 플레이어 입력과 상태 표시를 작은 책임으로 나눠 관리하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'package:flutter/material.dart';
import 'package:game_final_call/game_theme.dart';
import 'package:game_final_call/shared/widgets/party_pop.dart';
import 'package:game_kit/shared/widgets/game_turn_countdown.dart';
import 'package:game_kit/shared/widgets/game_turn_countdown_face.dart';

// ============================================================

/// 상단 상태 알약 안의 남은 시간 칩입니다(시안: `0:15`).
///
/// 시간 계산과 초읽기 소리 수명주기는 공용 [GameTurnCountdownFace]가 합니다.
/// 다른 사람 차례에는 소리 없이 [GameTurnCountdown]으로 시간만 셉니다.
/// 이 위젯은 **생김새만** 담당합니다.
class FinalCallTimer extends StatelessWidget {
  const FinalCallTimer({
    super.key,
    required this.deadline,
    this.onTimeout,
    this.withTickSound = true,
    this.dark = true,
  });

  final int deadline;
  final VoidCallback? onTimeout;

  /// 내 차례일 때만 마지막 초읽기 소리를 냅니다.
  final bool withTickSound;

  /// 남색 칩(노란 글자) 또는 연보라 칩(남색 글자)입니다.
  final bool dark;

  /// 화면에 보여 주는 최대 초입니다(턴 제한시간 30초).
  static const int maxSeconds = 30;

  Widget _build(BuildContext context, Duration? remaining) {
    // 올림으로 세어 마지막 1초가 화면에 남습니다(기존 표기 그대로).
    final seconds = ((remaining ?? Duration.zero).inMilliseconds / 1000)
        .ceil()
        .clamp(0, maxSeconds);
    final urgent = seconds <= 5;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        color: dark ? FinalCallColors.ink : FinalCallColors.lilac,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '0:${seconds.toString().padLeft(2, '0')}',
        style: finalCallPopText(
          16,
          color: urgent
              ? FinalCallColors.red
              : dark
              ? FinalCallColors.yellow
              : FinalCallColors.ink,
          height: 1.3,
        ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (withTickSound) {
      return GameTurnCountdownFace(
        expiresAt: deadline,
        onTimeout: onTimeout,
        builder: _build,
      );
    }
    return GameTurnCountdown(
      expiresAt: deadline,
      onTimeout: onTimeout,
      builder: _build,
    );
  }
}
