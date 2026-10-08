import 'package:flutter/material.dart';
import 'package:game_mafia/game_theme.dart';
import 'package:game_mafia/shared/models/state_models.dart';
import 'package:game_mafia/shared/widgets/noir.dart';

/// 서버가 확정한 후보·단계를 두 기기에 똑같이 표시합니다.
class MafiaTrialView extends StatelessWidget {
  const MafiaTrialView({
    super.key,
    required this.candidate,
    required this.defending,
    this.remainingSeconds,
    this.onVote,
    this.hasVoted = false,
    this.isCandidate = false,
    this.isTablet = false,
  });
  final String candidate;
  final bool defending;
  final int? remainingSeconds;
  final ValueChanged<bool>? onVote;
  final bool hasVoted;
  final bool isCandidate;
  final bool isTablet;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: MafiaColors.noirInk,
    child: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              defending ? '최후 변론' : '처형 찬반 투표',
              style: mafiaNoirBody(
                16,
                color: MafiaColors.noirBrass,
                letterSpacing: 6,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              candidate,
              textAlign: TextAlign.center,
              style: mafiaNoirDisplay(isTablet ? 96 : 54),
            ),
            const SizedBox(height: 16),
            Text(
              defending
                  ? (isCandidate ? '마지막으로 변론해 주세요' : '변론을 들어 주세요')
                  : '투표권자 과반수가 찬성하면 처형됩니다',
              textAlign: TextAlign.center,
              style: mafiaNoirBody(20),
            ),
            const SizedBox(height: 24),
            if (remainingSeconds != null)
              Text(
                mafiaNoirClock(remainingSeconds!),
                style: mafiaNoirDisplay(40, color: MafiaColors.noirBrass),
              ),
            if (!defending && !isTablet) ...[
              const SizedBox(height: 24),
              if (hasVoted)
                Text('투표 완료', style: mafiaNoirDisplay(28))
              else if (onVote == null)
                Text('투표를 기다리고 있습니다', style: mafiaNoirBody(20))
              else
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    SizedBox(
                      width: 150,
                      height: 62,
                      child: MafiaNoirButton(
                        label: '처형 찬성',
                        onTap: () => onVote!(true),
                        color: MafiaColors.noirBlood,
                        textColor: MafiaColors.noirPaper,
                        fontSize: 20,
                        letterSpacing: 0,
                      ),
                    ),
                    SizedBox(
                      width: 150,
                      height: 62,
                      child: MafiaNoirButton(
                        label: '처형 반대',
                        onTap: () => onVote!(false),
                        fontSize: 20,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    ),
  );
}

class MafiaLimitedDisclosure extends StatelessWidget {
  const MafiaLimitedDisclosure({
    super.key,
    required this.nickname,
    this.faction,
  });
  final String nickname;
  final String? faction;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: MafiaColors.noirInk,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$nickname님이 처형되었습니다',
              textAlign: TextAlign.center,
              style: mafiaNoirDisplay(34),
            ),
            const SizedBox(height: 24),
            Text(
              faction == null
                  ? '신분은 공개하지 않습니다'
                  : '${{'citizen': '시민 진영', 'mafia': '마피아 진영', 'neutral': '중립'}[faction] ?? '진영 비공개'}입니다',
              textAlign: TextAlign.center,
              style: mafiaNoirBody(24, color: MafiaColors.noirBrass),
            ),
          ],
        ),
      ),
    ),
  );
}

class MafiaVerdictSummary extends StatelessWidget {
  const MafiaVerdictSummary({super.key, required this.result});
  final MafiaVoteResult result;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: MafiaColors.noirInk,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              result.executedUid == null ? '처형 부결' : '처형 가결',
              style: mafiaNoirDisplay(48),
            ),
            const SizedBox(height: 24),
            Text(
              '찬성 ${result.verdictYes} · 반대 ${result.verdictNo}\n기권 ${result.abstainCount}',
              textAlign: TextAlign.center,
              style: mafiaNoirBody(
                24,
                color: MafiaColors.noirBrass,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
