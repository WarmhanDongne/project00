import 'package:flutter/material.dart';
import 'package:project00/games/mafia/models/mafia_player.dart';
import 'package:project00/games/mafia/models/mafia_role.dart';
import 'package:project00/games/mafia/models/mafia_roles.dart';
import 'package:project00/games/mafia/widgets/phone/mafia_phone_layout.dart';
import 'package:project00/games/mafia/widgets/phone/player_select_grid.dart';

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
  });

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
}

//=======================P2~P5 밤 화면==============================
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

  //=======================시안 기준 좌표==============================
  // 공용 좌표(버튼·보관 카드)는 [MafiaPhoneDesign]에 있습니다.
  // 안내·타이머는 모든 단계 공통 자리(MafiaPhoneStatusText)를 씁니다.
  static const double _promptTop = MafiaPhoneStatusText.promptTop;
  static const double _timerTop = MafiaPhoneStatusText.timerTop;

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
                    _NightViewMode.result => _buildInvestigationResult(
                      size,
                      scale,
                      result!,
                    ),
                    _NightViewMode.selection => [
                      ..._buildSelectionLayer(size, scale),
                      MafiaPhoneActionButton(
                        label: '선택 완료',
                        onTap: onConfirm,
                        enabled: selectedUid != null && onConfirm != null,
                        colorlessWhenDisabled: true,
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

  List<Widget> _buildSelectionLayer(Size size, double scale) {
    final current = role!;
    return [
      // 안내 문구 — 동사만 역할 색으로 강조합니다.
      Positioned(
        left: 0,
        right: 0,
        top: MafiaPhoneDesign.top(size, _promptTop),
        child: IgnorePointer(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: current.nightPromptVerb,
                  // 진영색이 아니라 행동 의미의 색입니다(치료=초록 등).
                  style: TextStyle(color: current.nightAction.accentColor),
                ),
                const TextSpan(text: ' 할 대상을 선택하세요'),
              ],
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: MafiaPhoneStatusText.promptFontSize * scale,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      if (remainingSeconds != null)
        Positioned(
          left: 0,
          right: 0,
          top: MafiaPhoneDesign.top(size, _timerTop),
          child: IgnorePointer(
            child: Text(
              '$remainingSeconds초',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: MafiaPhoneStatusText.timerFontSize * scale,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
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
          selectionColor: current.nightAction.accentColor,
          onSelect: onSelect,
        ),
      ),
    ];
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
    final accent = role?.nightAction.accentColor ?? const Color(0xFF44ABFF);
    // 확정(2026-08): 조사 결과가 마피아면 테두리를 마피아 진영 색으로 칠합니다.
    // 문구를 읽기 전에 색만으로 결과가 먼저 읽힙니다.
    final borderColor = result.showsMafia ? MafiaFactionColors.mafia : accent;
    const profileSize = 188.0;

    return [
      // "조사 결과"
      Positioned(
        left: 0,
        right: 0,
        top: MafiaPhoneDesign.top(size, _promptTop),
        child: IgnorePointer(
          child: Text(
            result.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: accent,
              fontSize: MafiaPhoneStatusText.promptFontSize * scale,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      // 결과 값 (예: 시민 / 마피아) — 시안 고유 자리(151)라 통일 대상이 아닙니다.
      Positioned(
        left: 0,
        right: 0,
        top: MafiaPhoneDesign.top(size, 151),
        child: IgnorePointer(
          child: Text(
            result.verdict,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 36 * scale,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      // 조사한 대상
      Positioned(
        left: (size.width - profileSize * scale) / 2,
        top: MafiaPhoneDesign.top(size, 295),
        width: profileSize * scale,
        height: profileSize * scale,
        child: IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10 * scale),
              border: Border.all(color: borderColor, width: 3 * scale),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10 * scale),
              child: MafiaProfileImage(url: result.target.profileImageUrl),
            ),
          ),
        ),
      ),
      Positioned(
        left: 0,
        right: 0,
        top: MafiaPhoneDesign.top(size, 490.02),
        child: IgnorePointer(
          child: Text(
            result.target.nickname,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 40 * scale),
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
    return [
      // 확정(2026-08): **밤에 할 일이 없는 신분**(시민 등)에게는 이 문구를
      // 띄우지 않습니다. 고른 것이 없는데 '완료했습니다'는 말이 맞지 않고,
      // 옆에서 보면 아무 것도 안 하는 신분임이 드러납니다.
      if (_hasSubmittedAction)
        Positioned(
          left: 0,
          right: 0,
          top: MafiaPhoneDesign.top(size, MafiaPhoneStatusText.waitingTop),
          child: IgnorePointer(
            child: Text(
              '선택을 완료했습니다',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: MafiaPhoneStatusText.waitingFontSize * scale,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      Positioned(
        left: 0,
        right: 0,
        top: MafiaPhoneDesign.top(size, MafiaPhoneStatusText.waitingSubTop),
        child: IgnorePointer(
          // 시안은 한 줄(nowrap)입니다. 좁은 기기에서 두 줄로 흐르지 않게
          // 필요한 만큼만 줄여 한 줄을 유지합니다.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '다른 플레이어의 행동을 기다리는 중…',
              maxLines: 1,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: MafiaPhoneStatusText.waitingSubFontSize * scale,
                fontWeight: FontWeight.w300,
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
