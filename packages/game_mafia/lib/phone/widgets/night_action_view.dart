// [night_action_view.dart] 는 마피아에서 사용하는 휴대폰 게임 화면에서 재사용하는 UI 조각을 구성하는 파일이다.
//
// - [Package] : 마피아
// - [PhoneWidget] : 휴대폰 게임 화면에서 재사용하는 UI 조각을 구성함
//
// 즉, 플레이어 조작과 상태 표시를 화면별로 나눠 관리하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'package:flutter/material.dart';
import 'package:game_mafia/shared/models/player.dart';
import 'package:game_mafia/shared/models/role.dart';
import 'package:game_mafia/shared/models/role_catalog.dart';
import 'package:game_mafia/phone/widgets/game_layout.dart';
import 'package:game_mafia/phone/widgets/player_select_grid.dart';
import 'package:game_mafia/shared/widgets/noir.dart';
import 'package:game_mafia/game_theme.dart';

// ============================================================

/// 경찰·정보원이 조사한 결과입니다.
///
/// 문구는 **서버가 계산한 값을 그대로** 담습니다. 밀러는 시민인데 마피아로,
/// 마피아 보스는 마피아인데 시민으로 보여야 하므로 클라이언트가 대상의 진영을
/// 다시 계산해서는 안 됩니다.
@immutable
class MafiaNightInvestigationResult {
  const MafiaNightInvestigationResult({
    required this.target,
    required this.verdict,
    this.title = '조사 결과',
    this.asFactionSentence = false,
  });

  /// 결과를 **문장 한 줄**로 보여 줄지입니다(경찰의 진영 조사).
  ///
  /// 확정(2026-08): 경찰의 결과는 `시민`처럼 한 낱말로 두지 않습니다. `시민`은
  /// 직업 이름이기도 해서 "정확한 직업을 알아냈다"로 읽힙니다. 그래서
  /// `OO님은 마피아입니다` · `OO님은 마피아가 아닙니다`로 적습니다.
  ///
  /// 영매·도둑은 실제로 직업 이름을 알아내므로 이 값이 false입니다.
  final bool asFactionSentence;

  /// 조사한 대상입니다.
  final MafiaPlayer target;

  /// 서버가 보낸 결과 값입니다. 예: `시민`·`마피아`.
  final String verdict;

  /// 상단 제목입니다.
  final String title;

  /// 결과가 **마피아**로 나왔는지입니다. 테두리를 진영 색(빨강)으로 바꿉니다.
  ///
  /// 진영을 다시 계산하지 않고 서버가 보낸 결과 문구만 읽습니다. 경찰은
  /// `마피아`·`시민` 두 값만 받고, 정보원은 역할 이름을 받으므로(`마피아 보스`
  /// 등) 역할 표에서 그 이름의 진영을 찾습니다. 밀러(시민인데 마피아로 보임)와
  /// 마피아 보스(마피아인데 시민으로 보임)도 서버가 보낸 값대로 칠해집니다.
  bool get showsMafia {
    final text = verdict.trim();
    if (text.isEmpty) return false;
    if (text == MafiaFaction.mafia.displayName) return true;
    return MafiaRoles.all.any(
      (role) => role.displayName == text && role.faction.isMafia,
    );
  }

  /// 화면에 적을 결과 문구입니다.
  ///
  /// 진영 조사는 문장으로, 직업을 알아내는 조사(영매·도둑)는 서버가 보낸 직업
  /// 이름을 그대로 씁니다.
  String get displayText {
    if (!asFactionSentence) return verdict;
    final name = target.nickname;
    return showsMafia ? '$name님은 마피아입니다' : '$name님은 마피아가 아닙니다';
  }
}

// ---------------------------------------------------------------------------
// P2~P5 밤 화면
// ---------------------------------------------------------------------------
/// 밤 화면입니다. 시안 P2~P5가 **모두 이 위젯 하나**입니다.
///
/// 역할 이름으로 분기하지 않고 [MafiaRole.nightAction]과 아래 상태만 봅니다.
/// 그래서 새 신분을 추가해도 이 화면은 수정할 필요가 없습니다.
///
/// | 시안 | 조건 | 화면 |
/// |---|---|---|
/// | P2 | `eliminate` | "**제거** 할 대상을…" + 선택 그리드 |
/// | P3 | `protect` | "**치료** 할 대상을…" + 선택 그리드 |
/// | P4 | `investigate` | "**조사** 할 대상을…" + 선택 그리드 |
/// | P4-2 | [investigationResult] 있음 | 대상 한 명을 크게 + 결과 |
/// | P5 | [isSubmitted] 또는 밤 행동 없음 | "선택을 완료했습니다" 대기 |
///
/// 마지막 줄이 이 게임의 핵심 장치입니다. **대상을 고르지 않는 역할(시민)과
/// 행동을 끝낸 특수직이 똑같은 화면을 봅니다.** 그래야 옆 사람이 훔쳐봐도
/// 누가 특수직인지 드러나지 않습니다.
class MafiaNightActionView extends StatelessWidget {
  const MafiaNightActionView({
    super.key,
    required this.role,
    this.players = const [],
    this.selectedUid,
    this.allySelectedUids = const {},
    this.remainingSeconds,
    this.isSubmitted = false,
    this.actionWindowClosed = false,
    this.abilityExhausted = false,
    this.onSelect,
    this.onConfirm,
    this.investigationResult,
    this.onConfirmResult,
    this.waitingMessage = '다른 플레이어의 행동을 기다리는 중…',
    this.isWrappingUp = false,
  });

  /// 내 역할입니다. null이면 아직 역할을 받지 못한 것으로 보고 대기 화면을 그립니다.
  final MafiaRole? role;

  /// 고를 수 있는 대상입니다. 호출부가 자신과 동료를 미리 걸러 전달합니다.
  final List<MafiaPlayer> players;

  final String? selectedUid;

  /// 동료가 고른 대상입니다(마피아끼리 실시간 확인).
  final Set<String> allySelectedUids;

  /// 남은 시간(초)입니다. null이면 타이머를 그리지 않습니다.
  final int? remainingSeconds;

  /// 선택을 확정해 서버에 보냈는지입니다. true면 대기 화면(P5)이 됩니다.
  final bool isSubmitted;

  /// 행동 시간(밤의 앞 1분)이 끝났는지입니다.
  ///
  /// 확정(2026-08): 이 뒤 30초는 아무도 고를 수 없고 다같이 기다립니다.
  /// 아직 안 골랐더라도 화면은 대기로 넘어갑니다.
  final bool actionWindowClosed;

  /// 능력을 다 써서 이번 밤에 고를 수 없는지입니다(자경단원의 한 발).
  ///
  /// 선택 화면 대신 **대기 화면**을 그립니다. 고를 수 없는 그리드를 보여 주면
  /// 막힌 화면이 되고, 무엇보다 옆에서 보는 사람에게 특수직임이 드러납니다.
  final bool abilityExhausted;

  final ValueChanged<String>? onSelect;
  final VoidCallback? onConfirm;

  /// 조사 결과입니다. 있으면 결과 화면(P4-2)을 그립니다.
  final MafiaNightInvestigationResult? investigationResult;

  /// 결과 화면의 '확인'을 눌렀을 때입니다.
  final VoidCallback? onConfirmResult;
  final String waitingMessage;

  /// 모든 밤 행동이 끝나고 아침 결과를 정리하는 공통 10초 구간인지입니다.
  final bool isWrappingUp;

  // ---------------------------------------------------------------------------
  // 시안 기준 좌표
  // ---------------------------------------------------------------------------
  // 공용 좌표(버튼·보관 카드)는 [MafiaPhoneDesign]에 있습니다.
  // 안내·타이머는 모든 단계 공통 자리(MafiaPhoneStatusText)를 씁니다.
  static const double _tagTop = 92;
  static const double _promptTop = 114;
  static const double _timerTop = 156;

  /// 내가 밤에 실제로 행동을 제출했는지입니다.
  ///
  /// 밤에 하는 일이 없는 신분은 제출할 것도 없으므로 false입니다.
  bool get _hasSubmittedAction => isSubmitted && (role?.actsAtNight ?? false);

  /// 화면이 바뀔 때 두 화면이 겹쳐 오가는 시간입니다.
  static const Duration modeFadeDuration = Duration(milliseconds: 360);

  /// 대상을 고르는 화면인지입니다.
  bool get _showsSelection {
    final current = role;
    if (current == null || isSubmitted || actionWindowClosed) return false;
    if (abilityExhausted) return false;
    return current.actsAtNight && players.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = MafiaPhoneDesign.resolve(constraints);
        final scale = MafiaPhoneDesign.scaleOf(size);
        final result = investigationResult;

        // 결과 > 선택 > 대기 중 하나만 그립니다.
        final mode = result != null
            ? _NightViewMode.result
            : _showsSelection
            ? _NightViewMode.selection
            : _NightViewMode.waiting;

        return Stack(
          fit: StackFit.expand,
          children: [
            const Positioned.fill(child: MafiaPhoneBackground.night()),
            if (isWrappingUp)
              const Positioned.fill(child: _MafiaPhoneNightWrapUp()),
            // 확정(2026-08): 화면이 바뀔 때 **안내 문구·선택 그리드·버튼이 한
            // 덩어리로 함께** 흐려지고, 다음 화면이 겹쳐 들어옵니다. 예전에는
            // 버튼만 따로 흐려져서 문구는 툭 끊기고 버튼만 남아 보였습니다.
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: modeFadeDuration,
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeOut,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  // 사라지는 중인 화면은 눌리지 않게 합니다.
                  child: IgnorePointer(
                    ignoring: animation.status == AnimationStatus.reverse,
                    child: child,
                  ),
                ),
                child: Stack(
                  key: ValueKey(mode),
                  fit: StackFit.expand,
                  children: switch (mode) {
                    _NightViewMode.result => [
                      Positioned.fill(
                        child: _MafiaInvestigationReveal(
                          child: Stack(
                            fit: StackFit.expand,
                            children: _buildInvestigationResult(
                              size,
                              scale,
                              result!,
                            ),
                          ),
                        ),
                      ),
                    ],
                    _NightViewMode.selection => [
                      ..._buildSelectionLayer(size, scale),
                      MafiaPhoneActionButton(
                        label: _confirmLabel(),
                        onTap: onConfirm,
                        enabled: selectedUid != null && onConfirm != null,
                        colorlessWhenDisabled: true,
                        backgroundColor: _confirmColor(),
                        labelColor: _confirmTextColor(),
                      ),
                    ],
                    _NightViewMode.waiting => _buildWaiting(size, scale),
                  },
                ),
              ),
            ),
            MafiaStoredRoleCard(role: role),
          ],
        );
      },
    );
  }

  /// 역할 영문 꼬리표입니다(시안: `MAFIA`·`DOCTOR`·`POLICE`).
  static String roleTag(MafiaRole role) =>
      role.id.replaceAll('_', ' ').toUpperCase();

  /// 밤 제목입니다. 제거는 `오늘 밤의 표적`, 치료는 `오늘 밤 살릴 사람`.
  static String nightTitle(MafiaRole role) => switch (role.nightAction) {
    MafiaNightAction.eliminate => '오늘 밤의 표적',
    MafiaNightAction.protect => '오늘 밤 살릴 사람',
    _ => '오늘 밤 ${role.nightPromptVerb}할 사람',
  };

  /// 고른 카드에 두르는 띠 문구입니다.
  static String bannerLabel(MafiaRole role) => switch (role.nightAction) {
    MafiaNightAction.eliminate => '표적',
    _ => role.nightPromptVerb,
  };

  /// 격자 아래 한 줄 안내입니다.
  String? _caption(MafiaRole role) {
    if (allySelectedUids.isNotEmpty) return '빨간 모서리는 동료가 고른 사람입니다';
    return switch (role.nightAction) {
      MafiaNightAction.protect => '마피아가 고른 사람을 맞히면 그 사람은 살아납니다',
      MafiaNightAction.investigate ||
      MafiaNightAction.investigateRole => '조사 결과는 나만 볼 수 있어요',
      _ => null,
    };
  }

  List<Widget> _buildRoleHeading(
    Size size,
    double scale,
    MafiaRole role,
    Color accent,
    String title, {
    int? seconds,
  }) {
    return [
      Positioned(
        left: 0,
        right: 0,
        top: MafiaPhoneDesign.top(size, _tagTop),
        child: IgnorePointer(
          child: Text(
            roleTag(role),
            textAlign: TextAlign.center,
            style: mafiaNoirBody(
              13 * scale,
              color: accent,
              weight: FontWeight.w700,
              letterSpacing: 6.5 * scale,
            ),
          ),
        ),
      ),
      Positioned(
        left: 0,
        right: 0,
        top: MafiaPhoneDesign.top(size, _promptTop),
        child: IgnorePointer(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              maxLines: 1,
              textAlign: TextAlign.center,
              style: mafiaNoirDisplay(
                MafiaPhoneStatusText.promptFontSize * scale,
                height: 1,
              ),
            ),
          ),
        ),
      ),
      if (seconds != null)
        Positioned(
          left: 0,
          right: 0,
          top: MafiaPhoneDesign.top(size, _timerTop),
          child: IgnorePointer(
            child: Text(
              mafiaNoirClock(seconds),
              textAlign: TextAlign.center,
              style: mafiaNoirDisplay(
                MafiaPhoneStatusText.timerFontSize * scale,
                color: MafiaColors.noirBrass,
              ),
            ),
          ),
        ),
    ];
  }

  List<Widget> _buildSelectionLayer(Size size, double scale) {
    final current = role!;
    final accent = current.nightAction.accentColor;
    final caption = _caption(current);
    return [
      ..._buildRoleHeading(
        size,
        scale,
        current,
        accent,
        nightTitle(current),
        seconds: remainingSeconds,
      ),
      Positioned(
        left: 0,
        right: 0,
        top: MafiaPhoneDesign.top(
          size,
          MafiaPlayerSelectGrid.topFor(players.length),
        ),
        child: MafiaPlayerSelectGrid(
          players: players,
          selectedUid: selectedUid,
          allySelectedUids: allySelectedUids,
          selectionColor: accent,
          selectedBanner: MafiaNoirBannerSpec(
            label: bannerLabel(current),
            color: current.nightAction == MafiaNightAction.eliminate
                ? MafiaColors.noirScarlet
                : accent,
            textColor: current.nightAction == MafiaNightAction.eliminate
                ? MafiaColors.noirPaper
                : MafiaColors.noirInk,
          ),
          // 영매·도둑은 **사망자**를 고릅니다. 이 값을 넘기지 않으면 명단이
          // 보이는데도 아무도 눌리지 않습니다(2026-08).
          selectsDead: current.targetsDead,
          onSelect: onSelect,
        ),
      ),
      if (caption != null)
        Positioned(
          left: 0,
          right: 0,
          top: MafiaPhoneDesign.top(
            size,
            MafiaPlayerSelectGrid.designBottom(players.length) + 4,
          ),
          child: IgnorePointer(
            child: Text(
              caption,
              textAlign: TextAlign.center,
              style: mafiaNoirBody(13 * scale, color: const Color(0xFF6E6A5D)),
            ),
          ),
        ),
    ];
  }

  Color _confirmColor() => switch (role?.nightAction) {
    MafiaNightAction.eliminate => MafiaColors.noirBlood,
    null || MafiaNightAction.none => MafiaColors.noirPaper,
    final action => action.accentColor,
  };

  Color _confirmTextColor() => role?.nightAction == MafiaNightAction.eliminate
      ? MafiaColors.noirPaper
      : MafiaColors.noirInk;

  /// 선택 완료 버튼 문구입니다(예: `서아 제거`).
  String _confirmLabel() {
    final current = role;
    final target = players
        .where((player) => player.uid == selectedUid)
        .firstOrNull;
    if (current == null || target == null) return '선택 완료';
    return '${target.nickname} ${current.nightPromptVerb}';
  }

  /// 조사 결과 화면입니다(P4 두 번째 시안).
  ///
  /// 선택 화면과 달리 대상 한 명을 크게 보여줍니다. 결과 문구는 서버가 계산한
  /// 값을 그대로 표시합니다. 밀러·마피아 보스처럼 실제 진영과 다르게 보이는
  /// 역할이 있으므로, 클라이언트가 진영을 다시 계산하면 안 됩니다.
  List<Widget> _buildInvestigationResult(
    Size size,
    double scale,
    MafiaNightInvestigationResult result,
  ) {
    final current = role;
    final accent = current?.nightAction.accentColor ?? MafiaColors.noirPolice;
    // 확정(2026-08): 조사 결과가 마피아면 테두리를 마피아 진영 색으로 칠합니다.
    // 문구를 읽기 전에 색만으로 결과가 먼저 읽힙니다.
    final mafia = result.showsMafia;
    final borderColor = mafia ? MafiaColors.noirScarlet : accent;
    final posterWidth = 230 * scale;
    final posterHeight = 320 * scale;
    final bannerText = result.asFactionSentence
        ? (mafia ? '마피아' : '마피아 아님')
        : result.verdict;

    return [
      if (current != null)
        ..._buildRoleHeading(size, scale, current, accent, result.title),
      Positioned(
        left: (size.width - posterWidth) / 2,
        top: MafiaPhoneDesign.top(size, 196),
        width: posterWidth,
        height: posterHeight,
        child: IgnorePointer(
          child: MafiaNoirPoster(
            player: result.target,
            width: posterWidth,
            height: posterHeight,
            grayscale: false,
            borderColor: borderColor,
            circleColor: mafia ? MafiaColors.noirBlood : MafiaColors.noirTeal,
            glowColor: borderColor,
            banner: MafiaNoirBannerSpec(
              label: bannerText,
              color: mafia ? MafiaColors.noirScarlet : accent,
              textColor: mafia ? MafiaColors.noirPaper : MafiaColors.noirInk,
              top: 0.53,
              angle: -16,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
      // 결과 문장 — 진영 조사는 `OO님은 마피아입니다`처럼 문장으로 적습니다.
      Positioned(
        left: MafiaPhoneDesign.left(size, 24),
        right: MafiaPhoneDesign.left(size, 24),
        top: MafiaPhoneDesign.top(size, 546),
        child: IgnorePointer(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              result.displayText,
              maxLines: 1,
              textAlign: TextAlign.center,
              style: mafiaNoirDisplay(
                30 * scale,
                color: mafia ? MafiaColors.noirRose : MafiaColors.noirPaper,
              ),
            ),
          ),
        ),
      ),
      Positioned(
        left: 0,
        right: 0,
        top: MafiaPhoneDesign.top(size, 592),
        child: IgnorePointer(
          child: Text(
            '이 결과는 나만 볼 수 있어요',
            textAlign: TextAlign.center,
            style: mafiaNoirBody(14 * scale),
          ),
        ),
      ),
      MafiaPhoneActionButton(
        label: '확인',
        onTap: onConfirmResult,
        enabled: onConfirmResult != null,
      ),
    ];
  }

  /// 행동을 끝내고 다른 사람을 기다리는 화면입니다(P5 시안).
  ///
  /// 대상을 고르지 않는 역할도 이 화면을 봅니다. 그래야 옆 사람이 훔쳐봐도
  /// 누가 특수직인지 드러나지 않습니다.
  List<Widget> _buildWaiting(Size size, double scale) {
    final seconds = remainingSeconds;
    return [
      // 보름달과 도시 — 고르지 않는 신분과 행동을 끝낸 신분이 같은 풍경을 봅니다.
      Positioned(
        left: 0,
        right: 0,
        top: MafiaPhoneDesign.top(size, 116),
        child: IgnorePointer(
          child: Center(
            child: MafiaNoirCityscape(width: size.width, height: 260 * scale),
          ),
        ),
      ),
      Positioned(
        left: MafiaPhoneDesign.left(size, 31),
        right: MafiaPhoneDesign.left(size, 31),
        top: MafiaPhoneDesign.top(size, 376),
        height: 2,
        child: const ColoredBox(color: MafiaColors.noirBrass),
      ),
      // 확정(2026-08): **밤에 할 일이 없는 신분**(시민 등)에게는 '완료' 문구를
      // 띄우지 않습니다. 고른 것이 없는데 '완료했습니다'는 말이 맞지 않습니다.
      Positioned(
        left: 0,
        right: 0,
        top: MafiaPhoneDesign.top(size, 412),
        child: IgnorePointer(
          child: _hasSubmittedAction
              ? _MafiaSubmissionConfirmation(scale: scale, label: '선택을 완료했습니다')
              : Text(
                  isWrappingUp ? '곧 아침이 옵니다' : '조용히 밤을 보내세요',
                  textAlign: TextAlign.center,
                  style: mafiaNoirDisplay(34 * scale),
                ),
        ),
      ),
      Positioned(
        left: 0,
        right: 0,
        top: MafiaPhoneDesign.top(size, _hasSubmittedAction ? 512 : 466),
        child: IgnorePointer(
          child: Text(
            isWrappingUp || _hasSubmittedAction
                ? waitingMessage
                : '화면을 켜 둔 채\n아침을 기다려 주세요.',
            textAlign: TextAlign.center,
            style: mafiaNoirBody(15 * scale, height: 1.6),
          ),
        ),
      ),
      if (seconds != null)
        Positioned(
          left: 0,
          right: 0,
          top: MafiaPhoneDesign.top(size, 568),
          child: IgnorePointer(
            child: Center(
              child: Transform.scale(
                scale: scale,
                child: MafiaNoirRuledLabel(
                  label: '아침까지',
                  value: mafiaNoirClock(seconds),
                ),
              ),
            ),
          ),
        ),
    ];
  }
}

/// 밤 화면이 지금 무엇을 보여 주는지입니다. 이 값이 바뀌면 화면이 교차됩니다.
enum _NightViewMode { result, selection, waiting }

/// 선택 직후 서버 응답을 기다리는 시간을 확정 동작처럼 보여 주는 연출입니다.
class _MafiaSubmissionConfirmation extends StatefulWidget {
  const _MafiaSubmissionConfirmation({
    required this.scale,
    required this.label,
  });

  final double scale;
  final String label;

  @override
  State<_MafiaSubmissionConfirmation> createState() =>
      _MafiaSubmissionConfirmationState();
}

class _MafiaSubmissionConfirmationState
    extends State<_MafiaSubmissionConfirmation>
    with TickerProviderStateMixin {
  late final AnimationController _seal;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _seal = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    )..forward();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _seal.addStatusListener(_startPulse);
  }

  void _startPulse(AnimationStatus status) {
    if (status == AnimationStatus.completed) _pulse.repeat(reverse: true);
  }

  @override
  void dispose() {
    _seal
      ..removeStatusListener(_startPulse)
      ..dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_seal, _pulse]),
      builder: (context, _) {
        final intro = Curves.easeOutBack.transform(_seal.value);
        final glow = _pulse.value;
        return Opacity(
          key: const ValueKey('mafia-submission-confirmation'),
          opacity: _seal.value.clamp(0, 1),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.scale(
                scale: (0.62 + intro * 0.38) * (1 + glow * 0.025),
                child: Container(
                  width: 46 * widget.scale,
                  height: 46 * widget.scale,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: MafiaColors.noirSlab,
                    border: Border.all(
                      color: MafiaColors.noirBrass.withValues(
                        alpha: 0.65 + glow * 0.35,
                      ),
                      width: 1.5 * widget.scale,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: MafiaColors.noirBrass.withValues(
                          alpha: 0.10 + glow * 0.10,
                        ),
                        blurRadius: (12 + glow * 8) * widget.scale,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    color: MafiaColors.noirBrass,
                    size: 30 * widget.scale,
                  ),
                ),
              ),
              SizedBox(height: 16 * widget.scale),
              Text(
                widget.label,
                textAlign: TextAlign.center,
                style: mafiaNoirDisplay(30 * widget.scale),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 서버에서 확정된 조사 결과가 기록 카드처럼 자리 잡는 짧은 등장 연출입니다.
class _MafiaInvestigationReveal extends StatelessWidget {
  const _MafiaInvestigationReveal({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: const ValueKey('mafia-investigation-reveal'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 640),
      curve: Curves.easeOutCubic,
      builder: (context, value, result) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 22 * (1 - value)),
            child: Transform.scale(scale: 0.94 + value * 0.06, child: result),
          ),
        );
      },
      child: child,
    );
  }
}

/// 휴대폰에서도 밤 마지막 구간이 멈춘 화면처럼 보이지 않게 새벽빛을 올립니다.
class _MafiaPhoneNightWrapUp extends StatelessWidget {
  const _MafiaPhoneNightWrapUp();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(seconds: 8),
      curve: Curves.easeInOut,
      builder: (context, value, _) {
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                const Color(0xFFB99378).withValues(alpha: 0.18 * value),
                const Color(0xFF4B5067).withValues(alpha: 0.08 * value),
                Colors.transparent,
              ],
              stops: const [0, 0.48, 1],
            ),
          ),
        );
      },
    );
  }
}
