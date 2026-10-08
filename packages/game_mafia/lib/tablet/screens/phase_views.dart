// [phase_views.dart] 는 마피아에서 사용하는 태블릿에서 보이는 공용 게임 진행 화면을 구성하는 파일이다.
//
// - [Package] : 마피아
// - [TabletScreen] : 태블릿에서 보이는 공용 게임 진행 화면을 구성함
//
// 즉, 모든 플레이어가 함께 보는 진행 상태와 연출을 표시하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'package:flutter/material.dart';
import 'package:game_mafia/shared/widgets/trial_view.dart';
import 'package:game_kit/game_flow/game_presentation_sequence.dart';
import 'package:game_mafia/shared/models/presentation_timing.dart';
import 'package:game_mafia/game_copy.dart';
import 'package:game_mafia/shared/models/player.dart';
import 'package:game_mafia/shared/models/role.dart';
import 'package:game_mafia/shared/models/state_models.dart';
import 'package:game_mafia/game_sounds.dart';
import 'package:game_mafia/tablet/screens/execution_view.dart';
import 'package:game_mafia/shared/animations/announcement_reveal.dart';
import 'package:game_mafia/tablet/screens/game_layout.dart';
import 'package:game_mafia/tablet/screens/noir_table.dart';
import 'package:game_mafia/game_theme.dart';
import 'package:game_mafia/shared/widgets/noir.dart';

// ============================================================

// ---------------------------------------------------------------------------
// T1 역할 배분
// ---------------------------------------------------------------------------
/// 카드를 각 자리로 나눠 주는 연출입니다.
///
/// 시안 없이 확정된 방식입니다 — 태블릿 배경 위에서 **공용 분배 애니메이션**을
/// 돌리고, 카드는 **뒷면 그대로** 둡니다. 태블릿에 신분이 보이면 옆에서 보는
/// 사람에게 다 드러납니다.
class MafiaTabletRoleDealView extends StatefulWidget {
  const MafiaTabletRoleDealView({
    super.key,
    required this.players,
    required this.confirmedCount,
    this.confirmedUids = const {},
    this.showsNightNotice = false,
    this.showsGameStartNotice = false,
  });

  final List<MafiaPlayer> players;
  final int confirmedCount;

  /// 신분 확인을 마친 사람입니다. 카드 아래 `확인 완료`가 붙습니다.
  final Set<String> confirmedUids;
  final bool showsNightNotice;
  final bool showsGameStartNotice;

  /// `확인 완료 N / M` 줄 자리입니다(시안 top 432).
  static const double confirmTextTop = 432;

  /// 참가자 카드 줄 자리입니다(시안 top 540).
  static const double rowTop = 540;
  static const Duration confirmRevealDuration = Duration(milliseconds: 220);

  @override
  State<MafiaTabletRoleDealView> createState() =>
      _MafiaTabletRoleDealViewState();
}

class _MafiaTabletRoleDealViewState extends State<MafiaTabletRoleDealView> {
  bool _deckCleared = false;

  @override
  Widget build(BuildContext context) {
    final players = widget.players;
    return Stack(
      fit: StackFit.expand,
      children: [
        const MafiaTabletHeadline(
          text: '신분 카드를 나눠드립니다',
          top: 40,
          fontSize: 52,
          color: MafiaColors.noirPaper,
        ),
        MafiaTabletBox(
          rect: const Rect.fromLTWH(0, 106, 1194, 28),
          child: Center(
            child: Text(
              '휴대폰에서 자신의 신분을 확인하세요 · 아무에게도 보여주지 마세요',
              style: mafiaNoirBody(18),
            ),
          ),
        ),
        if (players.isNotEmpty)
          MafiaTabletNoirDeal(
            playerCount: players.length,
            rowTop: MafiaTabletRoleDealView.rowTop,
            onDeckCleared: () {
              if (mounted) setState(() => _deckCleared = true);
            },
          ),
        AnimatedOpacity(
          opacity: _deckCleared || players.isEmpty ? 1 : 0,
          duration: MafiaTabletRoleDealView.confirmRevealDuration,
          child: MafiaTabletBox(
            rect: const Rect.fromLTWH(
              0,
              MafiaTabletRoleDealView.confirmTextTop,
              1194,
              60,
            ),
            child: Center(
              child: MafiaNoirRuledLabel(
                label: '확인 완료',
                value: '${widget.confirmedCount} / ${players.length}',
                lineColor: MafiaColors.noirBrass,
                labelColor: MafiaColors.noirBrass,
                valueColor: MafiaColors.noirPaper,
                valueSize: 36,
              ),
            ),
          ),
        ),
        MafiaTabletPlayerRow(
          players: players,
          top: MafiaTabletRoleDealView.rowTop,
          dimmedUids: _deckCleared
              ? {
                  for (final player in players)
                    if (!widget.confirmedUids.contains(player.uid)) player.uid,
                }
              : const {},
          labels: _deckCleared
              ? {
                  for (final player in players)
                    player.uid: widget.confirmedUids.contains(player.uid)
                        ? const MafiaTabletSeatLabel('확인 완료', strong: true)
                        : const MafiaTabletSeatLabel('확인 중…'),
                }
              : const {},
        ),
        if (widget.showsGameStartNotice && !widget.showsNightNotice)
          const Positioned.fill(
            child: MafiaAnnouncementReveal(
              child: MafiaTabletNotice.night(
                text: MafiaCopy.gameStartNotice,
                voice: null,
              ),
            ),
          ),
        if (widget.showsNightNotice)
          const Positioned.fill(
            child: MafiaAnnouncementReveal(
              child: MafiaTabletNotice.night(text: MafiaCopy.nightNotice),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// T2 밤
// ---------------------------------------------------------------------------
/// 밤 화면입니다(시안 `tablet-T2`).
///
/// 행동 중에는 달과 새만 보이며 진행 현황을 표시하지 않습니다. 모든 행동이
/// 끝나는 공통 마무리 구간에만 새벽빛과 중립적인 안내를 표시합니다. 누가 행동을
/// 마쳤는지 보이면 특수직이 드러나므로 역할·완료 인원은 보여 주지 않습니다.
class MafiaTabletNightView extends StatelessWidget {
  const MafiaTabletNightView({
    super.key,
    this.isWrappingUp = false,
    this.round = 0,
    this.remainingSeconds,
    this.players = const [],
    this.revealedRoles = const {},
  });

  final bool isWrappingUp;
  final int round;
  final int? remainingSeconds;
  final List<MafiaPlayer> players;
  final Map<String, MafiaRole?> revealedRoles;

  @override
  Widget build(BuildContext context) {
    final seconds = remainingSeconds;
    return Stack(
      fit: StackFit.expand,
      children: [
        const MafiaTabletMoon(),
        const MafiaTabletHeadline(
          text: '밤이 찾아왔다',
          top: 356,
          fontSize: 78,
          color: MafiaColors.noirPaper,
        ),
        MafiaTabletBox(
          rect: const Rect.fromLTWH(0, 444, 1194, 28),
          child: Center(
            child: Text(
              round > 0
                  ? '$round일째 밤 · 휴대폰을 보고 조용히 행동하세요'
                  : '휴대폰을 보고 조용히 행동하세요',
              style: mafiaNoirBody(19, letterSpacing: 1.1),
            ),
          ),
        ),
        if (seconds != null)
          MafiaTabletTimerBox(
            rect: const Rect.fromLTWH(497, 482, 200, 74),
            seconds: seconds,
          ),
        if (players.isNotEmpty)
          MafiaTabletPlayerRow(
            players: players,
            top: 612,
            revealedRoles: revealedRoles,
          ),
        Positioned.fill(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: isWrappingUp
                ? const _MafiaTabletNightWrapUp(
                    key: ValueKey('mafia-night-wrap-up'),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}

/// 밤의 마지막 10초를 서버 대기가 아니라 새벽이 다가오는 장면으로 보여 줍니다.
class _MafiaTabletNightWrapUp extends StatefulWidget {
  const _MafiaTabletNightWrapUp({super.key});

  @override
  State<_MafiaTabletNightWrapUp> createState() =>
      _MafiaTabletNightWrapUpState();
}

class _MafiaTabletNightWrapUpState extends State<_MafiaTabletNightWrapUp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dawn;

  @override
  void initState() {
    super.initState();
    _dawn = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..forward();
  }

  @override
  void dispose() {
    _dawn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _dawn,
      builder: (context, _) {
        final progress = Curves.easeInOut.transform(_dawn.value);
        final textOpacity = Curves.easeOut.transform(
          ((_dawn.value - 0.08) / 0.28).clamp(0.0, 1.0),
        );
        return Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    const Color(0xFFD5A17A).withValues(alpha: 0.26 * progress),
                    const Color(0xFF6E667A).withValues(alpha: 0.13 * progress),
                    Colors.transparent,
                  ],
                  stops: const [0, 0.42, 0.82],
                ),
              ),
            ),
            Align(
              alignment: const Alignment(0, 0.42),
              child: Opacity(
                opacity: textOpacity,
                child: Transform.translate(
                  offset: Offset(0, 12 * (1 - textOpacity)),
                  child: Text(
                    '밤이 지나가고 있습니다',
                    key: const ValueKey('mafia-night-wrap-up-text'),
                    style: mafiaNoirDisplay(
                      30,
                      color: MafiaColors.noirBrass,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// T3 아침 발표
// ---------------------------------------------------------------------------
/// 밤 사이 일어난 일을 알립니다(시안 `tablet-t3` 두 상태).
///
/// | 상태 | 시안 |
/// |---|---|
/// | 사망자 있음 | 시체 그림 + `○○님은 밤을 넘기지 못했습니다.` |
/// | 사망자 없음 | `어제 밤, 아무도 죽지 않았습니다.` |
///
/// 누가 살렸는지는 절대 보여 주지 않습니다. 의사와 대상이 드러납니다.
class MafiaTabletMorningView extends StatelessWidget {
  const MafiaTabletMorningView({
    super.key,
    required this.result,
    required this.players,
    this.round = 0,
    this.hold = MafiaPresentationTiming.morningDeaths,
  });

  final MafiaMorningResult? result;
  final Map<String, MafiaPlayer> players;
  final int round;

  /// 이 발표가 머무는 시간입니다. 아래 진행 막대가 이 시간 동안 찹니다.
  final Duration hold;

  static const Rect _poster = Rect.fromLTWH(437, 196, 320, 440);

  @override
  Widget build(BuildContext context) {
    final dead = [
      for (final uid in result?.deadUids ?? const <String>[]) ?players[uid],
    ];
    final names = dead.map((player) => player.nickname).join(' · ');
    return Stack(
      fit: StackFit.expand,
      children: [
        if (round > 0)
          MafiaTabletBox(
            rect: const Rect.fromLTWH(0, 40, 1194, 24),
            child: Center(
              child: Text(
                '$round일째 아침',
                style: mafiaNoirBody(
                  15,
                  color: MafiaColors.noirUmber,
                  letterSpacing: 7.5,
                ),
              ),
            ),
          ),
        const MafiaTabletHeadline(text: '아침이 밝았다', top: 70, fontSize: 72),
        if (dead.isNotEmpty)
          MafiaTabletBox(
            rect: _poster,
            child: MafiaAnnouncementReveal(
              child: MafiaNoirPoster(
                player: dead.first,
                width: _poster.width,
                height: _poster.height,
                banner: const MafiaNoirBannerSpec(
                  label: '어젯밤 사망',
                  top: 0.53,
                  angle: -14,
                ),
              ),
            ),
          )
        else
          MafiaTabletBox(
            rect: const Rect.fromLTWH(347, 220, 500, 380),
            child: MafiaNoirCityscape(width: 500, height: 380),
          ),
        MafiaTabletHeadline(
          text: dead.isEmpty
              ? '어젯밤은 아무도 쓰러지지 않았다'
              : '어젯밤, ${mafiaJosa(names, '이', '가')} 쓰러졌다',
          top: 664,
          fontSize: 34,
        ),
        MafiaTabletBox(
          rect: const Rect.fromLTWH(447, 728, 300, 40),
          child: MafiaNoirProgress(duration: hold, label: '잠시 후 토론을 시작합니다'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// T3 아침 순서
// ---------------------------------------------------------------------------
/// 아침 안내 → 사망자 발표 → 취재 공개(있는 경우) → 토론 안내 순서입니다.
/// 각 유지 시간은 휴대폰과 공유하는 [MafiaPresentationTiming]에서 조절합니다.
/// 중단 중에는 남은 연출 시간을 보존하고, 마지막 화면은 서버 phase가 바뀔
/// 때까지 유지해 완료 요청이 늦어져도 빈 화면이 나타나지 않도록 합니다.
/// 서버 완료 요청은 tablet board가 담당하며 이 위젯은 표시만 담당합니다.
class MafiaTabletMorningSequence extends StatelessWidget {
  const MafiaTabletMorningSequence({
    super.key,
    required this.result,
    required this.players,
    this.exposedRole,
    this.round = 0,
  });

  final MafiaMorningResult? result;
  final Map<String, MafiaPlayer> players;

  /// 몇째 날 아침인지입니다(`3일째 아침`).
  final int round;

  /// 기자가 취재한 사람의 신분입니다. 취재가 없었으면 null입니다.
  ///
  /// 서버가 `revealedRoles`에 공개한 값을 그대로 받습니다.
  final MafiaRole? exposedRole;

  /// '아침이 되었습니다'를 보여 주는 시간입니다.
  static const Duration openingHold = MafiaPresentationTiming.morningOpening;

  /// 사망자 발표를 읽을 시간입니다(확정: 8초).
  static const Duration announcementHold =
      MafiaPresentationTiming.morningDeaths;

  /// 기자의 취재 공개를 보여 주는 시간입니다(처형 공개와 같은 9초).
  static const Duration exposureHold = MafiaPresentationTiming.exposure;

  /// '토론을 시작합니다'를 보여 주는 시간입니다.
  static const Duration closingHold = MafiaPresentationTiming.nextPhase;

  /// 세 박자를 합한 아침 전체 시간입니다(취재 공개 없음).
  static Duration get totalHold => openingHold + announcementHold + closingHold;

  /// 이 결과로 실제로 보여 줄 시간입니다.
  ///
  /// 확정(2026-08): 사망자 발표로 게임이 끝나면 **'토론을 시작합니다'를 건너뛰고
  /// 곧바로** 결과 화면으로 갑니다. 이미 끝난 판에서 다음 단계를 예고하면 게임이
  /// 계속되는 것처럼 보입니다.
  ///
  /// 기자의 취재가 성공한 아침은 카드 공개 박자가 하나 더 들어갑니다. 이 값이
  /// 실제 연출보다 짧으면 발표가 잘린 채 단계가 넘어갑니다.
  static Duration holdOf(MafiaMorningResult? result) {
    final ends = result?.endsGame ?? false;
    // 취재 공개는 게임이 끝나는 아침에도 보여 줍니다 — 이미 공개된 신분이라
    // 승패를 앞당겨 알려 주는 것이 아닙니다.
    final exposure = (result?.hasExposure ?? false)
        ? exposureHold
        : Duration.zero;
    final base = openingHold + announcementHold + exposure;
    return ends ? base : base + closingHold;
  }

  @override
  Widget build(BuildContext context) {
    final exposedUid = result?.exposedUid;
    final exposed = exposedUid == null ? null : players[exposedUid];
    // 명단이 일시적으로 비어도 시간표 길이는 서버 결과와 동일하게 유지합니다.
    final showsExposure = result?.hasExposure ?? false;
    return GamePresentationSequence(
      beats: [
        // 1박자: 아침 안내가 떠올랐다 물러납니다.
        GamePresentationBeat(
          hold: openingHold,
          child: const MafiaTabletNotice.day(text: MafiaCopy.morningNotice),
        ),
        // 2박자: 안내가 물러난 뒤 사망자 발표가 떠오르고, 다 읽으면 물러납니다.
        GamePresentationBeat(
          hold: announcementHold,
          child: MafiaTabletMorningView(result: result, players: players),
        ),
        // 3박자(있을 때만): 기자의 취재 공개입니다. **처형 공개와 같은 연출**을
        // 그대로 씁니다 — 카드가 뒤집혀 신분이 드러나고, 그 사람은 죽지 않습니다.
        if (showsExposure)
          GamePresentationBeat(
            hold: exposureHold,
            child: exposed == null
                ? const MafiaTabletNotice.day(text: '취재 결과 발표')
                : MafiaTabletExecutionView(
                    executed: exposed,
                    executedRole: exposedRole,
                    isTie: false,
                    headlineBeats: MafiaCopy.exposureBeats,
                  ),
          ),
        // 마지막 박자: 토론 시작 안내입니다. 단계가 넘어갈 때까지 남습니다.
        // 이 발표로 게임이 끝나면 띄우지 않습니다.
        if (!(result?.endsGame ?? false))
          GamePresentationBeat(
            hold: closingHold,
            child: const MafiaTabletNotice.day(
              text: MafiaCopy.discussionNotice,
              // '지금부터 토론을 시작합니다' 음성(2.24초)이 2.5초 안내에 맞습니다.
              voice: MafiaSounds.voiceDiscussion,
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// T6·T7 개표 → 처형 발표
// ---------------------------------------------------------------------------
/// 개표판을 보여 준 뒤 처형 발표로 넘어갑니다.
///
/// 서버는 `voteResult` 하나로만 알려 주므로 두 시안의 순서를 화면이 셉니다.
/// 연출 상태라 컨트롤러에 두지 않습니다.
class MafiaTabletVoteResultSequence extends StatelessWidget {
  const MafiaTabletVoteResultSequence({
    super.key,
    required this.result,
    required this.players,
    required this.executed,
    required this.executedRole,
    this.limitedDisclosure = false,
    this.revealedFaction,
    this.round = 0,
  });

  /// 몇째 날 낮인지입니다(제목 아래 줄).
  final int round;

  /// 제목 아래 줄입니다. 예: `3일째 낮 · 5명 투표 · 누가 누구를 찍었는지는 비밀`.
  String get _subtitle {
    final voters = (result?.tally.values.fold<int>(0, (a, b) => a + b) ?? 0);
    final day = round > 0 ? '$round일째 낮 · ' : '';
    return '$day$voters표 · 누가 누구를 찍었는지는 비밀';
  }

  final MafiaVoteResult? result;
  final Map<String, MafiaPlayer> players;
  final MafiaPlayer? executed;
  final MafiaRole? executedRole;
  final bool limitedDisclosure;
  final String? revealedFaction;

  /// 개표판을 보여 주는 시간입니다(확정: 4초).
  static const Duration tallyHold = MafiaPresentationTiming.voteTally;

  /// 처형 발표(이름 4초 + 신분 공개 5초)를 보여 주는 시간입니다.
  static Duration get executionHold =>
      MafiaPresentationTiming.executionName +
      MafiaPresentationTiming.executionReveal;

  /// 마지막에 '밤이 되었습니다'를 보여 주는 시간입니다.
  static const Duration nightNoticeHold = MafiaPresentationTiming.nextPhase;

  /// 개표부터 밤 안내까지 합한 전체 시간입니다.
  static Duration get totalHold => tallyHold + executionHold + nightNoticeHold;

  /// 이 결과로 실제로 보여 줄 시간입니다.
  ///
  /// 확정(2026-08): 이 처형으로 게임이 끝나면 **'밤이 되었습니다'를 건너뛰고
  /// 곧바로** 결과 화면으로 갑니다. 밤을 예고했다가 게임이 끝나면 흐름이
  /// 끊깁니다.
  static Duration holdOf(MafiaVoteResult? result) =>
      (result?.endsGame ?? false) ? tallyHold + executionHold : totalHold;

  @override
  Widget build(BuildContext context) {
    // 아침 발표와 같은 말투입니다 — 각 박자가 떠올랐다 물러납니다.
    return GamePresentationSequence(
      beats: [
        GamePresentationBeat(
          hold: tallyHold,
          child: result?.hasVerdict == true
              ? MafiaVerdictSummary(result: result!)
              : MafiaTabletCountingView(
                  tally: result?.tally ?? const {},
                  players: players,
                  abstainCount: result?.abstainCount ?? 0,
                  subtitle: _subtitle,
                ),
        ),
        GamePresentationBeat(
          hold: executionHold,
          child: limitedDisclosure && executed != null
              ? MafiaLimitedDisclosure(
                  nickname: executed!.nickname,
                  faction: revealedFaction,
                )
              : MafiaTabletExecutionView(
                  executed: executed,
                  executedRole: executedRole,
                  isTie: result?.tie ?? false,
                  tally: result?.hasVerdict == true ? null : result?.tally,
                  players: players,
                  abstainCount: result?.abstainCount ?? 0,
                  subtitle: _subtitle,
                ),
        ),
        // 확정(2026-08): 밤으로 가기 전에 안내를 띄우고 그 뒤에 배경이 바뀝니다.
        // 이 처형으로 게임이 끝나면 띄우지 않습니다.
        if (!(result?.endsGame ?? false))
          GamePresentationBeat(
            hold: nightNoticeHold,
            child: const MafiaTabletNotice.night(text: MafiaCopy.nightNotice),
          ),
      ],
    );
  }
}
