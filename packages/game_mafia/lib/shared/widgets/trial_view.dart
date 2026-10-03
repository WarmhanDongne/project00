import 'package:flutter/material.dart';
import 'package:game_mafia/shared/models/state_models.dart';

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
    color: const Color(0xFFF6F3E9),
    child: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              defending ? '최후 변론' : '처형 찬반 투표',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Text(
              candidate,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            Text(
              defending
                  ? (isCandidate ? '마지막으로 변론해 주세요' : '변론을 들어 주세요')
                  : '투표권자 과반수가 찬성하면 처형됩니다',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 24),
            if (remainingSeconds != null)
              Text(
                '${remainingSeconds! < 0 ? 0 : remainingSeconds}초',
                style: const TextStyle(fontSize: 32),
              ),
            if (!defending && !isTablet) ...[
              const SizedBox(height: 24),
              if (hasVoted)
                const Text('투표 완료', style: TextStyle(fontSize: 24))
              else if (onVote == null)
                const Text('투표를 기다리고 있습니다', style: TextStyle(fontSize: 20))
              else
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    FilledButton(
                      onPressed: () => onVote!(true),
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('처형 찬성', style: TextStyle(fontSize: 22)),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () => onVote!(false),
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('처형 반대', style: TextStyle(fontSize: 22)),
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
    color: const Color(0xFFF6F3E9),
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$nickname님이 처형되었습니다',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Text(
              faction == null
                  ? '신분은 공개하지 않습니다'
                  : '${{'citizen': '시민 진영', 'mafia': '마피아 진영', 'neutral': '중립'}[faction] ?? '진영 비공개'}입니다',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 26),
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
    color: const Color(0xFFF6F3E9),
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              result.executedUid == null ? '처형 부결' : '처형 가결',
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Text(
              '찬성 ${result.verdictYes} · 반대 ${result.verdictNo}\n기권 ${result.abstainCount}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 26, height: 1.6),
            ),
          ],
        ),
      ),
    ),
  );
}
