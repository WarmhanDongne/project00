// [penalty_panels.dart] 태블릿 벌칙 단계에서 각 자리 쪽을 향해 띄우는
// 안내판과 룰렛 결과(생존·탈락) 화면을 그리는 파일이다.

// ========================[ import ]==========================
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:game_kit/player_layouts/services/player_slot_positions.dart';
import 'package:game_liars_poker/game_copy.dart';
import 'package:game_liars_poker/game_theme.dart';
import 'package:game_liars_poker/shared/widgets/noir_ui.dart';
import 'package:game_liars_poker/tablet/widgets/seat_plate.dart';

// ============================================================

/// 벌칙 단계의 자리 배치와 대상입니다.
@immutable
class TabletPenaltyLayout {
  const TabletPenaltyLayout({
    required this.seats,
    required this.seatIndexes,
    required this.targetIndex,
  });

  /// 자리 배치 순서대로의 공개 정보입니다.
  final List<TabletSeatInfo> seats;
  final List<int> seatIndexes;
  final int targetIndex;

  TabletSeatInfo get target => seats[targetIndex];
}

String _roundName(int penaltyCount) => switch (penaltyCount) {
  <= 0 => '첫 번째',
  1 => '두 번째',
  _ => '세 번째',
};

/// 자리 순서마다 자리판 중심과 회전을 계산해 [builder]의 안내판을 놓습니다.
class TabletSeatAnchors extends StatelessWidget {
  const TabletSeatAnchors({
    super.key,
    required this.layout,
    required this.builder,
  });

  final TabletPenaltyLayout layout;
  final Widget? Function(int index, TabletSeatInfo seat) builder;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      final unit = tabletDesignScale(size);
      final centers = playerCentersForBoard(
        playerCount: layout.seats.length,
        boardSize: size,
        radiusFactor: defaultPlayerOrbitRadiusFactor,
      );
      return Stack(
        clipBehavior: Clip.none,
        children: [
          for (var index = 0; index < layout.seats.length; index++)
            if (builder(index, layout.seats[index]) case final child?)
              () {
                // 대상 안내판(420×130)은 자리판보다 넓어 그 크기로 화면 안에 맞춥니다.
                final anchor = tabletSeatCenter(
                  size,
                  centers[layout.seatIndexes[index]],
                  plateSize: index == layout.targetIndex
                      ? const Size(430, 150)
                      : TabletSeatPlate.size,
                );
                // 대상 안내판(420)도 들어가도록 자리판보다 넓은 칸을 씁니다.
                const box = Size(440, 170);
                return Positioned(
                  left: anchor.dx - box.width * unit / 2,
                  top: anchor.dy - box.height * unit / 2,
                  width: box.width * unit,
                  height: box.height * unit,
                  child: Transform.rotate(
                    angle: tabletSeatRotation(size, anchor),
                    child: FittedBox(
                      child: SizedBox.fromSize(
                        size: box,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: child,
                        ),
                      ),
                    ),
                  ),
                );
              }(),
        ],
      );
    },
  );
}

/// 이름과 한 줄 안내가 있는 300×110 안내판입니다.
class TabletSeatNotice extends StatelessWidget {
  const TabletSeatNotice({
    super.key,
    required this.seat,
    required this.message,
    this.eliminated = false,
  });

  final TabletSeatInfo seat;
  final InlineSpan message;
  final bool eliminated;

  @override
  Widget build(BuildContext context) => Container(
    width: 300,
    height: 110,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: eliminated ? LiarsPokerColors.redPanel : LiarsPokerColors.panel,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: eliminated ? LiarsPokerColors.red : LiarsPokerColors.panelEdge,
        width: eliminated ? 3 : 2,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            NoirAvatar(
              characterId: seat.characterId,
              size: 44,
              ringColor: eliminated
                  ? LiarsPokerColors.dim
                  : LiarsPokerColors.ivory,
              ringWidth: 3,
              grayscale: eliminated,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                eliminated ? '탈락했습니다' : seat.nickname,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: eliminated
                    ? LiarsPokerFonts.headline(
                        size: 22,
                        color: LiarsPokerColors.pink,
                      )
                    : LiarsPokerFonts.text(size: 17, weight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const Spacer(),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: eliminated
                    ? LiarsPokerColors.redEdge
                    : LiarsPokerColors.panelEdge,
              ),
            ),
          ),
          child: Text.rich(
            message,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: LiarsPokerFonts.text(
              size: 14,
              color: eliminated
                  ? LiarsPokerColors.ivory
                  : LiarsPokerColors.mutedLight,
            ),
          ),
        ),
      ],
    ),
  );
}

/// 룰렛을 돌리는 사람 앞의 확률·레버 안내판(420×130)입니다.
class TabletTargetNotice extends StatelessWidget {
  const TabletTargetNotice({super.key, required this.seat});

  final TabletSeatInfo seat;

  @override
  Widget build(BuildContext context) {
    final odds = liarsPokerRouletteOdds(seat.penaltyCount);
    final survival = ((odds.total - odds.bad) / odds.total * 100).round();
    return Container(
      width: 420,
      height: 130,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: LiarsPokerColors.panelRaised,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: LiarsPokerColors.red, width: 3),
        boxShadow: [
          BoxShadow(
            color: LiarsPokerColors.red.withValues(alpha: .35),
            blurRadius: 40,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              NoirAvatar(
                characterId: seat.characterId,
                size: 48,
                ringColor: LiarsPokerColors.red,
                ringWidth: 3,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${seat.nickname} · ${_roundName(seat.penaltyCount)} 룰렛',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: LiarsPokerFonts.text(
                        size: 18,
                        weight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '옆의 레버를 당기세요',
                      style: LiarsPokerFonts.text(
                        size: 13,
                        weight: FontWeight.w700,
                        color: LiarsPokerColors.pinkLight,
                      ),
                    ),
                  ],
                ),
              ),
              Semantics(
                label: '생존 확률 $survival퍼센트',
                excludeSemantics: true,
                child: Text(
                  '$survival%',
                  style: LiarsPokerFonts.western(size: 28),
                ),
              ),
            ],
          ),
          const Spacer(),
          NoirOddsLadder(
            penaltyCount: seat.penaltyCount,
            edgeColor: LiarsPokerColors.dim,
          ),
        ],
      ),
    );
  }
}

/// 룰렛이 도는 동안 각 자리 쪽에 띄우는 안내입니다.
class TabletRouletteNotices extends StatelessWidget {
  const TabletRouletteNotices({super.key, required this.layout});

  final TabletPenaltyLayout layout;

  @override
  Widget build(BuildContext context) {
    final target = layout.target;
    return IgnorePointer(
      child: TabletSeatAnchors(
        layout: layout,
        builder: (index, seat) {
          if (seat.eliminated) return null;
          if (index == layout.targetIndex) {
            return TabletTargetNotice(seat: seat);
          }
          return TabletSeatNotice(
            seat: seat,
            message: TextSpan(
              children: [
                TextSpan(
                  text: target.nickname,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: LiarsPokerColors.ivory,
                  ),
                ),
                TextSpan(
                  text:
                      '${liarsPokerSubjectParticle(target.nickname)} 룰렛을 돌려요 · 탈락 ',
                ),
                TextSpan(
                  text: liarsPokerOddsLabel(target.penaltyCount),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: LiarsPokerColors.pink,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 룰렛 결과
// ---------------------------------------------------------------------------
/// 룰렛 결과입니다. 가운데에는 방향 없는 기호만 두고, 문구는 자리마다 돌립니다.
class TabletRouletteResult extends StatefulWidget {
  const TabletRouletteResult({
    super.key,
    required this.layout,
    required this.eliminated,
  });

  /// 결과가 반영된 뒤의 자리 정보입니다(생존이면 룰렛 단계가 하나 오름).
  final TabletPenaltyLayout layout;
  final bool eliminated;

  @override
  State<TabletRouletteResult> createState() => _TabletRouletteResultState();
}

class _TabletRouletteResultState extends State<TabletRouletteResult>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entry = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  )..forward();

  @override
  void dispose() {
    _entry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layout = widget.layout;
    final target = layout.target;
    final eliminated = widget.eliminated;
    final aliveCount = layout.seats.where((seat) => !seat.eliminated).length;
    final headline = '${target.nickname} ${eliminated ? '탈락' : '생존!'}';
    final odds = liarsPokerRouletteOdds(target.penaltyCount);
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final unit = tabletDesignScale(constraints.biggest);
          return AnimatedBuilder(
            animation: _entry,
            builder: (context, _) {
              final t = Curves.easeOutBack.transform(_entry.value);
              return Stack(
                fit: StackFit.expand,
                children: [
                  if (!eliminated)
                    Opacity(
                      opacity: _entry.value,
                      child: const CustomPaint(painter: _RaysPainter()),
                    ),
                  Center(
                    child: Transform.scale(
                      scale: .7 + .3 * t,
                      child: SizedBox(
                        width: 300 * unit,
                        height: 330 * unit,
                        child: FittedBox(
                          child: _CenterMark(
                            seat: target,
                            eliminated: eliminated,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Opacity(
                    opacity: _entry.value,
                    child: TabletSeatAnchors(
                      layout: layout,
                      builder: (index, seat) {
                        if (index == layout.targetIndex) {
                          if (eliminated) {
                            return TabletSeatNotice(
                              seat: seat,
                              eliminated: true,
                              message: const TextSpan(
                                text: '이제 휴대폰에서 관전할 수 있어요',
                              ),
                            );
                          }
                          return _SurvivorNotice(
                            seat: seat,
                            odds: '${odds.total}칸 중 ${odds.bad}칸',
                          );
                        }
                        if (seat.eliminated) return null;
                        return TabletSeatNotice(
                          seat: seat,
                          message: TextSpan(
                            children: [
                              TextSpan(
                                text: headline,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: eliminated
                                      ? LiarsPokerColors.pink
                                      : LiarsPokerColors.goldLight,
                                ),
                              ),
                              TextSpan(
                                text: eliminated
                                    ? ' · 남은 사람 $aliveCount명'
                                    : ' · 다음 라운드를 시작해요',
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _CenterMark extends StatelessWidget {
  const _CenterMark({required this.seat, required this.eliminated});

  final TabletSeatInfo seat;
  final bool eliminated;

  @override
  Widget build(BuildContext context) {
    final filled = eliminated ? 2 : seat.penaltyCount.clamp(0, 3);
    return SizedBox(
      width: 300,
      height: 330,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 30,
            top: 10,
            child: Opacity(
              opacity: eliminated ? .6 : 1,
              child: NoirAvatar(
                characterId: seat.characterId,
                size: 240,
                ringColor: eliminated
                    ? LiarsPokerColors.dim
                    : LiarsPokerColors.gold,
                ringWidth: 8,
                glowColor: eliminated
                    ? null
                    : LiarsPokerColors.gold.withValues(alpha: .4),
                grayscale: eliminated,
              ),
            ),
          ),
          Positioned(
            left: 200,
            top: 0,
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: eliminated
                    ? LiarsPokerColors.red
                    : LiarsPokerColors.gold,
                border: Border.all(color: LiarsPokerColors.night, width: 6),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x80000000),
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                eliminated ? Icons.close_rounded : Icons.check_rounded,
                size: 40,
                color: eliminated ? Colors.white : LiarsPokerColors.night,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var index = 0; index < 3; index++) ...[
                  if (index > 0) const SizedBox(width: 10),
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: eliminated && index == 2
                          ? LiarsPokerColors.red
                          : index < filled
                          ? LiarsPokerColors.gold
                          : null,
                      border: index < filled || (eliminated && index == 2)
                          ? null
                          : Border.all(color: LiarsPokerColors.dim, width: 3),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SurvivorNotice extends StatelessWidget {
  const _SurvivorNotice({required this.seat, required this.odds});

  final TabletSeatInfo seat;
  final String odds;

  @override
  Widget build(BuildContext context) => Container(
    width: 300,
    height: 110,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: LiarsPokerColors.panelRaised,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: LiarsPokerColors.gold, width: 3),
      boxShadow: [
        BoxShadow(
          color: LiarsPokerColors.gold.withValues(alpha: .25),
          blurRadius: 40,
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            NoirAvatar(
              characterId: seat.characterId,
              size: 44,
              ringColor: LiarsPokerColors.gold,
              ringWidth: 3,
            ),
            const SizedBox(width: 10),
            Text(
              '살아남았다!',
              style: LiarsPokerFonts.headline(
                size: 22,
                color: LiarsPokerColors.goldLight,
              ),
            ),
          ],
        ),
        const Spacer(),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.only(top: 6),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: LiarsPokerColors.panelEdge)),
          ),
          child: Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: '내 다음 룰렛은 '),
                TextSpan(
                  text: odds,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: LiarsPokerColors.pink,
                  ),
                ),
              ],
            ),
            style: LiarsPokerFonts.text(
              size: 14,
              color: LiarsPokerColors.mutedLight,
            ),
          ),
        ),
      ],
    ),
  );
}

class _RaysPainter extends CustomPainter {
  const _RaysPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.longestSide;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()..color = LiarsPokerColors.gold.withValues(alpha: .09);
    const step = 15 * math.pi / 180;
    const ray = 6 * math.pi / 180;
    for (var angle = 0.0; angle < math.pi * 2; angle += step) {
      canvas.drawArc(rect, angle, ray, true, paint);
    }
  }

  @override
  bool shouldRepaint(_RaysPainter oldDelegate) => false;
}
