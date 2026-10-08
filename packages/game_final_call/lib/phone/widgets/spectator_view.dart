import 'package:flutter/material.dart';
import 'package:game_final_call/game_theme.dart';
import 'package:game_final_call/shared/widgets/party_pop.dart';

/// 탈락자는 손패를 기다리지 않고 남은 팀의 경기를 관전합니다.
class FinalCallSpectatorView extends StatelessWidget {
  const FinalCallSpectatorView({
    super.key,
    required this.remainingTeamCount,
    required this.waitingForResult,
  });

  final int remainingTeamCount;
  final bool waitingForResult;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 60, 24, 20),
        child: Center(
          child: FinalCallPopBox(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.visibility_outlined,
                  size: 40,
                  color: FinalCallColors.violet,
                ),
                const SizedBox(height: 12),
                Text('우리 팀 탈락 · 관전 중', style: finalCallPopText(24)),
                const SizedBox(height: 8),
                Text(
                  waitingForResult
                      ? '태블릿에서 최종 결과를 확인해 주세요.'
                      : '남은 $remainingTeamCount팀이 경기 중입니다.\n태블릿에서 경기를 지켜봐 주세요.',
                  textAlign: TextAlign.center,
                  style: finalCallPopText(16, color: FinalCallColors.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
