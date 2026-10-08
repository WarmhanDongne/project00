// [day_view.dart] 는 마피아에서 사용하는 태블릿 낮 토론·투표 화면을 구성하는 파일이다.
//
// - [Package] : 마피아
// - [TabletScreen] : 낮 토론(사망 소식·토론 타이머)과 비밀 투표(투표함)를 구성함
//
// 즉, 테이블에 둘러앉은 모두가 낮의 진행 상황을 함께 보기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:game_mafia/game_theme.dart';
import 'package:game_mafia/shared/models/player.dart';
import 'package:game_mafia/shared/models/role.dart';
import 'package:game_mafia/shared/widgets/noir.dart';
import 'package:game_mafia/tablet/screens/game_layout.dart';
import 'package:game_mafia/tablet/screens/noir_table.dart';

// ============================================================

/// 태블릿 낮 화면입니다(시안 태블릿 ⑤ 낮 토론 · ⑥ 투표 중).
///
/// 토론과 투표가 **같은 위젯**이라, 투표가 시작되면 토론 타이머가 투표함으로
/// 겹쳐 바뀝니다. 화면 전체가 새로 그려지는 느낌 없이 이어집니다.
class MafiaTabletDayView extends StatelessWidget {
  const MafiaTabletDayView({
    super.key,
    required this.showBallotBox,
    this.remainingSeconds,
    this.voteSubmittedUids = const [],
    this.voteEligibleCount = 0,
    this.players = const [],
    this.lastNightDead = const [],
    this.revealedRoles = const {},
    this.round = 0,
    this.discussionSkipCount = 0,
  });

  /// 투표 중인지입니다.
  final bool showBallotBox;
  final int? remainingSeconds;

  /// 투표를 마친 사람입니다(어디에 냈는지는 모릅니다).
  final List<String> voteSubmittedUids;
  final int voteEligibleCount;

  /// 자리 순서대로 모든 참가자입니다.
  final List<MafiaPlayer> players;

  /// 어젯밤 쓰러진 사람입니다(왼쪽 소식 포스터).
  final List<MafiaPlayer> lastNightDead;

  /// 모두에게 공개된 신분입니다(처형된 사람 카드).
  final Map<String, MafiaRole?> revealedRoles;
  final int round;

  /// 토론 끝내기에 동의한 인원입니다.
  final int discussionSkipCount;

  static const Duration _crossFade = Duration(milliseconds: 520);

  /// 투표함 자리입니다(시안 태블릿 ⑥).
  static const Rect ballotBox = Rect.fromLTWH(447, 236, 300, 230);

  /// 남은 시간을 `2:30`처럼 적습니다.
  static String formatTabletTimer(int seconds) => mafiaNoirClock(seconds);

  @override
  Widget build(BuildContext context) {
    final alive = players.where((player) => player.isAlive).toList();
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedOpacity(
          opacity: showBallotBox ? 0 : 1,
          duration: _crossFade,
          curve: Curves.easeOut,
          child: IgnorePointer(
            ignoring: showBallotBox,
            child: _DiscussionLayer(
              players: players,
              aliveCount: alive.length,
              lastNightDead: lastNightDead,
              revealedRoles: revealedRoles,
              round: round,
              seconds: showBallotBox ? null : remainingSeconds,
              skipCount: discussionSkipCount,
            ),
          ),
        ),
        AnimatedOpacity(
          opacity: showBallotBox ? 1 : 0,
          duration: _crossFade,
          curve: Curves.easeOut,
          child: showBallotBox
              ? _VotingLayer(
                  alive: alive,
                  round: round,
                  seconds: remainingSeconds,
                  submittedUids: voteSubmittedUids,
                  eligibleCount: voteEligibleCount == 0
                      ? alive.length
                      : voteEligibleCount,
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 낮 토론
// ---------------------------------------------------------------------------
class _DiscussionLayer extends StatelessWidget {
  const _DiscussionLayer({
    required this.players,
    required this.aliveCount,
    required this.lastNightDead,
    required this.revealedRoles,
    required this.round,
    required this.seconds,
    required this.skipCount,
  });

  final List<MafiaPlayer> players;
  final int aliveCount;
  final List<MafiaPlayer> lastNightDead;
  final Map<String, MafiaRole?> revealedRoles;
  final int round;
  final int? seconds;
  final int skipCount;

  @override
  Widget build(BuildContext context) {
    final first = lastNightDead.firstOrNull;
    final names = lastNightDead.map((player) => player.nickname).join(' · ');
    final seconds = this.seconds;
    // 과반수가 동의하면 토론이 끝납니다(서버 규칙). 칸 수는 그 기준입니다.
    final needed = aliveCount ~/ 2 + 1;
    return Stack(
      fit: StackFit.expand,
      children: [
        // 사망 소식 포스터
        MafiaTabletBox(
          rect: const Rect.fromLTWH(150, 70, 300, 300),
          child: const DecoratedBox(
            decoration: BoxDecoration(
              color: MafiaColors.noirTeal,
              shape: BoxShape.circle,
            ),
          ),
        ),
        if (first != null)
          MafiaTabletBox(
            rect: const Rect.fromLTWH(165, 85, 270, 270),
            child: MafiaNoirFace(player: first, grayscale: true),
          ),
        MafiaTabletBox(
          rect: const Rect.fromLTWH(60, 330, 520, 120),
          child: ClipPath(
            clipper: const _BandClipper(),
            child: const ColoredBox(color: MafiaColors.noirInk),
          ),
        ),
        MafiaTabletBox(
          rect: const Rect.fromLTWH(90, 378, 480, 48),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              first == null
                  ? '어젯밤은 조용히 지나갔다'
                  : '어젯밤, ${mafiaJosa(names, '이', '가')} 쓰러졌다',
              style: mafiaNoirDisplay(44, height: 1),
            ),
          ),
        ),
        MafiaTabletBox(
          rect: const Rect.fromLTWH(92, 462, 520, 26),
          child: Text(
            '범인은 아직 이 테이블에 있다 · 생존 $aliveCount명',
            style: mafiaNoirBody(17, color: const Color(0xFF3B3A33)),
          ),
        ),
        // 토론 타이머
        MafiaTabletBox(
          rect: const Rect.fromLTWH(650, 70, 470, 380),
          child: MafiaNoirFrame(
            inset: 11,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  round > 0 ? '$round일째 낮 · 토론' : '토론',
                  style: mafiaNoirBody(
                    20,
                    color: MafiaColors.noirBrass,
                    letterSpacing: 6,
                  ),
                ),
                Text(
                  seconds == null ? '' : mafiaNoirClock(seconds),
                  style: mafiaNoirDisplay(
                    156,
                    height: 1,
                    color: seconds != null && seconds < 30
                        ? MafiaColors.noirRose
                        : MafiaColors.noirPaper,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '토론 끝내기 동의',
                      style: mafiaNoirBody(18, color: MafiaColors.noirPaper),
                    ),
                    const SizedBox(width: 12),
                    for (var index = 0; index < needed; index++)
                      Padding(
                        padding: const EdgeInsets.only(right: 5),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 260),
                          width: 18,
                          height: 26,
                          decoration: BoxDecoration(
                            color: index < skipCount
                                ? MafiaColors.noirBrass
                                : Colors.transparent,
                            border: Border.all(
                              color: index < skipCount
                                  ? MafiaColors.noirBrass
                                  : MafiaColors.noirFaded,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(width: 7),
                    Text(
                      '$skipCount / $aliveCount',
                      style: mafiaNoirDisplay(24, color: MafiaColors.noirBrass),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        MafiaTabletBox(
          rect: const Rect.fromLTWH(0, 498, 1194, 3),
          child: const ColoredBox(color: MafiaColors.noirInk),
        ),
        MafiaTabletPlayerRow(
          players: players,
          top: 534,
          revealedRoles: revealedRoles,
        ),
      ],
    );
  }
}

class _BandClipper extends CustomClipper<Path> {
  const _BandClipper();

  @override
  Path getClip(Size size) => Path()
    ..moveTo(0, size.height * 0.32)
    ..lineTo(size.width, 0)
    ..lineTo(size.width, size.height)
    ..lineTo(0, size.height)
    ..close();

  @override
  bool shouldReclip(_BandClipper oldClipper) => false;
}

// ---------------------------------------------------------------------------
// 투표 중
// ---------------------------------------------------------------------------
class _VotingLayer extends StatefulWidget {
  const _VotingLayer({
    required this.alive,
    required this.round,
    required this.seconds,
    required this.submittedUids,
    required this.eligibleCount,
  });

  final List<MafiaPlayer> alive;
  final int round;
  final int? seconds;
  final List<String> submittedUids;
  final int eligibleCount;

  static const double rowTop = 520;
  static const double rowGap = 30;

  @override
  State<_VotingLayer> createState() => _VotingLayerState();
}

class _VotingLayerState extends State<_VotingLayer> {
  /// 처음 그릴 때 이미 낸 사람입니다(재접속). 투표지를 다시 날리지 않습니다.
  late final Set<String> _alreadySubmitted = widget.submittedUids.toSet();

  @override
  Widget build(BuildContext context) {
    final seconds = widget.seconds;
    final submitted = widget.submittedUids.toSet();
    final alive = widget.alive;
    return Stack(
      fit: StackFit.expand,
      children: [
        MafiaTabletBox(
          rect: const Rect.fromLTWH(0, 36, 1194, 24),
          child: Center(
            child: Text(
              widget.round > 0 ? '${widget.round}일째 낮 · 비밀 투표' : '비밀 투표',
              style: mafiaNoirBody(
                15,
                color: MafiaColors.noirUmber,
                letterSpacing: 7.5,
              ),
            ),
          ),
        ),
        MafiaTabletBox(
          rect: const Rect.fromLTWH(0, 62, 1194, 80),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '투표 중',
                style: mafiaNoirDisplay(
                  66,
                  color: MafiaColors.noirInk,
                  height: 1,
                ),
              ),
              if (seconds != null) ...[
                const SizedBox(width: 22),
                Text(
                  mafiaNoirClock(seconds),
                  style: mafiaNoirDisplay(
                    52,
                    color: MafiaColors.noirBlood,
                    height: 1,
                  ),
                ),
              ],
            ],
          ),
        ),
        // 투표함 위 흩어진 투표지(장식)
        MafiaTabletBox(
          rect: const Rect.fromLTWH(527, 168, 70, 48),
          child: Transform.rotate(angle: -0.14, child: const _BallotPaper()),
        ),
        MafiaTabletBox(
          rect: const Rect.fromLTWH(600, 186, 70, 48),
          child: Transform.rotate(angle: 0.17, child: const _BallotPaper()),
        ),
        MafiaTabletBox(
          rect: MafiaTabletDayView.ballotBox,
          child: MafiaNoirFrame(
            inset: 8,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  left: 67,
                  top: 23,
                  width: 160,
                  height: 14,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black,
                      border: Border.all(
                        color: MafiaColors.noirBrass,
                        width: 2,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '투표 완료',
                        style: mafiaNoirBody(
                          14,
                          color: MafiaColors.noirBrass,
                          letterSpacing: 5.6,
                        ),
                      ),
                      Text(
                        '${submitted.length} / ${widget.eligibleCount}',
                        style: mafiaNoirDisplay(70, height: 1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        MafiaTabletPlayerRow(
          players: alive,
          top: _VotingLayer.rowTop,
          centeredGap: _VotingLayer.rowGap,
          dimmedUids: {
            for (final player in alive)
              if (!submitted.contains(player.uid)) player.uid,
          },
          labels: {
            for (final player in alive)
              player.uid: submitted.contains(player.uid)
                  ? const MafiaTabletSeatLabel('투표 완료', strong: true)
                  : const MafiaTabletSeatLabel('고민 중…'),
          },
        ),
        // 낸 사람 자리에서 투표지가 투표함으로 날아갑니다.
        for (var index = 0; index < alive.length; index++)
          if (submitted.contains(alive[index].uid) &&
              !_alreadySubmitted.contains(alive[index].uid))
            _BallotFlight(
              key: ValueKey('ballot-${alive[index].uid}'),
              from: MafiaTabletSeatRow.cardCenter(
                index,
                alive.length,
                _VotingLayer.rowTop,
                centeredGap: _VotingLayer.rowGap,
              ),
              to: Offset(
                MafiaTabletDayView.ballotBox.center.dx,
                MafiaTabletDayView.ballotBox.top + 30,
              ),
            ),
      ],
    );
  }
}

/// 투표함으로 날아가 슬롯에 빨려 들어가는 투표지 한 장입니다.
class _BallotFlight extends StatelessWidget {
  const _BallotFlight({super.key, required this.from, required this.to});

  final Offset from;
  final Offset to;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 820),
      builder: (context, t, _) {
        if (t >= 1) return const SizedBox.shrink();
        final eased = Curves.easeInOutCubic.transform(t);
        final position =
            Offset.lerp(from, to, eased)! +
            Offset(0, -math.sin(eased * math.pi) * 90);
        final shrink = t > 0.8 ? (1 - t) / 0.2 : 1.0;
        return MafiaTabletBox(
          rect: Rect.fromCenter(center: position, width: 70, height: 48),
          child: Opacity(
            opacity: shrink,
            child: Transform.rotate(
              angle: (1 - eased) * 0.5,
              child: Transform.scale(
                scale: 0.6 + 0.4 * shrink,
                child: const _BallotPaper(),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BallotPaper extends StatelessWidget {
  const _BallotPaper();

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: const Color(0xFFF4E8D2),
      border: Border.all(color: MafiaColors.noirInk, width: 2),
    ),
  );
}
