import 'package:flutter/material.dart';
import 'package:game_final_call/game_theme.dart';
import 'package:game_final_call/shared/widgets/party_pop.dart';
import 'package:game_kit/localization/game_locale.dart';

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
                Text(
                  GameLocale.select(
                    ko: '우리 팀 탈락 · 관전 중',
                    en: 'Our team is out · Spectating',
                    zhHans: '我方队伍已淘汰 · 观战中',
                    zhHant: '我方隊伍已淘汰 · 觀戰中',
                  ),
                  style: finalCallPopText(24),
                ),
                const SizedBox(height: 8),
                Text(
                  waitingForResult
                      ? GameLocale.select(
                          ko: '태블릿에서 최종 결과를 확인해 주세요.',
                          en: 'Check the final result on the tablet.',
                          zhHans: '请在平板上查看最终结果。',
                          zhHant: '請在平板上查看最終結果。',
                        )
                      : GameLocale.select(
                          ko: '남은 $remainingTeamCount팀이 경기 중입니다.\n태블릿에서 경기를 지켜봐 주세요.',
                          en: '$remainingTeamCount teams remain.\nWatch the game on the tablet.',
                          zhHans: '还有 $remainingTeamCount 支队伍在比赛。\n请在平板上观看。',
                          zhHant: '還有 $remainingTeamCount 支隊伍在比賽。\n請在平板上觀看。',
                        ),
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
