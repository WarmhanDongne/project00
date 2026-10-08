// 태블릿 게임 시작 전, 추천 신분을 카드로 보여 주고 추가·삭제하는 화면.
import 'dart:async';
import 'dart:math' as math;

import 'package:game_mafia/game_theme.dart';
import 'package:game_mafia/shared/widgets/noir.dart';
import 'package:flutter/material.dart';
import 'package:game_kit/recovery/widgets/game_request_notice.dart';
import 'package:game_kit/tablet/widgets/game_setup_back_button.dart';
import 'package:game_mafia/shared/models/game_composition.dart';
import 'package:game_mafia/shared/models/game_rules.dart';
import 'package:game_mafia/game_copy.dart';
import 'package:game_mafia/shared/models/role.dart';
import 'package:game_mafia/shared/models/role_catalog.dart';
import 'package:game_mafia/tablet/widgets/role_setup_card.dart';

/// 신분 한 종류를 세로 카드 한 장으로 표시합니다. 추천 인원수는 보존하고,
/// 시민을 선택한 동안에는 남은 자리를 시민으로 채웁니다.
/// 서버에 전달하는 구성과 검증 규칙은 기존 역할 배치 계약을 따릅니다.
class MafiaRoleSetupScreen extends StatefulWidget {
  const MafiaRoleSetupScreen({
    super.key,
    required this.playerCount,
    required this.onConfirm,
    required this.onCancel,
    this.onRulesChanged,
  });

  final ValueChanged<MafiaRules>? onRulesChanged;
  final int playerCount;
  final Future<bool> Function(Map<String, int> composition) onConfirm;
  final Future<bool> Function() onCancel;

  static const Size designSize = Size(1280, 800);

  @override
  State<MafiaRoleSetupScreen> createState() => _MafiaRoleSetupScreenState();
}

class _MafiaRoleSetupScreenState extends State<MafiaRoleSetupScreen> {
  // Noir Poster 시안 ①: 먹색 무대 위 종이색 글자입니다.
  static const _page = MafiaColors.noirInk;
  static const _ink = MafiaColors.noirPaper;
  static const _motion = Duration(milliseconds: 280);

  // 기존 설정 화면에서 선택 가능했던 19종만 제공합니다.
  static const _roleIds = [
    'citizen',
    'mafia',
    'police',
    'doctor',
    'soldier',
    'politician',
    'medium',
    'gangster',
    'detective',
    'reporter',
    'vigilante',
    'spy',
    'beast',
    'madam',
    'thief',
    'jester',
    'executioner',
    'serial_killer',
    'cult_leader',
  ];

  late Map<String, int> _selected;
  bool _pickerOpen = false;
  bool _isSubmitting = false;
  bool _isCancelling = false;
  String? _requestError;
  String? _lastAdded;
  MafiaRules _rules = const MafiaRules();
  String _preset = '확장';
  String? _editingRole;
  Timer? _editTimer;
  final Set<int> _heldPointers = {};
  double _dragOffset = 0;

  bool get _busy => _isSubmitting || _isCancelling;

  @override
  void initState() {
    super.initState();
    _resetRecommended();
  }

  @override
  void didUpdateWidget(covariant MafiaRoleSetupScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playerCount != widget.playerCount) {
      _endEditing();
      _resetRecommended();
      _preset = '확장';
      _pickerOpen = false;
      _lastAdded = null;
      _requestError = null;
    }
  }

  @override
  void dispose() {
    _editTimer?.cancel();
    super.dispose();
  }

  void _endEditing() {
    _editTimer?.cancel();
    _editingRole = null;
    _dragOffset = 0;
  }

  void _scheduleEditingEnd() {
    _editTimer?.cancel();
    if (_editingRole == null || _heldPointers.isNotEmpty) return;
    _editTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(_endEditing);
    });
  }

  void _beginEditing(String id) {
    if (_busy || id == 'citizen') return;
    _editTimer?.cancel();
    setState(() {
      if (_editingRole != id) _dragOffset = 0;
      _editingRole = id;
      _pickerOpen = false;
    });
    _scheduleEditingEnd();
  }

  int _maximumCount(String id) =>
      widget.playerCount -
      (_specialCount - (_selected[id] ?? 0)) -
      (_selected.containsKey('citizen') ? 1 : 0);

  void _changeCount(String id, int delta) {
    if (_busy || id == 'citizen' || !_selected.containsKey(id)) return;
    final next = (_selected[id]! + delta).clamp(1, _maximumCount(id));
    if (next != _selected[id]) {
      setState(() {
        _preset = '자유';
        _selected[id] = next;
        _requestError = null;
      });
    }
    _scheduleEditingEnd();
  }

  void _dragCount(String id, DragUpdateDetails details) {
    if (_busy || _editingRole != id) return;
    // 숫자 열이 손가락을 따라 움직입니다. 위의 큰 숫자를 아래로 끌어 선택합니다.
    _dragOffset += details.delta.dy;
    // 한 칸마다 44 logical pixels. 경계에서 쌓인 이동량은 남기지 않습니다.
    final steps = (_dragOffset / 44).truncate();
    if (steps == 0) return;
    _dragOffset -= steps * 44;
    _changeCount(id, steps);
  }

  Widget _buildSelectedCard(String id) {
    final editable = !_busy && id != 'citizen';
    final count = id == 'citizen' ? _citizenCount : _selected[id]!;
    return Listener(
      onPointerDown: (event) {
        _heldPointers.add(event.pointer);
        _editTimer?.cancel();
      },
      onPointerUp: (event) {
        _heldPointers.remove(event.pointer);
        _scheduleEditingEnd();
      },
      onPointerCancel: (event) {
        _heldPointers.remove(event.pointer);
        _scheduleEditingEnd();
      },
      child: Semantics(
        excludeSemantics: true,
        label: '${MafiaRoles.find(id)!.displayName} 인원',
        value: '$count',
        increasedValue: editable && count < _maximumCount(id)
            ? '${count + 1}'
            : null,
        decreasedValue: editable && count > 1 ? '${count - 1}' : null,
        onIncrease: editable && count < _maximumCount(id)
            ? () {
                _beginEditing(id);
                _changeCount(id, 1);
              }
            : null,
        onDecrease: editable && count > 1
            ? () {
                _beginEditing(id);
                _changeCount(id, -1);
              }
            : null,
        child: GestureDetector(
          key: ValueKey('edit-role-$id'),
          behavior: HitTestBehavior.opaque,
          onTap: editable ? () => _beginEditing(id) : null,
          onVerticalDragStart: editable
              ? (_) {
                  _dragOffset = 0;
                  _beginEditing(id);
                }
              : null,
          onVerticalDragUpdate: editable
              ? (details) => _dragCount(id, details)
              : null,
          onVerticalDragEnd: editable ? (_) => _scheduleEditingEnd() : null,
          onVerticalDragCancel: editable ? _scheduleEditingEnd : null,
          child: MafiaSetupRoleCard(
            role: MafiaRoles.find(id)!,
            count: count,
            highlighted: _lastAdded == id,
            editing: _editingRole == id,
            maximumCount: id == 'citizen' ? count : _maximumCount(id),
          ),
        ),
      ),
    );
  }

  void _resetRecommended() {
    final recommended =
        MafiaComposition.recommended[widget.playerCount] ??
        const {'mafia': 1, 'citizen': 3};
    _selected = {
      if (recommended.containsKey('citizen'))
        'citizen': recommended['citizen']!,
      for (final entry in recommended.entries)
        if (entry.key != 'citizen') entry.key: entry.value,
    };
  }

  int get _specialCount => _selected.entries
      .where((entry) => entry.key != 'citizen')
      .fold(0, (sum, entry) => sum + entry.value);

  int get _citizenCount => math.max(0, widget.playerCount - _specialCount);

  bool _canAddRole(String id) {
    if (_selected.containsKey(id)) return false;
    // 시민이 선택돼 있으면 최소 한 자리를 남깁니다. 추천 마피아 2명도
    // 카드 종류 수가 아니라 실제 배정 인원수에 포함합니다.
    final citizenMinimum = _selected.containsKey('citizen') || id == 'citizen'
        ? 1
        : 0;
    final additionalCount = id == 'citizen' ? 0 : 1;
    return _specialCount + additionalCount + citizenMinimum <=
        widget.playerCount;
  }

  bool get _canAddAnyRole => _roleIds.any(_canAddRole);

  Map<String, int> get _composition => {
    for (final entry in _selected.entries)
      if (entry.key != 'citizen') entry.key: entry.value,
    if (_selected.containsKey('citizen') && _citizenCount > 0)
      'citizen': _citizenCount,
  };

  String? get _compositionError {
    if (!MafiaComposition.recommended.containsKey(widget.playerCount)) {
      return '마피아는 4~12명이 함께할 수 있어요.';
    }
    final composition = _composition;
    final total = composition.values.fold(0, (sum, count) => sum + count);
    if (total > widget.playerCount) return '참여 인원보다 신분이 많아요. 카드를 삭제해 주세요.';
    if (total < widget.playerCount) return '신분이 부족해요. 시민이나 다른 신분을 추가해 주세요.';
    final mafiaCount = composition.entries
        .where(
          (entry) => MafiaRoles.find(entry.key)?.faction == MafiaFaction.mafia,
        )
        .fold(0, (sum, entry) => sum + entry.value);
    if (mafiaCount == 0) return '마피아팀 신분을 하나 이상 추가해 주세요.';
    final competingNeutral = composition.keys.any(
      (id) => ['serial_killer', 'cult_leader', 'cultist'].contains(id),
    );
    if (mafiaCount >= widget.playerCount ||
        (!competingNeutral && mafiaCount * 2 >= widget.playerCount)) {
      return '시작부터 마피아 승리 조건입니다. 인원을 줄여 주세요.';
    }
    return null;
  }

  void _add(String id) {
    if (_busy || !_canAddRole(id)) return;
    setState(() {
      _endEditing();
      _preset = '자유';
      _selected[id] = 1;
      _lastAdded = id;
      _pickerOpen = false;
      _requestError = null;
    });
  }

  void _remove(String id) {
    if (_busy) return;
    setState(() {
      _endEditing();
      _preset = '자유';
      _selected.remove(id);
      _lastAdded = null;
      _requestError = null;
    });
  }

  int _factionCount(MafiaFaction faction) => _composition.entries
      .where((e) => MafiaRoles.find(e.key)?.faction == faction)
      .fold(0, (sum, e) => sum + e.value);

  String? get _balanceWarning {
    if (_compositionError != null) return null;
    if (_factionCount(MafiaFaction.mafia) * 3 > widget.playerCount) {
      return '마피아 진영 비중이 높습니다';
    }
    if (_composition.keys.length > 6) return '특수 역할이 많은 숙련자 구성입니다';
    for (final id in ['police', 'doctor', 'reporter', 'detective']) {
      if ((_selected[id] ?? 0) > 1) {
        return '${MafiaRoles.find(id)!.displayName}은 1명을 권장합니다';
      }
    }
    return null;
  }

  void _choosePreset(String preset) {
    if (_busy) return;
    setState(() {
      _endEditing();
      _preset = preset;
      _pickerOpen = false;
      if (preset == '기본') {
        _selected = Map.of(MafiaComposition.basicFor(widget.playerCount));
      } else if (preset == '확장') {
        _resetRecommended();
      }
      _lastAdded = null;
      _requestError = null;
    });
  }

  Future<void> _showRules() async {
    final result = await showDialog<MafiaRules>(
      context: context,
      builder: (context) {
        var draft = _rules;
        return StatefulBuilder(
          builder: (context, update) => AlertDialog(
            title: const Text('이번 판 규칙'),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      title: const Text('최후 변론과 찬반 투표'),
                      subtitle: const Text('30초 변론 후 1인 1표 · 투표권자 과반수 찬성 시 처형'),
                      value: draft.trial,
                      onChanged: (value) => update(
                        () => draft = MafiaRules(
                          trial: value,
                          executionReveal: draft.executionReveal,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('처형된 사람의 신분 공개', style: TextStyle(fontSize: 20)),
                    const SizedBox(height: 12),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'role', label: Text('직업')),
                        ButtonSegment(value: 'faction', label: Text('진영만')),
                        ButtonSegment(value: 'hidden', label: Text('비공개')),
                      ],
                      selected: {draft.executionReveal},
                      onSelectionChanged: (value) => update(
                        () => draft = MafiaRules(
                          trial: draft.trial,
                          executionReveal: value.single,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      '이번 판 역할',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    for (final entry in _composition.entries)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          '${MafiaRoles.find(entry.key)!.displayName} ${entry.value}명 — ${MafiaCopy.roleRules(MafiaRoles.find(entry.key)!)}',
                          style: const TextStyle(fontSize: 17),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, draft),
                child: const Text('적용'),
              ),
            ],
          ),
        );
      },
    );
    if (result != null && mounted) setState(() => _rules = result);
  }

  Future<void> _cancel() async {
    if (_busy || !mounted) return;
    if (_editingRole != null) {
      setState(_endEditing);
      return;
    }
    if (_pickerOpen) {
      setState(() => _pickerOpen = false);
      return;
    }
    setState(() => _isCancelling = true);
    try {
      final canLeave = await widget.onCancel();
      if (!mounted) return;
      if (canLeave) {
        Navigator.of(context).pop();
      } else {
        _requestError = '나가기를 처리하지 못했습니다. 다시 눌러 주세요.';
      }
    } catch (_) {
      _requestError = '나가기를 처리하지 못했습니다. 다시 눌러 주세요.';
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  Future<void> _confirm() async {
    if (_busy || _compositionError != null) return;
    setState(() {
      _endEditing();
      _isSubmitting = true;
      _requestError = null;
    });
    var started = false;
    try {
      widget.onRulesChanged?.call(_rules);
      started = await widget.onConfirm(_composition);
      if (!started) _requestError = '게임을 시작하지 못했습니다. 연결을 확인하고 다시 눌러 주세요.';
    } catch (_) {
      _requestError = '게임을 시작하지 못했습니다. 연결을 확인하고 다시 눌러 주세요.';
    } finally {
      if (mounted && !started) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _compositionError ?? _balanceWarning;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_cancel());
      },
      child: Scaffold(
        backgroundColor: _page,
        body: Stack(
          children: [
            const Positioned.fill(
              child: MafiaNoirRays.night(origin: Alignment(0, -1)),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                child: Column(
                  children: [
                    SizedBox(
                      height: 76,
                      child: Row(
                        children: [
                          GameSetupBackButton(
                            isBusy: _busy,
                            onPressed: () => unawaited(_cancel()),
                          ),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'CASTING',
                                  style: mafiaNoirBody(
                                    13,
                                    color: MafiaColors.noirBrass,
                                    letterSpacing: 6.5,
                                    height: 1.2,
                                  ),
                                ),
                                Text(
                                  '직업 구성',
                                  textAlign: TextAlign.center,
                                  style: mafiaNoirDisplay(40, color: _ink),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${widget.playerCount}명',
                            semanticsLabel: '참여 인원 ${widget.playerCount}명',
                            style: mafiaNoirDisplay(24, color: _ink),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 48,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final preset in ['기본', '확장', '자유'])
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: SizedBox(
                                    width: 44,
                                    child: Text(
                                      preset,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: _preset == preset
                                            ? MafiaColors.noirInk
                                            : MafiaColors.noirPaper,
                                      ),
                                    ),
                                  ),
                                  selected: _preset == preset,
                                  showCheckmark: false,
                                  backgroundColor: MafiaColors.noirSlab,
                                  selectedColor: MafiaColors.noirBrass,
                                  side: const BorderSide(
                                    color: MafiaColors.noirBrass,
                                  ),
                                  shape: const RoundedRectangleBorder(),
                                  onSelected: _busy
                                      ? null
                                      : (_) => _choosePreset(preset),
                                ),
                              ),
                            const SizedBox(width: 16),
                            _FactionBar(
                              citizen: _factionCount(MafiaFaction.citizen),
                              mafia: _factionCount(MafiaFaction.mafia),
                              neutral: _factionCount(MafiaFaction.neutral),
                            ),
                            const SizedBox(width: 16),
                            TextButton.icon(
                              key: const ValueKey('setup-rules'),
                              onPressed: _busy ? null : _showRules,
                              icon: const Icon(
                                Icons.tune,
                                color: MafiaColors.noirBrass,
                              ),
                              label: const Text(
                                '이번 판 규칙',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: MafiaColors.noirBrass,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(child: _buildCards()),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: error == null
                              ? const SizedBox.shrink()
                              : Text(
                                  error,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    color: MafiaColors.noirRose,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 16),
                        FilledButton(
                          key: const ValueKey('confirm-roles'),
                          onPressed: !_busy && _compositionError == null
                              ? _confirm
                              : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: _ink,
                            foregroundColor: _page,
                            disabledBackgroundColor: MafiaColors.noirFaded,
                            textStyle: mafiaNoirDisplay(22, color: _page),
                            minimumSize: const Size(220, 60),
                            shape: const RoundedRectangleBorder(
                              side: BorderSide(
                                color: MafiaColors.noirBrass,
                                width: 2,
                              ),
                            ),
                          ),
                          // 스피너 대신 문구만 바꿉니다. 서버가 판을 열면 곧바로
                          // 분배 장면으로 넘어갑니다.
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Text(
                              _isSubmitting ? '카드를 섞는 중' : '게임 시작',
                              key: ValueKey(_isSubmitting),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (_requestError != null)
              GameRequestNotice(message: _requestError),
          ],
        ),
      ),
    );
  }

  Widget _buildCards() => LayoutBuilder(
    builder: (context, constraints) {
      const gap = 6.0;
      const rowGap = 12.0;
      const removeHeight = 44.0;
      final width = constraints.maxWidth;
      final height = constraints.maxHeight;
      final closedRailWidth = (width * .14).clamp(76.0, 180.0);
      final railWidth = _pickerOpen
          ? (width * .32).clamp(190.0, 340.0)
          : closedRailWidth;
      final gridWidth = math.max(0.0, width - railWidth - gap);
      final ids = _selected.keys.toList();
      // 선택 목록을 여닫을 때 줄 수가 출렁이지 않도록 닫힌 상태 폭으로 판정합니다.
      // 넓은 화면에서도 한 줄에 7종 이상 몰아 그림을 가늘게 자르지 않습니다.
      const maxSingleRowCards = 6;
      const minSingleCardWidth = 160.0;
      final singleWidth =
          (width - closedRailWidth - gap * math.max(1, ids.length)) /
          math.max(1, ids.length);
      final rows =
          ids.length > 1 &&
              (ids.length > maxSingleRowCards ||
                  singleWidth < minSingleCardWidth)
          ? 2
          : 1;
      final columns = math.max(1, (ids.length / rows).ceil());
      final cardWidth = math.max(
        0.0,
        (gridWidth - gap * (columns - 1)) / columns,
      );
      final rowHeight = (height - rowGap * (rows - 1)) / rows;
      final railHeight = math.max(0.0, height - removeHeight);

      return Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          if (ids.isEmpty)
            Positioned(
              left: 0,
              top: 0,
              width: gridWidth,
              height: height,
              child: Center(
                child: Text('오른쪽 +에서 신분을 추가해 주세요.', style: mafiaNoirBody(18)),
              ),
            ),
          for (var index = 0; index < ids.length; index++)
            AnimatedPositioned(
              key: ValueKey('selected-role-${ids[index]}'),
              duration: _motion,
              curve: Curves.easeInOutCubic,
              left: (index % columns) * (cardWidth + gap),
              top: (index ~/ columns) * (rowHeight + rowGap),
              width: cardWidth,
              height: rowHeight,
              child: Column(
                children: [
                  Expanded(child: _buildSelectedCard(ids[index])),
                  SizedBox(
                    height: removeHeight,
                    child: IconButton(
                      key: ValueKey('remove-role-${ids[index]}'),
                      tooltip: '${MafiaRoles.find(ids[index])!.displayName} 삭제',
                      onPressed: _busy ? null : () => _remove(ids[index]),
                      icon: const Icon(
                        Icons.cancel_outlined,
                        size: 22,
                        color: _ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          AnimatedPositioned(
            key: const ValueKey('role-add-rail'),
            duration: _motion,
            curve: Curves.easeInOutCubic,
            left: gridWidth + gap,
            top: 0,
            width: railWidth,
            height: railHeight,
            child: _pickerOpen ? _buildPicker() : _buildAddButton(),
          ),
        ],
      );
    },
  );

  Widget _buildAddButton() => Material(
    // 시안 ①의 '+ 다른 직업' 칸입니다.
    color: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: const BorderSide(color: MafiaColors.noirFaded, width: 2),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      key: const ValueKey('add-role'),
      onTap: _busy || !_canAddAnyRole
          ? null
          : () => setState(() {
              _endEditing();
              _pickerOpen = true;
            }),
      child: Center(
        child: Icon(
          Icons.add,
          size: 56,
          color: _busy || !_canAddAnyRole
              ? MafiaColors.noirFaded
              : MafiaColors.noirDust,
          semanticLabel: '신분 추가',
        ),
      ),
    ),
  );

  Widget _buildPicker() {
    final available = _roleIds
        .where((id) => !_selected.containsKey(id))
        .toList();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: MafiaColors.noirSlab,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: MafiaColors.noirBrass, width: 2),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    '신분 추가',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: MafiaColors.noirPaper,
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey('close-role-picker'),
                  tooltip: '신분 목록 닫기',
                  onPressed: _busy
                      ? null
                      : () => setState(() => _pickerOpen = false),
                  icon: const Icon(
                    Icons.close,
                    size: 20,
                    color: MafiaColors.noirBrass,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: available.isEmpty
                ? const Center(
                    child: Text(
                      '모든 신분을 추가했어요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        color: MafiaColors.noirPaper,
                      ),
                    ),
                  )
                : GridView.builder(
                    key: const ValueKey('role-picker-grid'),
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 6,
                          mainAxisSpacing: 8,
                          childAspectRatio: .64,
                        ),
                    itemCount: available.length,
                    itemBuilder: (context, index) {
                      final role = MafiaRoles.find(available[index])!;
                      return Semantics(
                        button: true,
                        enabled: !_busy && _canAddRole(role.id),
                        label: '${role.displayName} 추가',
                        child: GestureDetector(
                          key: ValueKey('pick-role-${role.id}'),
                          onTap: _busy || !_canAddRole(role.id)
                              ? null
                              : () => _add(role.id),
                          child: MafiaSetupRoleCard(role: role),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// 기존 색 필터 helper를 사용하는 외부 테스트와의 호환성을 유지합니다.
@visibleForTesting
List<double> mafiaRoleIconTint(double t) {
  // 사람 눈이 느끼는 밝기 비율입니다(회색조로 만들 때 씁니다).
  const red = 0.2126;
  const green = 0.7152;
  const blue = 0.0722;
  // 고르지 않은 아이콘은 옅게 그립니다.
  const unselectedOpacity = 0.72;

  double toColor(double gray, double identity) => gray + (identity - gray) * t;
  final alpha = unselectedOpacity + (1 - unselectedOpacity) * t;
  return <double>[
    toColor(red, 1), toColor(green, 0), toColor(blue, 0), 0, 0, //
    toColor(red, 0), toColor(green, 1), toColor(blue, 0), 0, 0, //
    toColor(red, 0), toColor(green, 0), toColor(blue, 1), 0, 0, //
    0, 0, 0, alpha, 0, //
  ];
}

/// 진영 비율 막대입니다(시안 ①: 마피아 팀 빨강 · 시민 팀 청록).
class _FactionBar extends StatelessWidget {
  const _FactionBar({
    required this.citizen,
    required this.mafia,
    required this.neutral,
  });

  final int citizen;
  final int mafia;
  final int neutral;

  @override
  Widget build(BuildContext context) {
    final total = (citizen + mafia + neutral).clamp(1, 99);
    Widget segment(int count, Color color) => count == 0
        ? const SizedBox.shrink()
        : Expanded(
            flex: count,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              height: 10,
              color: color,
            ),
          );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '마피아 팀 $mafia',
          style: mafiaNoirBody(
            16,
            color: MafiaColors.noirScarlet,
            weight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 240,
          child: Row(
            children: [
              segment(mafia, MafiaColors.noirBlood),
              segment(neutral, MafiaColors.noirBrass),
              segment(citizen, MafiaColors.noirTeal),
              if (total == 0) const Spacer(),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '시민 팀 $citizen${neutral > 0 ? ' · 중립 $neutral' : ''}',
          style: mafiaNoirBody(
            16,
            color: MafiaColors.noirCitizen,
            weight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
