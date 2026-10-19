import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:game_yut/src/rules.dart';
import 'package:game_yut/src/theme.dart';
import 'package:game_yut/src/view.dart';
import 'package:game_yut/src/widgets.dart';

/// 끌고 있는 말입니다. 판 위의 말과 남은 말 더미가 같은 값을 씁니다.
@immutable
class YutDrag {
  const YutDrag({required this.owner, required this.pieceId});
  final String owner;
  final int pieceId;
}

/// 끌어 놓을 수 있는 한 칸입니다. [chips]는 차례대로 쓸 나온 윷입니다.
@immutable
class _Target {
  const _Target(this.node, this.chips, this.label);
  final int node;
  final List<int> chips;
  final String label;
}

/// 말의 주인 색입니다. 백군은 한지색 대신 먹색으로 빛을 냅니다.
Color yutOwnerColor(YutGameView game, String owner) {
  if (game.edition) return YutColors.lilac;
  final team = game.teamOfOwner(owner);
  if (team == YutTeam.white) return YutColors.muted;
  return YutTeamStyle.of(team).fill;
}

/// 판, 판 위의 말, 끌어 놓기와 이동·업기·잡기 연출을 그립니다.
///
/// 시안 `보통 윷놀이 · 말 움직이기`를 따릅니다. 판 위의 내 말을 꾹 누르면
/// 둘레에 원이 차오르고, 갈 수 있는 칸마다 자기 색 빛무리와 흐린 미리보기
/// 말이 나타납니다. 끌어다 놓으면 한 칸씩 통통 뛰고, 상대 말을 잡으면
/// 판이 쩍 갈라지며 잡힌 말이 주인에게 날아갑니다.
/// 세 게임(일반·전략·에디션)이 같은 연출을 씁니다.
class YutBoardView extends StatefulWidget {
  const YutBoardView({
    super.key,
    required this.game,
    this.onMove,
    this.busy = false,
    this.stackOffset,
  });
  final YutGameView game;

  /// 놓은 말과 차례대로 쓸 나온 윷 번호입니다. null이면 끌 수 없습니다.
  final void Function(int pieceId, List<int> chips)? onMove;
  final bool busy;

  /// 잡힌 말이 돌아갈 주인 더미의 위치(판 왼쪽 위 기준)입니다.
  final Offset? Function(String owner)? stackOffset;

  @override
  State<YutBoardView> createState() => _YutBoardViewState();
}

class _YutBoardViewState extends State<YutBoardView>
    with TickerProviderStateMixin {
  late final _fx = AnimationController(vsync: this);
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat();
  late final _press = AnimationController(vsync: this, duration: _pressDelay);
  final _queue = <YutMoveView>[];
  bool _readyForNextMove = false;
  int _playbackGeneration = 0;
  YutMoveView? _move;
  int _shownMoveAt = 0;
  YutDrag? _drag;
  YutDrag? _pendingDrag;
  _Target? _pendingTarget;
  int? _hoverNode;
  YutDrag? _pressing;
  final _boardKey = GlobalKey();

  static const _pressDelay = Duration(milliseconds: 400);
  static const _hopMs = 350;

  @override
  void initState() {
    super.initState();
    _fx.addListener(_advanceAfterLanding);
    // 재접속 직후 오래된 이동을 다시 연출하지 않습니다.
    _shownMoveAt = widget.game.lastMove?.createdAt ?? 0;
  }

  @override
  void didUpdateWidget(covariant YutBoardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final move = widget.game.lastMove;
    if (move != null && move.createdAt > _shownMoveAt) {
      _pendingDrag = null;
      _pendingTarget = null;
      _shownMoveAt = move.createdAt;
      _queue.add(move);
      if (_move == null || _readyForNextMove) _playNext();
    }
    if ((oldWidget.busy && !widget.busy) ||
        !widget.game.moving ||
        widget.game.paused ||
        oldWidget.game.turnOwner != widget.game.turnOwner) {
      _pendingDrag = null;
      _pendingTarget = null;
    }
    if (!widget.game.moving && _drag != null) {
      _drag = null;
      _hoverNode = null;
    }
  }

  void _playNext() {
    _readyForNextMove = false;
    final generation = ++_playbackGeneration;
    if (_queue.isEmpty) {
      setState(() => _move = null);
      return;
    }
    final move = _queue.removeAt(0);
    setState(() => _move = move);
    _fx
      ..duration = Duration(milliseconds: _totalMs(move))
      ..forward(from: 0).whenComplete(() {
        if (mounted && generation == _playbackGeneration) _playNext();
      });
  }

  void _advanceAfterLanding() {
    final move = _move;
    if (move == null || _readyForNextMove) return;
    // 실제 재생 위치를 기준으로 합니다. 앱이 뒤로 가거나 프레임이 늦어져도
    // 착지/잡힌 말의 귀환보다 먼저 다음 이동이 시작되지 않습니다.
    final readyAt = _landMs(move) + (move.captured.isNotEmpty ? 1200 : 360);
    if (_ms < readyAt) return;
    setState(() => _readyForNextMove = true);
    if (_queue.isNotEmpty) _playNext();
  }

  int _hops(YutMoveView move) => math.max(1, move.path.length - 1);
  int _landMs(YutMoveView move) => _hops(move) * _hopMs;
  int _totalMs(YutMoveView move) =>
      _landMs(move) +
      (move.captured.isNotEmpty
          ? 2400
          : _isEntry(move) || _stackedCount(move) > 1
          ? 1700
          : 900);

  bool _isEntry(YutMoveView move) =>
      move.path.isNotEmpty && move.path.first < 0;

  /// 도착 칸에 쌓인 내 말 수(업기)입니다.
  int _stackedCount(YutMoveView move) {
    final destination = move.path.isEmpty ? -1 : move.path.last;
    if (destination < 0 || destination >= YutBoard.home) return 0;
    return widget.game
        .piecesOf(move.owner)
        .where((piece) => piece.onBoard && piece.position == destination)
        .length;
  }

  @override
  void dispose() {
    _fx.dispose();
    _pulse.dispose();
    _press.dispose();
    super.dispose();
  }

  bool get _edition => widget.game.edition;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final side = math.min(box.maxWidth, box.maxHeight);
      final lo = _edition ? .08128 : .124;
      final nodes = YutBoard.nodes(
        lo: lo,
        hi: 1 - lo,
      ).map((node) => Offset(node.dx * side, node.dy * side)).toList();
      final pieceSize = side * (_edition ? .091 : .0968);
      return Center(
        child: SizedBox.square(
          key: _boardKey,
          dimension: side,
          child: DragTarget<YutDrag>(
            onWillAcceptWithDetails: (details) {
              final ok = _canDrag(details.data);
              if (ok && _drag == null) setState(() => _drag = details.data);
              return ok;
            },
            onMove: (details) => _hover(details.offset, nodes, pieceSize),
            onLeave: (_) => setState(() => _hoverNode = null),
            onAcceptWithDetails: (details) =>
                _drop(details.data, details.offset, nodes, pieceSize),
            builder: (context, _, _) => AnimatedBuilder(
              animation: Listenable.merge([_fx, _pulse, _press]),
              builder: (context, _) {
                final shake = _shakeOffset(pieceSize);
                return Transform.translate(
                  offset: shake,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _boardImage(side),
                      if (_edition) _startLabel(nodes[YutBoard.start], side),
                      ..._cracks(nodes, pieceSize),
                      ..._targetsLayer(nodes, pieceSize),
                      ..._pieces(nodes, pieceSize),
                      ..._captureEffects(nodes, pieceSize, side),
                      ..._landingTags(nodes, pieceSize, side),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );
    },
  );

  /// 일반·전략 윷놀이는 오크 판(E안), 에디션은 홀로그램 판입니다.
  Widget _boardImage(double side) => Positioned.fill(
    child: _edition
        ? Image(image: YutImages.boardHolo, fit: BoxFit.fill)
        : YutOakBoard(side: side),
  );

  Widget _startLabel(Offset node, double side) {
    final size = side * (_edition ? .07 : .06);
    return Positioned(
      left: node.dx - size,
      top: node.dy - size / 2,
      width: size * 2,
      height: size,
      child: IgnorePointer(
        child: Center(
          child: Text(
            YutCopy.start,
            style: YutFonts.stamp(
              side * (_edition ? .027 : .03),
              color: _edition ? YutColors.night : Colors.white,
              shadows: _edition
                  ? null
                  : const [Shadow(color: Color(0x8C460A06), blurRadius: 2)],
            ),
          ),
        ),
      ),
    );
  }

  //=======================끌어 놓기==============================

  bool _canDrag(YutDrag drag) {
    final game = widget.game;
    if (widget.onMove == null ||
        widget.busy ||
        _pendingDrag != null ||
        !game.moving ||
        game.paused) {
      return false;
    }
    if (drag.owner != game.turnOwner) return false;
    return _targetsFor(drag).isNotEmpty;
  }

  YutPieceView? _piece(YutDrag drag) => widget.game
      .piecesOf(drag.owner)
      .where((piece) => piece.id == drag.pieceId)
      .firstOrNull;

  /// 나온 윷 하나 또는 둘(합쳐서)로 갈 수 있는 칸입니다. 중간에 상대를
  /// 잡거나 먼저 나는 조합은 서버에서 한 번 더 던지기로 끊기므로 뺍니다.
  List<_Target> _targetsFor(YutDrag drag) {
    final game = widget.game;
    final piece = _piece(drag);
    if (piece == null || piece.finished) return const [];
    final start = piece.onBoard ? piece.path : const <int>[];
    final usable = game.pool
        .where((chip) => chip.result.steps >= 0 || piece.onBoard)
        .toList();
    final targets = <int, _Target>{};
    for (final chip in usable) {
      final path = YutBoard.advance(start, chip.result.steps);
      if (path.isEmpty) continue;
      targets.putIfAbsent(
        path.last,
        () => _Target(path.last, [chip.index], YutCopy.result(chip.result)),
      );
    }
    for (final first in usable) {
      for (final second in usable) {
        if (first.index == second.index) continue;
        if (first.result.steps < 0 || second.result.steps < 0) continue;
        final middle = YutBoard.advance(start, first.result.steps);
        if (middle.isEmpty || middle.last == YutBoard.home) continue;
        if (_hasOpponent(drag.owner, middle.last)) continue;
        final path = YutBoard.advance(middle, second.result.steps);
        targets.putIfAbsent(
          path.last,
          () => _Target(
            path.last,
            [first.index, second.index],
            '${YutCopy.result(first.result)}+${YutCopy.result(second.result)}',
          ),
        );
      }
    }
    return targets.values.toList();
  }

  bool _hasOpponent(String owner, int node) => widget.game.pieces.entries.any(
    (entry) =>
        entry.key != owner &&
        entry.value.any((piece) => piece.onBoard && piece.position == node),
  );

  /// 도착 칸 좌표입니다. 나는 칸은 출발 모서리 바깥에 둡니다.
  Offset _targetPoint(int node, List<Offset> nodes, double size) =>
      node == YutBoard.home
      ? nodes[YutBoard.start] + Offset(size * .9, size * .9)
      : nodes[node];

  Offset _local(Offset globalTopLeft, double size) {
    final box = _boardKey.currentContext?.findRenderObject() as RenderBox?;
    final feedback = size * 1.15;
    return (box?.globalToLocal(globalTopLeft) ?? globalTopLeft) +
        Offset(feedback / 2, feedback / 2);
  }

  _Target? _nearest(Offset point, List<Offset> nodes, double size) {
    final drag = _drag;
    if (drag == null) return null;
    _Target? best;
    var bestDistance = size * 1.1;
    for (final target in _targetsFor(drag)) {
      final distance =
          (_targetPoint(target.node, nodes, size) - point).distance;
      if (distance < bestDistance) {
        best = target;
        bestDistance = distance;
      }
    }
    return best;
  }

  void _hover(Offset globalTopLeft, List<Offset> nodes, double size) {
    final node = _nearest(_local(globalTopLeft, size), nodes, size)?.node;
    if (node != _hoverNode) setState(() => _hoverNode = node);
  }

  void _drop(
    YutDrag drag,
    Offset globalTopLeft,
    List<Offset> nodes,
    double size,
  ) {
    final target = _nearest(_local(globalTopLeft, size), nodes, size);
    setState(() {
      _drag = null;
      _hoverNode = null;
      // 미리보기만 유지합니다. 실제 말 위치는 서버의 lastMove로 옮깁니다.
      if (target != null && widget.onMove != null) {
        _pendingDrag = drag;
        _pendingTarget = target;
      }
    });
    if (target == null) return;
    widget.onMove?.call(drag.pieceId, target.chips);
  }

  /// 갈 수 있는 칸: 자기 색 빛무리, 흐린 미리보기 말, 결과 이름표.
  List<Widget> _targetsLayer(List<Offset> nodes, double size) {
    final pending = _pendingDrag != null;
    final drag = _pendingDrag ?? _drag;
    if (drag == null) return const [];
    final game = widget.game;
    final color = yutOwnerColor(game, drag.owner);
    final keeper = game.pieceKeeper(drag.owner, drag.pieceId);
    final pulse = .85 + .25 * (math.sin(_pulse.value * math.pi * 2) * .5 + .5);
    final out = <Widget>[];
    final targets = pending ? [?_pendingTarget] : _targetsFor(drag);
    for (final target in targets) {
      final c = _targetPoint(target.node, nodes, size);
      final hot = target.node == _hoverNode;
      final halo = size * 40 / 28 * (hot ? 1.15 : pulse);
      out.add(
        Positioned(
          left: c.dx - halo,
          top: c.dy - halo,
          width: halo * 2,
          height: halo * 2,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    color.withValues(alpha: .9),
                    color.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      out.add(
        Positioned(
          left: c.dx - size * 25 / 56,
          top: c.dy - size * 25 / 56,
          child: IgnorePointer(
            child: Opacity(
              opacity: pending
                  ? .3 + .15 * _pulse.value
                  : hot
                  ? .8
                  : .5,
              child: YutPieceToken(
                team: game.teamOfOwner(drag.owner),
                label: keeper?.initial ?? '',
                size: size * 50 / 56,
                edition: _edition,
                characterId: game.strategy ? null : keeper?.characterId,
              ),
            ),
          ),
        ),
      );
      out.add(
        Positioned(
          left: c.dx - size * .9,
          width: size * 1.8,
          top: c.dy - size * 62 / 56,
          child: IgnorePointer(
            child: Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: size * .2),
                height: size * 26 / 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(size),
                  border: Border.all(color: YutColors.paperLight, width: 2),
                ),
                child: Text(
                  pending
                      ? yutText('확인 중', 'Sending', '确认中', '確認中')
                      : target.node == YutBoard.home
                      ? yutText('났다!', 'Home!', '到家！', '到家！')
                      : target.label,
                  style: YutFonts.title(
                    size * 17 / 56,
                    color: _edition ? YutColors.night : Colors.white,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return out;
  }

  //=======================판 위의 말==============================

  /// 같은 칸의 내 말은 한 묶음(업기)으로 그립니다.
  List<Widget> _pieces(List<Offset> nodes, double size) {
    final game = widget.game;
    final move = _move;
    final out = <Widget>[];
    for (final entry in game.pieces.entries) {
      final stacks = <int, List<YutPieceView>>{};
      for (final piece in entry.value) {
        if (!piece.onBoard) continue;
        stacks.putIfAbsent(piece.position, () => []).add(piece);
      }
      for (final stack in stacks.values) {
        final lead = stack.first;
        final drag = YutDrag(owner: entry.key, pieceId: lead.id);
        var center = nodes[lead.position.clamp(0, nodes.length - 1)];
        var lift = 0.0;
        var scale = 1.0;
        final moving =
            move != null &&
            move.owner == entry.key &&
            stack.any((piece) => move.pieceIds.contains(piece.id));
        final queued = _queue.any(
          (m) =>
              m.owner == entry.key &&
              stack.any((piece) => m.pieceIds.contains(piece.id)),
        );
        if (moving) {
          final hop = _hopPoint(move, nodes, size);
          center = hop.$1;
          lift = hop.$2;
          scale = hop.$3;
        } else if (queued) {
          final next = _queue.firstWhere(
            (m) =>
                m.owner == entry.key &&
                stack.any((piece) => m.pieceIds.contains(piece.id)),
          );
          final from = next.path.firstOrNull ?? lead.position;
          if (from >= 0 && from < nodes.length) center = nodes[from];
        }
        final dragging =
            _drag?.owner == entry.key &&
            stack.any((piece) => piece.id == _drag!.pieceId);
        final pressing =
            _pressing?.owner == entry.key &&
            stack.any((piece) => piece.id == _pressing!.pieceId);
        final pending =
            _pendingDrag?.owner == entry.key &&
            stack.any((piece) => piece.id == _pendingDrag!.pieceId);
        if (pending && (!moving || _readyForNextMove)) {
          lift = size * (.08 + .04 * math.sin(_pulse.value * math.pi * 2));
          scale = 1.06;
        }
        if (dragging) scale = 1.15;
        final keeper = game.pieceKeeper(entry.key, lead.id);
        final movable =
            (!moving || _readyForNextMove) &&
            widget.onMove != null &&
            game.moving &&
            entry.key == game.turnOwner &&
            _targetsFor(drag).isNotEmpty;
        final token = YutPieceToken(
          team: game.teamOfOwner(entry.key),
          label: _stackLabel(entry.key, stack, keeper),
          size: size,
          edition: _edition,
          count: stack.length,
          glow: dragging || pressing || pending,
          characterId: game.strategy ? null : keeper?.characterId,
        );
        Widget child = Transform.scale(scale: scale, child: token);
        if (movable && !widget.busy && _pendingDrag == null) {
          child = _PressDraggable(
            data: drag,
            delay: _pressDelay,
            feedback: YutDragFeedback(
              game: game,
              owner: entry.key,
              pieceId: lead.id,
              size: size,
            ),
            onPressStart: () {
              setState(() => _pressing = drag);
              _press.forward(from: 0);
            },
            onPressEnd: () {
              _press.reset();
              if (mounted) setState(() => _pressing = null);
            },
            onDragStarted: () => setState(() {
              _drag = drag;
              _pressing = null;
              _press.reset();
            }),
            onDragEnd: () => setState(() {
              _drag = null;
              _hoverNode = null;
            }),
            child: Stack(
              clipBehavior: Clip.none,
              // 누르는 동안 구조가 바뀌면 손가락 입력이 취소되므로
              // 고리와 원은 항상 두고 보이기만 바꿉니다.
              children: [
                _candidateRing(
                  size,
                  entry.key,
                  visible: !dragging && !pressing,
                ),
                child,
                _pressRing(size, entry.key, visible: pressing),
              ],
            ),
          );
        }
        out.add(
          Positioned(
            left: center.dx - size / 2,
            top: center.dy - size / 2 - lift,
            child: child,
          ),
        );
      }
    }
    return out;
  }

  String _stackLabel(
    String owner,
    List<YutPieceView> stack,
    YutPlayerView? keeper,
  ) {
    final game = widget.game;
    if (!game.strategy) return keeper?.initial ?? '';
    final names = {
      for (final piece in stack) game.pieceKeeper(owner, piece.id)?.initial,
    }.whereType<String>();
    return names.length == 1
        ? names.first
        : YutCopy.teamMark(game.teamOfOwner(owner));
  }

  /// 움직일 수 있는 내 말 둘레의 은은한 고리입니다.
  Widget _candidateRing(double size, String owner, {bool visible = true}) {
    final color = yutOwnerColor(widget.game, owner);
    final grow = 1 + .12 * math.sin(_pulse.value * math.pi * 2);
    return Positioned(
      left: -size * .22 * grow,
      top: -size * .22 * grow,
      width: size * (1 + .44 * grow),
      height: size * (1 + .44 * grow),
      child: IgnorePointer(
        child: Opacity(
          opacity: visible ? 1 : 0,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: .7), width: 2),
            ),
          ),
        ),
      ),
    );
  }

  /// 꾹 누르는 동안 둘레를 채우는 원입니다.
  Widget _pressRing(double size, String owner, {required bool visible}) =>
      Positioned(
        left: -size * .2,
        top: -size * .2,
        width: size * 1.4,
        height: size * 1.4,
        child: IgnorePointer(
          child: CustomPaint(
            painter: _ArcPainter(
              progress: visible ? _press.value : 0,
              color: yutOwnerColor(widget.game, owner),
              width: size * 6 / 56,
            ),
          ),
        ),
      );

  //=======================이동 연출==============================

  double get _ms => _move == null ? 0 : _fx.value * _totalMs(_move!);

  /// 이동 중 말의 위치, 들림(px), 크기입니다.
  (Offset, double, double) _hopPoint(
    YutMoveView move,
    List<Offset> nodes,
    double size,
  ) {
    Offset at(int node) => node < 0
        ? nodes[YutBoard.start] + Offset(size * 1.2, size * 1.2)
        : _targetPoint(node, nodes, size);
    final hops = _hops(move);
    if (move.path.length < 2) return (at(move.path.firstOrNull ?? 0), 0, 1);
    final progress = (_ms / _hopMs).clamp(0.0, hops.toDouble());
    final index = progress.floor().clamp(0, hops - 1);
    final local = progress - index;
    final landed = progress >= hops;
    final a = at(move.path[index]);
    final b = at(move.path[math.min(index + 1, move.path.length - 1)]);
    final point = Offset.lerp(
      a,
      b,
      landed ? 1 : Curves.easeInOut.transform(local),
    )!;
    final lift = landed ? 0.0 : math.sin(local * math.pi) * size * .5;
    var scale = landed ? 1.0 : 1 + .22 * math.sin(local * math.pi);
    if (landed && move.captured.isNotEmpty) {
      // 잡을 때 쾅: 커졌다 찌그러졌다 돌아옵니다.
      final t = _ms - _landMs(move);
      scale = _keys(t, const [(0, 1.38), (100, .82), (200, 1.08), (300, 1)]);
    }
    return (point, lift, scale);
  }

  /// 착지 뒤 이름표: 새 말이면 `새 말 출발!`, 업으면 큰 `×2`.
  List<Widget> _landingTags(List<Offset> nodes, double size, double side) {
    final move = _move;
    if (move == null || move.captured.isNotEmpty || move.path.length < 2) {
      return const [];
    }
    final destination = move.path.last;
    if (destination < 0 || destination >= nodes.length) return const [];
    final t = _ms - _landMs(move);
    if (t < 0) return const [];
    final color = yutOwnerColor(widget.game, move.owner);
    final team = widget.game.teamOfOwner(move.owner);
    final shadow = _edition
        ? Colors.black
        : team == YutTeam.white
        ? YutColors.inkSoft
        : YutTeamStyle.of(team).shadow;
    final fade =
        1 -
        ((t - (_totalMs(move) - _landMs(move) - 300)) / 300).clamp(0.0, 1.0);
    final c = nodes[destination];
    final stacked = _stackedCount(move);
    if (stacked > 1) {
      final pop = _keys(t, const [(0, .4), (200, 1.3), (330, 1)]);
      return [
        Positioned(
          right: side - (c.dx - size * .55),
          top: c.dy - size * .62,
          child: IgnorePointer(
            child: Opacity(
              opacity: fade,
              child: Transform.scale(
                scale: pop,
                alignment: Alignment.centerRight,
                child: _OutlinedText(
                  '×$stacked',
                  size: size,
                  fill: color,
                  shadow: shadow,
                ),
              ),
            ),
          ),
        ),
      ];
    }
    if (!_isEntry(move)) return const [];
    final pop = _keys(t, const [(0, .5), (200, 1.15), (330, 1)]);
    return [
      Positioned(
        left: c.dx + size * .5,
        top: c.dy - size * 1.15,
        child: IgnorePointer(
          child: Opacity(
            opacity: fade,
            child: Transform.scale(
              scale: pop,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: size * .25,
                  vertical: size * .1,
                ),
                decoration: BoxDecoration(
                  color: _edition ? null : color,
                  gradient: _edition ? YutColors.holoGradient : null,
                  borderRadius: BorderRadius.circular(size),
                  boxShadow: [
                    BoxShadow(color: shadow, offset: const Offset(0, 4)),
                  ],
                ),
                child: Text(
                  yutText('새 말 출발!', 'New piece!', '新棋出发！', '新棋出發！'),
                  style: YutFonts.title(
                    size * 24 / 56,
                    color: _edition ? YutColors.night : Colors.white,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ];
  }

  //=======================잡기 연출==============================

  double get _sinceLand => _move == null ? -1 : _ms - _landMs(_move!);

  bool get _capturing => _move != null && _move!.captured.isNotEmpty;

  Offset _shakeOffset(double size) {
    if (!_capturing) return Offset.zero;
    final t = _sinceLand;
    if (t < 0 || t > 310) return Offset.zero;
    final k = size / 56;
    const keys = [
      (0, Offset.zero),
      (40, Offset(-12, 6)),
      (80, Offset(10, -8)),
      (120, Offset(-8, -6)),
      (165, Offset(7, 8)),
      (210, Offset(-4, 3)),
      (250, Offset(3, -2)),
      (310, Offset.zero),
    ];
    for (var i = 1; i < keys.length; i++) {
      if (t <= keys[i].$1) {
        final f = (t - keys[i - 1].$1) / (keys[i].$1 - keys[i - 1].$1);
        return Offset.lerp(keys[i - 1].$2, keys[i].$2, f)! * k;
      }
    }
    return Offset.zero;
  }

  /// 착지 칸에서 여섯 갈래로 판이 쩍 갈라집니다.
  List<Widget> _cracks(List<Offset> nodes, double size) {
    if (!_capturing || _sinceLand < 0) return const [];
    final destination = _move!.path.last;
    if (destination < 0 || destination >= nodes.length) return const [];
    final t = _sinceLand;
    final grow = ((t - 15) / 160).clamp(0.0, 1.0);
    final fade = 1 - ((t - 2050) / 280).clamp(0.0, 1.0);
    return [
      Positioned.fill(
        child: IgnorePointer(
          child: Opacity(
            opacity: fade,
            child: CustomPaint(
              painter: _CrackPainter(
                center: nodes[destination],
                scale: size / 56,
                progress: grow,
                edition: _edition,
              ),
            ),
          ),
        ),
      ),
    ];
  }

  List<Widget> _captureEffects(List<Offset> nodes, double size, double side) {
    final move = _move;
    if (move == null || move.captured.isEmpty || move.path.isEmpty) {
      return const [];
    }
    final destination = move.path.last;
    if (destination < 0 || destination >= nodes.length) return const [];
    final c = nodes[destination];
    final t = _sinceLand;
    final k = size / 56;
    final game = widget.game;
    final color = yutOwnerColor(game, move.owner);
    final out = <Widget>[];

    Widget victimToken(String owner, int pieceId, {int count = 1}) =>
        YutPieceToken(
          team: game.teamOfOwner(owner),
          label: game.pieceKeeper(owner, pieceId)?.initial ?? '',
          size: size,
          edition: _edition,
          count: count,
          characterId: game.strategy ? null : game.player(owner)?.characterId,
        );

    // 착지 전: 잡힐 말이 제자리에 남아 있습니다.
    if (t < 0) {
      for (final victim in move.captured.entries) {
        out.add(
          Positioned(
            left: c.dx - size / 2,
            top: c.dy - size / 2,
            child: victimToken(
              victim.key,
              victim.value.first,
              count: victim.value.length,
            ),
          ),
        );
      }
      return out;
    }

    // 흰 섬광
    final flash = _keys(t, const [(0, 0), (20, .55), (200, 0)]);
    if (flash > 0) {
      out.add(
        Positioned(
          left: -side,
          top: -side,
          width: side * 3,
          height: side * 3,
          child: IgnorePointer(
            child: ColoredBox(
              color: const Color(0xFFFFF8E0).withValues(alpha: flash),
            ),
          ),
        ),
      );
    }
    // 충격파 두 겹
    for (final (radius, width, ink, end) in [
      (90.0, 10.0, const Color(0xFFFFE27A), 420.0),
      (130.0, 5.0, Colors.white, 560.0),
    ]) {
      final f = ((t - 20) / (end - 20)).clamp(0.0, 1.0);
      if (f <= 0 || f >= 1) continue;
      final r = radius * k * (.2 + .8 * Curves.easeOut.transform(f));
      out.add(
        Positioned(
          left: c.dx - r,
          top: c.dy - r,
          width: r * 2,
          height: r * 2,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: ink.withValues(alpha: 1 - f),
                  width: width * k,
                ),
              ),
            ),
          ),
        ),
      );
    }
    // 불꽃 열 개
    const sparks = [
      Offset(110, 0),
      Offset(89, 65),
      Offset(34, 105),
      Offset(-34, 105),
      Offset(-89, 65),
      Offset(-110, 0),
      Offset(-89, -65),
      Offset(-34, -105),
      Offset(34, -105),
      Offset(89, -65),
    ];
    final sparkF = ((t - 20) / 470).clamp(0.0, 1.0);
    if (sparkF > 0 && sparkF < 1) {
      for (var i = 0; i < sparks.length; i++) {
        final p = c + sparks[i] * k * Curves.easeOut.transform(sparkF);
        final r = (i.isEven ? 5 : 7) * k;
        out.add(
          Positioned(
            left: p.dx - r,
            top: p.dy - r,
            width: r * 2,
            height: r * 2,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (i.isEven ? color : const Color(0xFFFFE27A))
                      .withValues(alpha: 1 - sparkF),
                ),
              ),
            ),
          ),
        );
      }
    }
    // 잡힌 말: 위로 튀어 빙글빙글 돌며 주인 더미로 날아갑니다.
    for (final victim in move.captured.entries) {
      final home =
          widget.stackOffset?.call(victim.key) ??
          Offset(c.dx < side / 2 ? -size * 2 : side + size * 2, c.dy);
      final f = (t / 910).clamp(0.0, 1.0);
      if (t > 1190) continue;
      final e = Curves.easeOutCubic.transform(f);
      final peak = Offset(
        (c.dx + home.dx) / 2,
        math.min(c.dy, home.dy) - size * 2.4,
      );
      // 2차 베지어로 포물선을 그립니다.
      final p =
          c * ((1 - e) * (1 - e)) + peak * (2 * e * (1 - e)) + home * (e * e);
      final grow = f < .23 ? 1 + .9 * (f / .23) : 1.9 - .9 * ((f - .23) / .77);
      final pop = t > 910
          ? _keys(t - 910, const [(0, 1), (105, 1.25), (280, .9)])
          : 1.0;
      final opacity = t > 1015 ? 1 - ((t - 1015) / 175).clamp(0.0, 1.0) : 1.0;
      out.add(
        Positioned(
          left: p.dx - size / 2,
          top: p.dy - size / 2,
          child: IgnorePointer(
            child: Opacity(
              opacity: opacity,
              child: Transform.rotate(
                angle: -e * math.pi * 4,
                child: Transform.scale(
                  scale: grow * pop,
                  child: victimToken(victim.key, victim.value.first),
                ),
              ),
            ),
          ),
        ),
      );
    }
    // 잡았다!
    final textIn = _keys(t, const [
      (35, .3),
      (140, 1.25),
      (182, 1.1),
      (224, 1.15),
      (280, 1),
    ]);
    final textOpacity = t < 35
        ? 0.0
        : t < 140
        ? (t - 35) / 105
        : 1 - ((t - 2050) / 280).clamp(0.0, 1.0);
    final wobble = _keys(t, const [(140, -4), (182, 3), (224, -2), (280, 0)]);
    out.add(
      Positioned(
        left: (c.dx - size * 3).clamp(0.0, math.max(0.0, side - size * 6)),
        width: size * 6,
        // 맨 위 줄에서 잡으면 판 밖으로 나가지 않게 말 아래에 띄웁니다.
        top: c.dy - size * 2.2 < 0 ? c.dy + size * .8 : c.dy - size * 2.2,
        child: IgnorePointer(
          child: Opacity(
            opacity: textOpacity.clamp(0.0, 1.0),
            child: Transform.rotate(
              angle: wobble * math.pi / 180,
              child: Transform.scale(
                scale: textIn,
                child: Center(
                  child: _OutlinedText(
                    yutText('잡았다!', 'Caught!', '吃掉了！', '吃掉了！'),
                    size: size * 64 / 56,
                    fill: color,
                    shadow: const Color(0xFF2E2A26),
                    strokeWidth: 4,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return out;
  }
}

/// CSS 키프레임처럼 (시각 ms, 값) 사이를 이어 줍니다.
double _keys(double t, List<(num, num)> stops) {
  if (t <= stops.first.$1) return stops.first.$2.toDouble();
  for (var i = 1; i < stops.length; i++) {
    if (t <= stops[i].$1) {
      final f = (t - stops[i - 1].$1) / (stops[i].$1 - stops[i - 1].$1);
      return stops[i - 1].$2 + (stops[i].$2 - stops[i - 1].$2) * f;
    }
  }
  return stops.last.$2.toDouble();
}

/// 흰 테두리와 그림자가 있는 큰 글자(`잡았다!`, `×2`)입니다.
class _OutlinedText extends StatelessWidget {
  const _OutlinedText(
    this.text, {
    required this.size,
    required this.fill,
    required this.shadow,
    this.strokeWidth = 6,
  });
  final String text;
  final double size;
  final Color fill;
  final Color shadow;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final base = YutFonts.title(size, height: 1);
    return Stack(
      children: [
        Transform.translate(
          offset: const Offset(4, 5),
          child: Text(text, style: base.copyWith(color: shadow)),
        ),
        Text(
          text,
          style: base.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth * 2
              ..strokeJoin = StrokeJoin.round
              ..color = Colors.white,
          ),
        ),
        Text(text, style: base.copyWith(color: fill)),
      ],
    );
  }
}

class _ArcPainter extends CustomPainter {
  const _ArcPainter({
    required this.progress,
    required this.color,
    required this.width,
  });
  final double progress;
  final Color color;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawArc(
      (Offset.zero & size).deflate(width / 2),
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.progress != progress || old.color != color;
}

/// 시안의 금 여섯 갈래(진한 홈 + 밝은 결)입니다.
class _CrackPainter extends CustomPainter {
  const _CrackPainter({
    required this.center,
    required this.scale,
    required this.progress,
    required this.edition,
  });
  final Offset center;
  final double scale;
  final double progress;
  final bool edition;

  static const _lines = [
    [
      Offset(14.7, 6.5),
      Offset(35.9, -2.5),
      Offset(54.8, 24.4),
      Offset(87.8, -6.1),
    ],
    [
      Offset(1.7, 15.9),
      Offset(20.2, 29.9),
      Offset(6.3, 59.7),
      Offset(49.2, 73),
    ],
    [
      Offset(-14.3, 7),
      Offset(-21.1, 29.2),
      Offset(-53.9, 26.3),
      Offset(-51.7, 71.2),
    ],
    [
      Offset(-13.2, -8.9),
      Offset(-35.8, -3.7),
      Offset(-49.7, -33.5),
      Offset(-87.5, -9.2),
    ],
    [
      Offset(-1.6, -15.9),
      Offset(-20.1, -29.8),
      Offset(-6.2, -59.6),
      Offset(-49.2, -72.9),
    ],
    [
      Offset(14.4, -7),
      Offset(21.2, -29.1),
      Offset(54, -26.3),
      Offset(51.8, -71.2),
    ],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final groove = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5 * scale
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = edition ? YutColors.lilac : const Color(0xFF2A1608);
    final light = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4 * scale
      ..color = edition ? Colors.white : const Color(0xFFF3D6A8);
    for (final line in _lines) {
      final path = Path()..moveTo(center.dx, center.dy);
      for (final point in line) {
        final p = center + point * scale;
        path.lineTo(p.dx, p.dy);
      }
      for (final metric in path.computeMetrics()) {
        final part = metric.extractPath(0, metric.length * progress);
        canvas.drawPath(part, groove);
        canvas.drawPath(part.shift(Offset(1.5 * scale, 1.5 * scale)), light);
      }
    }
  }

  @override
  bool shouldRepaint(_CrackPainter old) =>
      old.progress != progress || old.center != center;
}

/// 끌 때 손가락을 따라오는 흐린 말입니다(남은 말 더미에서도 씁니다).
class YutDragFeedback extends StatelessWidget {
  const YutDragFeedback({
    super.key,
    required this.game,
    required this.owner,
    required this.pieceId,
    required this.size,
  });
  final YutGameView game;
  final String owner;
  final int pieceId;
  final double size;

  @override
  Widget build(BuildContext context) {
    final keeper = game.pieceKeeper(owner, pieceId);
    return IgnorePointer(
      child: Opacity(
        opacity: .6,
        child: SizedBox.square(
          dimension: size * 1.15,
          child: YutPieceToken(
            team: game.teamOfOwner(owner),
            label: keeper?.initial ?? '',
            size: size * 1.15,
            edition: game.edition,
            characterId: game.strategy ? null : keeper?.characterId,
          ),
        ),
      ),
    );
  }
}

/// 남은 말 더미의 말입니다. 꾹 누르지 않고 바로 끌어 판에 놓습니다.
class YutStackDraggable extends StatelessWidget {
  const YutStackDraggable({
    super.key,
    required this.game,
    required this.owner,
    required this.pieceId,
    required this.pieceSize,
    required this.enabled,
    required this.child,
  });
  final YutGameView game;
  final String owner;
  final int pieceId;

  /// 판 위 말 크기입니다. 끄는 말이 판에 놓일 크기로 보입니다.
  final double pieceSize;
  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled || pieceId < 0) return child;
    return Draggable<YutDrag>(
      data: YutDrag(owner: owner, pieceId: pieceId),
      dragAnchorStrategy: yutCenteredAnchor,
      feedback: YutDragFeedback(
        game: game,
        owner: owner,
        pieceId: pieceId,
        size: pieceSize,
      ),
      childWhenDragging: Opacity(opacity: .5, child: child),
      child: child,
    );
  }
}

/// 끄는 말의 가운데가 손가락 아래에 오게 합니다. 판은 놓은 자리를
/// `feedback 왼쪽 위 + 크기/2`로 계산합니다.
Offset yutCenteredAnchor(
  Draggable<Object> draggable,
  BuildContext context,
  Offset position,
) {
  final size = (draggable.feedback is YutDragFeedback)
      ? (draggable.feedback as YutDragFeedback).size * 1.15
      : 0.0;
  return Offset(size / 2, size / 2);
}

/// 꾹 누른 뒤에만 끌리는 말입니다. 누르는 동안 [onPressStart]로 원을 채웁니다.
class _PressDraggable extends StatelessWidget {
  const _PressDraggable({
    required this.data,
    required this.delay,
    required this.feedback,
    required this.onPressStart,
    required this.onPressEnd,
    required this.onDragStarted,
    required this.onDragEnd,
    required this.child,
  });
  final YutDrag data;
  final Duration delay;
  final Widget feedback;
  final VoidCallback onPressStart;
  final VoidCallback onPressEnd;
  final VoidCallback onDragStarted;
  final VoidCallback onDragEnd;
  final Widget child;

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => onPressStart(),
    onPointerUp: (_) => onPressEnd(),
    onPointerCancel: (_) => onPressEnd(),
    child: LongPressDraggable<YutDrag>(
      data: data,
      delay: delay,
      dragAnchorStrategy: yutCenteredAnchor,
      hapticFeedbackOnStart: true,
      feedback: feedback,
      childWhenDragging: child,
      onDragStarted: onDragStarted,
      onDragEnd: (_) => onDragEnd(),
      onDraggableCanceled: (_, _) => onDragEnd(),
      child: child,
    ),
  );
}
