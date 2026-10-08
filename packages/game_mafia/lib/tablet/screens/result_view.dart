// [result_view.dart] 는 마피아에서 사용하는 태블릿에서 보이는 공용 게임 진행 화면을 구성하는 파일이다.
//
// - [Package] : 마피아
// - [TabletScreen] : 태블릿에서 보이는 공용 게임 진행 화면을 구성함
//
// 즉, 모든 플레이어가 함께 보는 진행 상태와 연출을 표시하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'package:flutter/material.dart';
import 'package:game_mafia/shared/widgets/result_art.dart';
import 'package:game_mafia/shared/models/player.dart';
import 'package:game_mafia/shared/models/role.dart';
import 'package:game_mafia/tablet/screens/game_layout.dart';
import 'package:game_mafia/game_theme.dart';
import 'package:game_mafia/shared/animations/announcement_reveal.dart';
import 'package:game_mafia/shared/widgets/noir.dart';

// ============================================================

// ---------------------------------------------------------------------------
// 태블릿 결과 화면
// ---------------------------------------------------------------------------
/// 승리 진영을 알리고 전원 신분을 공개합니다(시안 `tablet-p9`).
///
/// 확정된 순서(2026-08):
///
/// | 박자 | 내용 |
/// |---|---|
/// | 1 | 승리 배경만 화면을 덮습니다. 문구·버튼 없음 |
/// | 2 | **2초 뒤 또는 화면을 누르면** 인물 그림과 흰 판이 올라옵니다 |
/// | 3 | 신분 카드가 **한 장씩 차례로** 뒷면으로 놓입니다 |
/// | 4 | 놓인 순서대로(앞 카드부터) **뒤집혀 신분이 드러납니다** |
///
/// 카드는 자리 순서대로 놓습니다. 진영별로 묶지 않는 이유는, 뒤집기 전에
/// 자리만 보고 진영을 짐작할 수 있으면 공개하는 재미가 사라지기 때문입니다.
class MafiaTabletResultView extends StatelessWidget {
  const MafiaTabletResultView({
    super.key,
    required this.winner,
    this.winnerRoleIds = const {},
    this.winnerLabel,
    required this.players,
    required this.revealedRoles,
    this.winnerUids = const {},
    this.onRestart,
    this.onHome,
  });

  final MafiaFaction? winner;
  final Set<String> winnerRoleIds;

  /// 결과 제목입니다(예: `마피아 승리`, `광대 승리`).
  final String? winnerLabel;
  final Map<String, MafiaPlayer> players;

  /// 게임이 끝나 전원 공개된 신분입니다.
  final Map<String, MafiaRole?> revealedRoles;

  /// 이긴 사람입니다. 명단에 `승리` 꼬리표가 붙습니다.
  final Set<String> winnerUids;
  final VoidCallback? onRestart;
  final VoidCallback? onHome;

  /// 이긴 쪽의 대표 신분입니다(왼쪽 포스터 카드).
  MafiaRole? get _posterRole {
    for (final uid in winnerUids) {
      final role = revealedRoles[uid];
      if (role != null) return role;
    }
    return null;
  }

  String get _reason => switch (winner) {
    MafiaFaction.mafia => '마피아 수가 남은 사람 수와 같아졌습니다',
    MafiaFaction.citizen => '마피아가 모두 사라졌습니다',
    MafiaFaction.neutral => '홀로 목표를 이뤘습니다',
    null => '게임이 끝났습니다',
  };

  @override
  Widget build(BuildContext context) {
    final ordered = players.values.toList()
      ..sort((a, b) {
        // 이긴 사람 → 살아 있는 사람 → 떠난 사람 순입니다(시안).
        int rank(MafiaPlayer player) => winnerUids.contains(player.uid)
            ? 0
            : player.isAlive
            ? 1
            : 2;
        final byRank = rank(a).compareTo(rank(b));
        return byRank != 0 ? byRank : a.seatIndex.compareTo(b.seatIndex);
      });
    final card = _posterRole?.card;
    final label = winnerLabel ?? MafiaResultArt.label(winner);
    final rowHeight = (600 / ordered.length.clamp(1, 99)).clamp(40.0, 66.0);
    return Stack(
      fit: StackFit.expand,
      children: [
        const MafiaNoirRays.blood(origin: Alignment(-0.48, -0.08)),
        // 승리 포스터
        MafiaTabletBox(
          rect: const Rect.fromLTWH(110, 150, 400, 400),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: winner == MafiaFaction.citizen
                  ? MafiaColors.noirTeal
                  : MafiaColors.noirBlood,
              shape: BoxShape.circle,
            ),
          ),
        ),
        if (card != null)
          MafiaTabletBox(
            rect: const Rect.fromLTWH(170, 92, 280, 411),
            child: MafiaAnnouncementReveal(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: MafiaColors.noirBrass, width: 3),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0xB3000000),
                      blurRadius: 50,
                      offset: Offset(0, 24),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: card.image(fit: BoxFit.cover),
                ),
              ),
            ),
          ),
        MafiaTabletBox(
          rect: const Rect.fromLTWH(50, 560, 520, 170),
          child: Column(
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(label, style: mafiaNoirDisplay(96, height: 1)),
              ),
              const SizedBox(height: 10),
              Container(
                width: 440,
                height: 12,
                color: winner == MafiaFaction.citizen
                    ? MafiaColors.noirTeal
                    : MafiaColors.noirBlood,
              ),
              const SizedBox(height: 10),
              Text(_reason, style: mafiaNoirBody(17)),
            ],
          ),
        ),
        // 모든 신분 공개
        MafiaTabletBox(
          rect: const Rect.fromLTWH(640, 70, 500, 30),
          child: Text(
            '모든 신분 공개',
            style: mafiaNoirBody(
              14,
              color: MafiaColors.noirBrass,
              letterSpacing: 7,
            ),
          ),
        ),
        for (var index = 0; index < ordered.length; index++)
          MafiaTabletBox(
            rect: Rect.fromLTWH(
              640,
              106 + index * rowHeight,
              500,
              rowHeight - 6,
            ),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: Duration(milliseconds: 380 + index * 90),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) => Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(30 * (1 - value), 0),
                  child: child,
                ),
              ),
              child: _ResultRow(
                player: ordered[index],
                role: revealedRoles[ordered[index].uid],
                won: winnerUids.contains(ordered[index].uid),
              ),
            ),
          ),
        MafiaTabletBox(
          rect: const Rect.fromLTWH(640, 730, 500, 60),
          ignorePointer: false,
          child: Row(
            children: [
              Expanded(
                child: _ResultButton(
                  label: '한 판 더',
                  filled: true,
                  onTap: onRestart,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _ResultButton(
                  label: '로비로',
                  filled: false,
                  onTap: onHome,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.player,
    required this.role,
    required this.won,
  });

  final MafiaPlayer player;
  final MafiaRole? role;
  final bool won;

  @override
  Widget build(BuildContext context) {
    final mafia = role?.faction.isMafia ?? false;
    final death = player.isAlive
        ? null
        : player.wasExecuted
        ? '처형'
        : player.diedAtNight
        ? '사망'
        : '퇴장';
    final roleText = role?.displayName ?? '알 수 없음';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: won ? const Color(0xFF2A1512) : Colors.transparent,
        border: won
            ? Border.all(color: MafiaColors.noirBlood)
            : const Border(bottom: BorderSide(color: Color(0xFF2A2F2C))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: MafiaNoirFace(player: player, grayscale: !player.isAlive),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              player.nickname,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: mafiaNoirDisplay(
                22,
                color: won || player.isAlive
                    ? MafiaColors.noirPaper
                    : MafiaColors.noirDust,
              ),
            ),
          ),
          Text(
            death == null ? roleText : '$roleText · $death',
            style: mafiaNoirBody(
              15,
              color: won && mafia
                  ? MafiaColors.noirRose
                  : won
                  ? MafiaColors.noirPaper
                  : MafiaColors.noirDust,
              weight: won ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
          if (won) ...[
            const SizedBox(width: 10),
            Container(
              color: MafiaColors.noirBrass,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
              child: Text(
                '승리',
                style: mafiaNoirBody(
                  13,
                  color: MafiaColors.noirInk,
                  weight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ResultButton extends StatelessWidget {
  const _ResultButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final bool filled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    label: label,
    excludeSemantics: true,
    onTap: onTap,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: onTap == null ? 0.45 : 1,
        duration: const Duration(milliseconds: 200),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: filled ? MafiaColors.noirPaper : Colors.transparent,
            border: filled
                ? null
                : Border.all(color: MafiaColors.noirBrass, width: 2),
          ),
          child: Text(
            label,
            style: mafiaNoirDisplay(
              22,
              color: filled ? MafiaColors.noirInk : MafiaColors.noirBrass,
              letterSpacing: 1.8,
            ),
          ),
        ),
      ),
    ),
  );
}
