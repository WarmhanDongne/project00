// [execution_view.dart] 는 마피아에서 사용하는 태블릿에서 보이는 공용 게임 진행 화면을 구성하는 파일이다.
//
// - [Package] : 마피아
// - [TabletScreen] : 태블릿에서 보이는 공용 게임 진행 화면을 구성함
//
// 즉, 모든 플레이어가 함께 보는 진행 상태와 연출을 표시하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'package:game_kit/game_flow/game_presentation_clock.dart';
import 'package:flutter/material.dart';
import 'package:game_mafia/shared/models/presentation_timing.dart';
import 'package:game_mafia/game_assets.dart';
import 'package:game_mafia/game_copy.dart';
import 'package:game_mafia/shared/models/player.dart';
import 'package:game_mafia/shared/models/role.dart';
import 'package:game_mafia/shared/widgets/flip_card.dart';
import 'package:game_mafia/tablet/screens/game_layout.dart';
import 'package:game_mafia/shared/widgets/noir.dart';
import 'package:game_mafia/game_theme.dart';
import 'package:game_mafia/shared/animations/announcement_reveal.dart';
import 'package:game_mafia/gen/assets.gen.dart';

// ============================================================

// ---------------------------------------------------------------------------
// 태블릿 처형 발표
// ---------------------------------------------------------------------------
/// 개표 뒤 처형자를 알리고 신분을 공개합니다.
///
/// 시안 세 장이 한 연출입니다.
///
/// | 박자 | 시안 | 내용 |
/// |---|---|---|
/// | 1 | `tablet-p7 투표 결과발표` | `탈락자 닉네임` 64px |
/// | 2 | `1017:555` | 뒷면 카드 + 대상의 원형 사진 |
/// | 3 | `1017:566` | 앞면 카드 + "○○님은 ○○이었습니다." |
///
/// **카드가 박자 2 → 3에서 31px 올라갑니다.** 실수가 아니라 필요한 이동입니다.
/// 박자 2 위치에 그대로 두면 카드 아래끝(628)이 문구(627)와 겹칩니다. 그래서
/// 뒤집기와 함께 올라가도록 이었습니다.
class MafiaTabletExecutionView extends StatefulWidget {
  const MafiaTabletExecutionView({
    super.key,
    required this.executed,
    required this.executedRole,
    required this.isTie,
    this.headlineBeats,
    this.tally,
    this.players = const {},
    this.abstainCount = 0,
    this.subtitle,
  });

  /// 득표입니다(`uid → 표`). 있으면 왼쪽에 득표 막대를 그립니다.
  final Map<String, int>? tally;

  /// 득표 막대의 얼굴·이름을 찾는 참가자 표입니다.
  final Map<String, MafiaPlayer> players;

  /// 표를 내지 않은 인원입니다(`기권`).
  final int abstainCount;

  /// 제목 아래 한 줄입니다(예: `3일째 낮 · 5명 투표 · 누가 누구를 찍었는지는 비밀`).
  final String? subtitle;

  /// 카드가 나오기 전에 찍는 머리말입니다. null이면 그 사람의 닉네임입니다.
  ///
  /// 확정(2026-08): 기자의 취재 공개가 **이 연출을 그대로** 씁니다. 카드가
  /// 뒤집혀 신분이 드러나는 흐름은 같고, 앞에 찍는 말과 죽지 않는다는 점만
  /// 다릅니다. 그래서 연출을 복사하지 않고 머리말만 갈아 끼웁니다.
  final List<String>? headlineBeats;

  /// 처형된 사람입니다. 동표로 무처형이면 null입니다.
  final MafiaPlayer? executed;

  /// 처형된 사람의 신분입니다. 서버가 공개한 값을 그대로 씁니다.
  final MafiaRole? executedRole;

  /// 동표로 아무도 처형되지 않았는지입니다.
  final bool isTie;

  // ---------------------------------------------------------------------------
  // 연출 시간
  // ---------------------------------------------------------------------------
  /// 이름을 보여 주는 시간입니다(확정: 4초). 이 뒤에 카드가 나옵니다.
  static const Duration nameHold = MafiaPresentationTiming.executionName;

  /// 뒷면 카드를 보여 주는 시간입니다. 이 뒤에 뒤집혀 공개 5초가 이어집니다.
  static const Duration cardHold = Duration(milliseconds: 1000);

  /// 카드가 뒤집히는 시간입니다. 휴대폰과 같게 맞췄습니다.
  static const Duration flipDuration = Duration(milliseconds: 620);

  @override
  State<MafiaTabletExecutionView> createState() =>
      _MafiaTabletExecutionViewState();
}

class _MafiaTabletExecutionViewState extends State<MafiaTabletExecutionView>
    with SingleTickerProviderStateMixin, GamePresentationState {
  @override
  Iterable<AnimationController> get presentationAnimations => [_flip];
  // ---------------------------------------------------------------------------
  // 시안 기준 좌표
  // ---------------------------------------------------------------------------
  static const double _nameTop = 378;

  late final AnimationController _flip;
  PresentationTimer? _nameTimer;
  PresentationTimer? _cardTimer;

  /// 신분 문구를 찍기 시작했는지입니다.
  ///
  /// 오른쪽 신분 카드가 절반 돌아간 순간 카운트다운이 신분 이름으로 바뀝니다.
  bool _showsSentence = false;

  @override
  void initState() {
    super.initState();
    _flip = AnimationController(
      vsync: this,
      duration: MafiaTabletExecutionView.flipDuration,
    )..addListener(_handleFlipProgress);
    if (widget.executed == null) return;

    _nameTimer = presentationTimer(MafiaTabletExecutionView.nameHold, () {
      if (!mounted) return;
      _cardTimer = presentationTimer(MafiaTabletExecutionView.cardHold, () {
        if (mounted) _flip.forward();
      });
    });
  }

  void _handleFlipProgress() {
    if (_showsSentence || !mounted) return;
    // 앞면이 드러나기 시작하는 지점입니다(카드 뒤집기의 절반).
    if (_flip.value < 0.5) return;
    setState(() => _showsSentence = true);
  }

  @override
  void dispose() {
    _nameTimer?.cancel();
    _cardTimer?.cancel();
    _flip
      ..removeListener(_handleFlipProgress)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final executed = widget.executed;
    final headline = widget.headlineBeats;
    final tally = widget.tally;
    final votes = tally?[executed?.uid];

    return Stack(
      fit: StackFit.expand,
      children: [
        // 시안 태블릿 ⑦: 먹색 무대 위에 위에서 떨어지는 스포트라이트입니다.
        const ColoredBox(color: MafiaColors.noirInk),
        const Positioned.fill(child: CustomPaint(painter: _SpotlightPainter())),
        MafiaTabletHeadline(
          text: headline == null ? '오늘의 처형' : headline.join(' '),
          top: 36,
          fontSize: headline == null ? 56 : 44,
          color: MafiaColors.noirPaper,
        ),
        if (widget.subtitle != null)
          MafiaTabletBox(
            rect: const Rect.fromLTWH(0, 104, 1194, 26),
            child: Center(
              child: Text(
                widget.subtitle!,
                style: mafiaNoirBody(17, letterSpacing: 1.7),
              ),
            ),
          ),
        if (executed == null)
          MafiaTabletAnnouncement(
            beats: widget.isTie
                ? MafiaCopy.tieBeats
                : const [MafiaCopy.noExecution],
            top: _nameTop,
            color: MafiaColors.noirPaper,
          )
        else
          MafiaTabletBox(
            rect: _poster,
            child: MafiaAnnouncementReveal(
              child: MafiaNoirPoster(
                player: executed,
                width: _poster.width,
                height: _poster.height,
                grayscale: false,
                borderColor: MafiaColors.noirBrass,
                circleColor: MafiaColors.noirBlood,
                subtitle: headline != null
                    ? '신분 공개'
                    : votes == null
                    ? '처형 확정'
                    : '$votes표 · 처형 확정',
                banner: MafiaNoirBannerSpec(
                  label: headline == null ? '처 형' : '공 개',
                  top: 0.5,
                  angle: -14,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        if (tally != null)
          MafiaTabletBox(
            rect: const Rect.fromLTWH(60, 220, 320, 470),
            child: _TallyList(
              tally: tally,
              players: widget.players,
              abstainCount: widget.abstainCount,
            ),
          ),
        if (executed != null) ..._buildRevealPanel(executed),
      ],
    );
  }

  static const Rect _poster = Rect.fromLTWH(437, 160, 320, 470);
  static const Rect _revealCard = Rect.fromLTWH(905, 256, 150, 220);

  List<Widget> _buildRevealPanel(MafiaPlayer executed) {
    final role = widget.executedRole;
    return [
      MafiaTabletBox(
        rect: const Rect.fromLTWH(830, 220, 300, 24),
        child: Center(
          child: Text(
            _showsSentence ? '신분 공개' : '신분 공개까지',
            style: mafiaNoirBody(16, letterSpacing: 3.2),
          ),
        ),
      ),
      AnimatedBuilder(
        animation: _flip,
        builder: (context, _) {
          final progress = Curves.easeInOutCubic.transform(_flip.value);
          return MafiaTabletBox(
            rect: _revealCard,
            child: MafiaFlipCard(
              progress: progress,
              front: role?.card,
              back: Assets.games.mafia.images.cards.roleBack.game,
              borderRadius: BorderRadius.circular(8),
              borderColor: MafiaColors.noirBrass,
            ),
          );
        },
      ),
      MafiaTabletBox(
        rect: const Rect.fromLTWH(830, 496, 300, 120),
        child: Center(
          child: _showsSentence
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      role?.displayName ?? '알 수 없음',
                      style: mafiaNoirDisplay(
                        44,
                        color: role?.faction.isMafia ?? false
                            ? MafiaColors.noirRose
                            : MafiaColors.noirPaper,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('${executed.nickname}님의 신분', style: mafiaNoirBody(15)),
                  ],
                )
              : TweenAnimationBuilder<double>(
                  tween: Tween(begin: 1, end: 0),
                  duration:
                      MafiaTabletExecutionView.nameHold +
                      MafiaTabletExecutionView.cardHold,
                  builder: (context, value, _) {
                    final total =
                        MafiaTabletExecutionView.nameHold +
                        MafiaTabletExecutionView.cardHold;
                    final left = (value * total.inMilliseconds / 1000).ceil();
                    return Text(
                      '${left.clamp(1, 99)}',
                      style: mafiaNoirDisplay(
                        72,
                        color: MafiaColors.noirBrass,
                        height: 1,
                      ),
                    );
                  },
                ),
        ),
      ),
    ];
  }
}

/// 위에서 아래로 넓어지는 스포트라이트와 바닥의 빛 웅덩이입니다.
class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final light = Paint()..color = const Color(0x14D9C2A2);
    canvas
      ..drawPath(
        Path()
          ..moveTo(size.width * 0.46, 0)
          ..lineTo(size.width * 0.54, 0)
          ..lineTo(size.width * 0.76, size.height)
          ..lineTo(size.width * 0.24, size.height)
          ..close(),
        light,
      )
      ..drawOval(
        Rect.fromCenter(
          center: Offset(size.width / 2, size.height * 0.88),
          width: size.width * 0.37,
          height: size.height * 0.084,
        ),
        Paint()..color = const Color(0x1AD9C2A2),
      );
  }

  @override
  bool shouldRepaint(_SpotlightPainter oldDelegate) => false;
}

/// 왼쪽 득표 막대입니다. 표가 많은 순서로, 기권은 마지막 줄입니다.
class _TallyList extends StatelessWidget {
  const _TallyList({
    required this.tally,
    required this.players,
    required this.abstainCount,
  });

  final Map<String, int> tally;
  final Map<String, MafiaPlayer> players;
  final int abstainCount;

  @override
  Widget build(BuildContext context) {
    final rows = tally.entries.toList()
      ..sort((left, right) => right.value.compareTo(left.value));
    final maxRows = abstainCount > 0 ? 5 : 6;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('득표', style: mafiaNoirBody(16, letterSpacing: 3.2)),
        const SizedBox(height: 16),
        for (var index = 0; index < rows.length && index < maxRows; index++)
          _row(
            index: index,
            leading: players[rows[index].key] == null
                ? const SizedBox(width: 56, height: 56)
                : SizedBox(
                    width: 56,
                    height: 56,
                    child: MafiaNoirFace(player: players[rows[index].key]!),
                  ),
            name: players[rows[index].key]?.nickname ?? '플레이어',
            count: rows[index].value,
            filled: true,
            top: index == 0,
          ),
        if (abstainCount > 0)
          _row(
            index: rows.length,
            leading: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: MafiaColors.noirFaded, width: 2),
              ),
            ),
            name: '기권',
            count: abstainCount,
            filled: false,
            top: false,
          ),
      ],
    );
  }

  Widget _row({
    required int index,
    required Widget leading,
    required String name,
    required int count,
    required bool filled,
    required bool top,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 420 + index * 160),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(-24 * (1 - value), 0),
          child: child,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.only(bottom: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFF2F3532))),
        ),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 14),
            // 닉네임(최대 8자)을 자르지 않고 칸에 맞춰 줄입니다.
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  name,
                  maxLines: 1,
                  style: mafiaNoirDisplay(
                    26,
                    color: filled
                        ? MafiaColors.noirPaper
                        : MafiaColors.noirDust,
                  ),
                ),
              ),
            ),
            for (var tick = 0; tick < count && tick < 8; tick++)
              Container(
                width: 10,
                height: 30,
                margin: const EdgeInsets.only(left: 4),
                decoration: BoxDecoration(
                  color: !filled
                      ? Colors.transparent
                      : top
                      ? MafiaColors.noirBlood
                      : MafiaColors.noirPaper,
                  border: filled
                      ? null
                      : Border.all(color: MafiaColors.noirFaded, width: 2),
                ),
              ),
            SizedBox(
              width: 34,
              child: Text(
                '$count',
                textAlign: TextAlign.right,
                style: mafiaNoirDisplay(
                  34,
                  color: filled ? MafiaColors.noirBrass : MafiaColors.noirDust,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 개표 박자입니다(처형 발표 직전). 처형 화면과 같은 무대·같은 득표 자리를
/// 써서, 다음 박자로 넘어갈 때 득표 막대가 제자리에 그대로 남습니다.
class MafiaTabletCountingView extends StatelessWidget {
  const MafiaTabletCountingView({
    super.key,
    required this.tally,
    required this.players,
    this.abstainCount = 0,
    this.subtitle,
  });

  final Map<String, int> tally;
  final Map<String, MafiaPlayer> players;
  final int abstainCount;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: MafiaColors.noirInk),
        const Positioned.fill(child: CustomPaint(painter: _SpotlightPainter())),
        const MafiaTabletHeadline(
          text: '개표',
          top: 36,
          fontSize: 56,
          color: MafiaColors.noirPaper,
        ),
        if (subtitle != null)
          MafiaTabletBox(
            rect: const Rect.fromLTWH(0, 104, 1194, 26),
            child: Center(
              child: Text(
                subtitle!,
                style: mafiaNoirBody(17, letterSpacing: 1.7),
              ),
            ),
          ),
        // 가운데는 봉인된 투표함입니다. 다음 박자에서 처형 포스터로 바뀝니다.
        MafiaTabletBox(
          rect: const Rect.fromLTWH(447, 236, 300, 230),
          child: MafiaNoirFrame(
            child: Text(
              '${tally.values.fold<int>(0, (sum, value) => sum + value)}표',
              style: mafiaNoirDisplay(70, height: 1),
            ),
          ),
        ),
        MafiaTabletBox(
          rect: const Rect.fromLTWH(60, 220, 320, 470),
          child: _TallyList(
            tally: tally,
            players: players,
            abstainCount: abstainCount,
          ),
        ),
      ],
    );
  }
}
