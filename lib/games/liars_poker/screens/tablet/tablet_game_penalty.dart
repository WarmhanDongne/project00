import 'package:flutter/material.dart';
import 'package:project00/games/penalty/roulette.dart';

/// 벌칙 룰렛과 서버 반영 중 상태를 표시합니다.
class TabletGamePenalty extends StatelessWidget {
  const TabletGamePenalty({
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
                '벌칙 진행 중',
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
        if (isResolving)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x66000000),
              child: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
}
