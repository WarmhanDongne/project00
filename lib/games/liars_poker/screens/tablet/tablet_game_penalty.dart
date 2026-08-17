import 'package:flutter/material.dart';
import 'package:project00/games/liars_poker/liars_poker_copy.dart';
import 'package:project00/games/penalty/roulette.dart';

/// 벌칙 룰렛과 서버 반영 중 상태를 표시합니다.
class LiarsPokerTabletGamePenalty extends StatelessWidget {
  const LiarsPokerTabletGamePenalty({
    super.key,
    required this.attemptCount,
    required this.profileImageUrl,
    required this.isResolving,
    required this.onResult,
  });

  final int attemptCount;
  final String profileImageUrl;
  final bool isResolving;
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
                centerProfileImageUrl: profileImageUrl,
                onResult: onResult,
              ),
            ),
          ),
        ),
        const Positioned(
          top: 25,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Center(
              child: Text(
                LiarsPokerCopy.penaltyTitle,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  shadows: [
                    Shadow(
                      color: Colors.black,
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
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
