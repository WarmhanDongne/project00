import 'dart:async';

import 'package:flutter/material.dart';
import 'package:project00/core/assets/game_image.dart';
import 'package:project00/games/mafia/models/mafia_composition.dart';
import 'package:project00/games/mafia/models/mafia_role.dart';
import 'package:project00/games/mafia/models/mafia_roles.dart';
import 'package:project00/games/shared/widgets/game_setup_back_button.dart';
import 'package:project00/gen/assets.gen.dart';

//=======================역할 배치 (게임 시작 전)==============================
/// 마피아는 게임을 시작할 때 **자리 배치 대신 역할 배치**를 합니다
/// (시안 `1149:334`, 확정 2026-08).
///
/// 다른 게임은 누가 어디 앉는지가 중요해서 자리 배치 화면을 지나갑니다. 마피아는
/// 자리보다 **이번 판에 어떤 신분이 들어가는지**가 판을 좌우하므로, 그 자리에
/// 이 화면을 넣습니다. 자리는 참여 순서대로 자동 배정합니다.
///
/// 고르는 방식(확정 2026-08):
///
/// - 역할을 누르면 **색이 들어오고**(선택), 다시 누르면 회색으로 돌아갑니다.
/// - 고른 역할은 **한 자리씩** 차지합니다.
/// - 남은 자리는 **시민**이 채웁니다. 그래서 시민을 켜 두면 인원이 몇이든
///   구성이 완성되고, 시민을 끄면 고른 역할 수가 인원과 정확히 같아야 합니다.
/// - 마피아 진영이 최소 1명은 있어야 하고, 전원 마피아는 안 됩니다.
///   (서버 `mafiaComposition`이 같은 규칙으로 한 번 더 막습니다)
///
/// 오른쪽 Tip은 **인원별 추천 조합**입니다([MafiaComposition.recommended]).
/// 서버가 쓰는 표와 같은 값이라, 아무것도 건드리지 않고 시작하면 추천 조합으로
/// 진행됩니다.
class MafiaRoleSetupScreen extends StatefulWidget {
  const MafiaRoleSetupScreen({
    super.key,
    required this.playerCount,
    required this.onConfirm,
    required this.onCancel,
  });

  /// 이번 판 인원입니다. 고른 역할의 합이 이 수와 맞아야 시작할 수 있습니다.
  final int playerCount;

  /// 고른 구성(`역할 id → 인원수`)으로 게임을 시작합니다.
  ///
  /// false를 돌려주면 화면에 그대로 머무릅니다(서버가 거절한 경우).
  final Future<bool> Function(Map<String, int> composition) onConfirm;

  /// 뒤로 나갑니다(게임 선택 해제). 시안에 버튼이 없어 기기 뒤로 가기만 받습니다.
  final Future<bool> Function() onCancel;

  //=======================시안 좌표 (1280 × 800)==============================
  static const Size designSize = Size(1280, 800);

  @override
  State<MafiaRoleSetupScreen> createState() => _MafiaRoleSetupScreenState();
}

/// 시안 색입니다(스크린샷에서 그대로 읽은 값).
abstract final class _Palette {
  static const page = Color(0xFFFBFAF9);
  static const panel = Colors.white;
  static const citizenHeader = Color(0xFF72B4FF);
  static const mafiaHeader = Color(0xFFFF8585);
  static const neutralHeader = Color(0xFFF0FF4C);
  static const divider = Color(0xFFE8E8E8);
  static const shadow = Color(0x22000000);
  static const confirm = Color(0xFF534AB7);
  static const confirmOff = Color(0xFFBDBDBD);

  /// 고르지 않은 역할의 이름 색입니다(확정: 선택하면 검정, 아니면 회색).
  static const unselectedText = Color(0xFFBDBDBD);
}

/// 한 팀 판입니다. 시안은 색 띠(머리) 위에 흰 판이 얹혀 있습니다.
@immutable
class _Panel {
  const _Panel({
    required this.title,
    required this.headerColor,
    required this.titleColor,
    required this.header,
    required this.body,
    required this.titleOffset,
    required this.rowDividers,
    required this.dividerLeft,
  });

  final String title;
  final Color headerColor;
  final Color titleColor;

  /// 색 띠입니다(흰 판이 아래쪽을 덮어 위쪽만 보입니다).
  final Rect header;
  final Rect body;

  /// 제목 글자 왼쪽·위 자리입니다.
  final Offset titleOffset;

  /// 줄을 나누는 가로선의 y입니다. 줄 높이도 이 값으로 정합니다.
  final List<double> rowDividers;

  /// 가로선이 시작하는 x입니다(시안이 판마다 조금 다릅니다).
  final double dividerLeft;

  /// [index]번째 줄의 가운데 y입니다.
  double rowCenter(int index) {
    final edges = [body.top, ...rowDividers, body.bottom];
    return (edges[index] + edges[index + 1]) / 2;
  }

  /// [index]번째 줄에서 가로선이 닿는 오른쪽 x입니다.
  double dividerRight(int index, List<_RoleSlot> slots) {
    // 시안은 그 줄에 놓인 마지막 칸까지만 선을 긋습니다.
    final row = slots.where((slot) => slot.row == index);
    if (row.isEmpty) return body.right - 66;
    final lastX = row
        .map((slot) => slot.iconLeft)
        .reduce((a, b) => a > b ? a : b);
    return (lastX + 238).clamp(body.left, body.right - 66);
  }
}

/// 판 안에 놓이는 역할 한 칸입니다(아이콘 80 × 80 + 이름).
@immutable
class _RoleSlot {
  const _RoleSlot(this.roleId, {required this.iconLeft, required this.row});

  final String roleId;

  /// 시안 기준 아이콘 왼쪽 x입니다.
  final double iconLeft;

  /// 판 안에서 몇 번째 줄인지입니다.
  final int row;
}

class _MafiaRoleSetupScreenState extends State<MafiaRoleSetupScreen> {
  //=======================시안 좌표==============================
  static const double _iconSize = 80;

  /// 아이콘 오른쪽에서 이름까지의 거리입니다(시안 98 → 181).
  static const double _labelGap = 83;

  static const _citizenPanel = _Panel(
    title: '시민팀',
    headerColor: _Palette.citizenHeader,
    titleColor: Colors.white,
    header: Rect.fromLTWH(59, 51, 1188, 275.5),
    body: Rect.fromLTWH(59, 111.4, 1188, 275.5),
    titleOffset: Offset(108, 62),
    rowDividers: [207.6, 292],
    dividerLeft: 97.5,
  );

  static const _mafiaPanel = _Panel(
    title: '마피아팀',
    headerColor: _Palette.mafiaHeader,
    titleColor: Colors.white,
    header: Rect.fromLTWH(59, 430, 494, 275.5),
    body: Rect.fromLTWH(59, 490.5, 494, 275.5),
    titleOffset: Offset(108, 441),
    rowDividers: [586, 670],
    dividerLeft: 87,
  );

  static const _neutralPanel = _Panel(
    title: '중립',
    headerColor: _Palette.neutralHeader,
    titleColor: Colors.black,
    header: Rect.fromLTWH(465, 430, 531, 275.5),
    body: Rect.fromLTWH(465, 490.4, 531, 275.5),
    titleOffset: Offset(607, 441),
    rowDividers: [586.6, 670.6],
    dividerLeft: 512.4,
  );

  /// 시안에 그려진 역할과 자리입니다. **순서·자리 모두 시안 그대로**입니다.
  ///
  /// ⚠️ 시안은 `영매`와 `자경단원`의 그림이 서로 바뀌어 있습니다(십자선을 든
  /// 그림이 영매 쪽에, 눈+불꽃이 자경단원 쪽에). 그림 뜻에 맞게 넣었습니다.
  static const _citizenSlots = <_RoleSlot>[
    _RoleSlot('citizen', iconLeft: 98, row: 0),
    _RoleSlot('soldier', iconLeft: 340, row: 0),
    _RoleSlot('reporter', iconLeft: 613, row: 0),
    _RoleSlot('vigilante', iconLeft: 890, row: 0),
    _RoleSlot('police', iconLeft: 98, row: 1),
    _RoleSlot('politician', iconLeft: 340, row: 1),
    _RoleSlot('gangster', iconLeft: 613, row: 1),
    _RoleSlot('doctor', iconLeft: 98, row: 2),
    _RoleSlot('medium', iconLeft: 340, row: 2),
    _RoleSlot('detective', iconLeft: 613, row: 2),
  ];

  static const _mafiaSlots = <_RoleSlot>[
    _RoleSlot('mafia', iconLeft: 98, row: 0),
    _RoleSlot('madam', iconLeft: 340, row: 0),
    _RoleSlot('spy', iconLeft: 98, row: 1),
    _RoleSlot('thief', iconLeft: 340, row: 1),
    _RoleSlot('beast', iconLeft: 98, row: 2),
  ];

  static const _neutralSlots = <_RoleSlot>[
    _RoleSlot('jester', iconLeft: 613, row: 0),
    _RoleSlot('cult_leader', iconLeft: 771, row: 0),
    _RoleSlot('executioner', iconLeft: 613, row: 1),
    _RoleSlot('serial_killer', iconLeft: 613, row: 2),
  ];

  /// 오른쪽 Tip 카드와 시작 버튼입니다.
  static const Rect _tipCard = Rect.fromLTWH(1040, 430, 208, 257);
  static const Rect _tipIcon = Rect.fromLTWH(1048, 441, 41, 41);
  static const Offset _tipTitle = Offset(1093, 441);
  static const Offset _tipSubtitle = Offset(1069, 492);
  static const Rect _tipList = Rect.fromLTWH(1069, 510, 168, 168);
  static const Rect _confirmButton = Rect.fromLTWH(1039, 702, 208, 64);

  /// 남은 자리를 채우는 역할입니다. 이 역할만 인원수가 1보다 커질 수 있습니다.
  static const String _fillerRoleId = 'citizen';

  /// **끌 수 없는 필수 신분**입니다(확정 2026-08).
  ///
  /// 마피아가 없으면 아무 일도 일어나지 않는 판이 되고, 시민이 없으면 남은
  /// 자리를 채울 역할이 없어 인원과 딱 맞는 조합만 시작할 수 있습니다. 둘은
  /// 게임의 바탕이라 회색으로 되돌릴 수 없게 잠가 둡니다.
  static const Set<String> _requiredRoleIds = {'mafia', _fillerRoleId};

  /// 지금 고른 역할입니다.
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    // 아무것도 건드리지 않고 시작하면 추천 조합으로 진행됩니다.
    _selected = {..._recommended.keys, ..._requiredRoleIds};
  }

  Map<String, int> get _recommended =>
      MafiaComposition.recommended[widget.playerCount] ??
      const {'mafia': 1, 'citizen': 3};

  /// 시민(채우는 역할)을 뺀, 한 자리씩 차지하는 역할 수입니다.
  int get _specialCount => _selected.where((id) => id != _fillerRoleId).length;

  /// 시민이 채우게 되는 자리 수입니다.
  int get _fillerCount => _selected.contains(_fillerRoleId)
      ? widget.playerCount - _specialCount
      : 0;

  /// 지금 고른 구성입니다(`역할 id → 인원수`).
  Map<String, int> get _composition => {
    for (final id in _selected)
      if (id != _fillerRoleId) id: 1,
    if (_fillerCount > 0) _fillerRoleId: _fillerCount,
  };

  /// 이 구성으로 시작할 수 있는지입니다. 서버와 같은 규칙입니다.
  bool get _canStart {
    final composition = _composition;
    final total = composition.values.fold<int>(0, (sum, n) => sum + n);
    if (total != widget.playerCount) return false;
    var mafiaCount = 0;
    for (final entry in composition.entries) {
      if (MafiaRoles.find(entry.key)?.faction == MafiaFaction.mafia) {
        mafiaCount += entry.value;
      }
    }
    return mafiaCount >= 1 && mafiaCount < widget.playerCount;
  }

  bool _isSubmitting = false;

  /// 뒤로 가기를 처리하는 중인지입니다(자리 배치 화면과 같은 동작).
  bool _isCancelling = false;

  /// 뒤로 갑니다. 게임 선택이 풀리면 화면을 닫습니다.
  Future<void> _cancel() async {
    if (_isSubmitting || _isCancelling || !mounted) return;
    setState(() => _isCancelling = true);
    final canLeave = await widget.onCancel();
    if (!mounted) return;
    if (canLeave) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _isCancelling = false);
  }

  Future<void> _confirm() async {
    if (_isSubmitting || !_canStart) return;
    setState(() => _isSubmitting = true);
    final started = await widget.onConfirm(_composition);
    if (!mounted || started) return;
    setState(() => _isSubmitting = false);
  }

  void _toggle(String roleId) {
    // 필수 신분은 끌 수 없습니다. 눌러도 아무 일도 일어나지 않습니다.
    if (_requiredRoleIds.contains(roleId)) return;
    setState(() {
      if (!_selected.remove(roleId)) _selected.add(roleId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_cancel());
      },
      child: Scaffold(
        backgroundColor: _Palette.page,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(
              constraints.hasBoundedWidth
                  ? constraints.maxWidth
                  : MafiaRoleSetupScreen.designSize.width,
              constraints.hasBoundedHeight
                  ? constraints.maxHeight
                  : MafiaRoleSetupScreen.designSize.height,
            );
            final design = MafiaRoleSetupScreen.designSize;
            final scale =
                (size.width / design.width) < (size.height / design.height)
                ? size.width / design.width
                : size.height / design.height;
            // 화면 비율이 시안과 달라도 전체를 가운데로 모읍니다.
            final dx = (size.width - design.width * scale) / 2;
            final dy = (size.height - design.height * scale) / 2;

            Widget place(Rect rect, Widget child) => Positioned(
              left: dx + rect.left * scale,
              top: dy + rect.top * scale,
              width: rect.width * scale,
              height: rect.height * scale,
              child: child,
            );

            return Stack(
              children: [
                ..._buildPanel(_citizenPanel, _citizenSlots, scale, place),
                // 시안은 두 판이 x 465~553에서 겹치고, **마피아팀이 위**에
                // 그려집니다. 순서를 바꾸면 마담·도둑 이름이 중립 판에 가립니다.
                ..._buildPanel(_neutralPanel, _neutralSlots, scale, place),
                ..._buildPanel(_mafiaPanel, _mafiaSlots, scale, place),
                ..._buildTip(scale, place),
                place(_confirmButton, _buildConfirmButton(scale)),
                // 뒤로가기는 자리 배치 화면과 **같은 버튼·같은 자리**입니다.
                Positioned(
                  left: 0,
                  top: 0,
                  child: SafeArea(
                    child: Padding(
                      padding: GameSetupBackButton.rowPadding,
                      child: SizedBox(
                        height: GameSetupBackButton.rowHeight,
                        child: GameSetupBackButton(
                          isBusy: _isCancelling,
                          onPressed: () => unawaited(_cancel()),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  //=======================팀 판==============================
  List<Widget> _buildPanel(
    _Panel panel,
    List<_RoleSlot> slots,
    double scale,
    Widget Function(Rect, Widget) place,
  ) {
    final radius = BorderRadius.circular(24 * scale);
    return [
      // 색 띠 → 흰 판 순서로 얹으면 시안처럼 위쪽만 색이 남습니다.
      place(
        panel.header,
        DecoratedBox(
          decoration: BoxDecoration(
            color: panel.headerColor,
            borderRadius: radius,
          ),
        ),
      ),
      place(
        Rect.fromLTWH(
          panel.titleOffset.dx,
          panel.titleOffset.dy,
          panel.header.right - panel.titleOffset.dx,
          48,
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            panel.title,
            style: TextStyle(
              color: panel.titleColor,
              fontSize: 28 * scale,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      place(
        panel.body,
        DecoratedBox(
          decoration: BoxDecoration(
            color: _Palette.panel,
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: _Palette.shadow,
                blurRadius: 6 * scale,
                offset: Offset(0, 2 * scale),
              ),
            ],
          ),
        ),
      ),
      // 줄을 나누는 가로선입니다.
      for (var index = 0; index < panel.rowDividers.length; index += 1)
        place(
          Rect.fromLTWH(
            panel.dividerLeft,
            panel.rowDividers[index],
            panel.dividerRight(index, slots) - panel.dividerLeft,
            1,
          ),
          const ColoredBox(color: _Palette.divider),
        ),
      for (final slot in slots) _buildSlot(panel, slots, slot, scale, place),
    ];
  }

  Widget _buildSlot(
    _Panel panel,
    List<_RoleSlot> slots,
    _RoleSlot slot,
    double scale,
    Widget Function(Rect, Widget) place,
  ) {
    final role = MafiaRoles.find(slot.roleId);
    final selected = _selected.contains(slot.roleId);
    final centerY = panel.rowCenter(slot.row);
    // 이름이 다음 칸까지 넘치지 않게, 같은 줄의 다음 칸까지를 폭으로 씁니다.
    final sameRow = slots.where((other) => other.row == slot.row).toList()
      ..sort((a, b) => a.iconLeft.compareTo(b.iconLeft));
    final nextIndex = sameRow.indexOf(slot) + 1;
    final right = nextIndex < sameRow.length
        ? sameRow[nextIndex].iconLeft - 12
        : panel.body.right - 24;

    return place(
      Rect.fromLTWH(
        slot.iconLeft,
        centerY - _iconSize / 2,
        right - slot.iconLeft,
        _iconSize,
      ),
      _RoleTile(
        role: role,
        selected: selected,
        isRequired: _requiredRoleIds.contains(slot.roleId),
        scale: scale,
        iconSize: _iconSize,
        labelGap: _labelGap,
        onTap: () => _toggle(slot.roleId),
      ),
    );
  }

  //=======================Tip: 인원별 추천 조합==============================
  List<Widget> _buildTip(double scale, Widget Function(Rect, Widget) place) {
    final entries = _recommended.entries.toList();
    return [
      place(
        _tipCard,
        DecoratedBox(
          decoration: BoxDecoration(
            color: _Palette.panel,
            borderRadius: BorderRadius.circular(16 * scale),
            boxShadow: [
              BoxShadow(
                color: _Palette.shadow,
                blurRadius: 6 * scale,
                offset: Offset(0, 2 * scale),
              ),
            ],
          ),
        ),
      ),
      place(_tipIcon, _tipBulb()),
      place(
        Rect.fromLTWH(_tipTitle.dx, _tipTitle.dy, 120, 44),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Tip',
            style: TextStyle(
              color: Colors.black,
              fontSize: 28 * scale,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      place(
        Rect.fromLTWH(_tipSubtitle.dx, _tipSubtitle.dy, 170, 18),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '${widget.playerCount}인원수일때 추천하는 조합',
            style: TextStyle(color: Colors.black, fontSize: 11 * scale),
          ),
        ),
      ),
      place(
        _tipList,
        // 확정(2026-08): 아이콘만 보여 줍니다(`x1` 같은 숫자는 빼기로 했습니다).
        // 인원이 많으면 추천 역할도 늘어나므로 넘치지 않게 담습니다.
        SingleChildScrollView(
          child: Wrap(
            spacing: 10 * scale,
            runSpacing: 8 * scale,
            children: [
              for (final entry in entries)
                _TipIcon(role: MafiaRoles.find(entry.key), scale: scale),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _tipBulb() => Assets.games.mafia.images.icons.iconTipBulb.game.image(
    fit: BoxFit.contain,
    filterQuality: FilterQuality.high,
  );

  //=======================설정 완료==============================
  Widget _buildConfirmButton(double scale) {
    final enabled = _canStart && !_isSubmitting;
    return Semantics(
      button: true,
      enabled: enabled,
      label: '설정 완료',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? _confirm : null,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: enabled ? _Palette.confirm : _Palette.confirmOff,
            borderRadius: BorderRadius.circular(14 * scale),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: _Palette.shadow,
                      blurRadius: 8 * scale,
                      offset: Offset(0, 3 * scale),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              '설정 완료',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20 * scale,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

//=======================역할 한 칸==============================
/// 아이콘 + 이름입니다. 확정(2026-08): **고르면 색이 들어오고, 고르지 않으면
/// 회색**입니다. 이름도 고르면 검정, 아니면 회색입니다.
///
/// 마피아·시민처럼 [isRequired]인 신분은 **끌 수 없습니다.** 늘 색이 들어와
/// 있고 눌러도 회색으로 돌아가지 않습니다.
class _RoleTile extends StatelessWidget {
  const _RoleTile({
    required this.role,
    required this.selected,
    required this.scale,
    required this.iconSize,
    required this.labelGap,
    required this.onTap,
    this.isRequired = false,
  });

  final MafiaRole? role;
  final bool selected;
  final double scale;
  final double iconSize;
  final double labelGap;
  final VoidCallback onTap;

  /// 끌 수 없는 필수 신분인지입니다.
  final bool isRequired;

  /// 색을 완전히 빼는 행렬입니다(회색조).
  static const List<double> _grayscale = <double>[
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 1, 0, //
  ];

  static const Duration _fade = Duration(milliseconds: 180);

  @override
  Widget build(BuildContext context) {
    final icon = role?.icon;
    final side = iconSize * scale;

    return Semantics(
      button: !isRequired,
      selected: selected,
      enabled: !isRequired,
      label: isRequired
          ? '${role?.displayName ?? ''} (필수 신분)'
          : role?.displayName ?? '',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // 필수 신분은 누름을 받지 않습니다.
        onTap: isRequired ? null : onTap,
        child: Row(
          children: [
            SizedBox(
              width: side,
              height: side,
              child: icon == null
                  ? const SizedBox.shrink()
                  : AnimatedOpacity(
                      opacity: selected ? 1 : 0.72,
                      duration: _fade,
                      child: selected
                          ? icon.image(fit: BoxFit.contain)
                          : ColorFiltered(
                              colorFilter: const ColorFilter.matrix(_grayscale),
                              child: icon.image(fit: BoxFit.contain),
                            ),
                    ),
            ),
            SizedBox(width: (labelGap - iconSize) * scale),
            Expanded(
              child: AnimatedDefaultTextStyle(
                duration: _fade,
                style: TextStyle(
                  color: selected ? Colors.black : _Palette.unselectedText,
                  fontSize: 28 * scale,
                  fontWeight: FontWeight.w700,
                ),
                child: Text(
                  role?.displayName ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tip 카드의 추천 역할 하나입니다.
///
/// 확정(2026-08): 아이콘만 둡니다. `x1` 같은 숫자는 빼기로 했습니다.
class _TipIcon extends StatelessWidget {
  const _TipIcon({required this.role, required this.scale});

  final MafiaRole? role;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final icon = role?.icon;
    final side = 40 * scale;
    return SizedBox(
      width: side,
      height: side,
      child: icon == null
          ? const SizedBox.shrink()
          : icon.image(fit: BoxFit.contain),
    );
  }
}
