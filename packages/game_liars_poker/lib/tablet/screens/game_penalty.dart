// [game_penalty.dart] 태블릿에 벌칙 룰렛을 표시하고,
// 결과를 서버에 반영하는 동안의 입력 차단 상태를 구성하는 파일이다.

// ========================[ import ]==========================
import 'package:flutter/material.dart';
import 'package:game_kit/penalty/roulette.dart';

// ============================================================

/// 벌칙 룰렛과 서버 반영 중 상태를 표시합니다.
class LiarsPokerTabletGamePenalty extends StatelessWidget {
  const LiarsPokerTabletGamePenalty({
    super.key,
    required this.attemptCount,
    required this.characterId,
    required this.isResolving,
    required this.onPrepareResult,
    required this.onResult,
  });

  final int attemptCount;
  final String characterId;
  final bool isResolving;
  final Future<RouletteResult?> Function() onPrepareResult;
  final ValueChanged<RouletteResult> onResult;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: AbsorbPointer(
            absorbing: isResolving,
            child: Center(
              child: PenaltyRoulette(
                attemptCount: attemptCount,
                centerCharacterId: characterId,
                onPrepareResult: onPrepareResult,
                onResult: onResult,
              ),
            ),
          ),
        ),

        // 룰렛 결과를 서버에 반영하는 동안에는 위쪽 AbsorbPointer가 입력만
        // 막습니다. 결과가 나온 화면을 로딩 표시로 가리면 연출이 끊겨 보여
        // 별도 스피너나 어두운 막은 그리지 않습니다.
      ],
    );
  }
}
