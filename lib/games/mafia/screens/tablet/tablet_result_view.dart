import 'dart:async';

import 'package:flutter/material.dart';
import 'package:project00/games/mafia/mafia_result_art.dart';
import 'package:project00/games/mafia/models/mafia_player.dart';
import 'package:project00/games/mafia/models/mafia_role.dart';
import 'package:project00/games/mafia/screens/tablet/tablet_game_layout.dart';

//=======================태블릿 결과 화면==============================
/// 승리 진영을 알리고 전원 신분을 공개합니다(시안 `tablet-p9`, node 1113:13·16).
///
/// 확정된 순서(2026-08):
///
/// | 박자 | 내용 |
/// |---|---|
/// | 1 | 승리 배경만 화면을 덮습니다. 문구·버튼 없음 |
/// | 2 | **2초 뒤 또는 화면을 누르면** 명단판이 올라옵니다 |
/// | 3 | 진영 이름 → 신분·닉네임 → 버튼 순으로 차례차례 드러납니다 |
///
/// 명단은 진영 셋(마피아·시민·중립)을 **항상 세 칸으로** 보여 줍니다. 시안이
/// 승패와 무관하게 세 칸이라, 승리 진영에 따라 칸이 움직이지 않습니다.
///
/// 진영 이름 색은 시안 값(빨강 · `#44ABFF` · 노랑)을 씁니다.
/// [MafiaFactionColors]의 시민 파랑(`#0D00FF`)은 짙어서 이 어두운 판 위에서는
/// 거의 보이지 않습니다.
class MafiaTabletResultView extends StatefulWidget {
  const MafiaTabletResultView({
    super.key,
    required this.winner,
    required this.players,
    required this.revealedRoles,
    this.onRestart,
    this.onHome,
  });

  /// 승리 진영입니다. 중립 개별 승리는 배경이 없어 명단부터 보여 줍니다.
  final MafiaFaction? winner;

  final Map<String, MafiaPlayer> players;

  /// 전원 신분입니다. 게임이 끝나면 서버가 모두 공개합니다.
  final Map<String, MafiaRole?> revealedRoles;

  final VoidCallback? onRestart;
  final VoidCallback? onHome;

  /// 승리 배경만 보여 주는 시간입니다. 화면을 누르면 기다리지 않습니다.
  static const Duration posterHold = Duration(seconds: 2);

  /// 명단판이 올라오고 내용이 차례로 드러나는 시간입니다.
  static const Duration revealDuration = Duration(milliseconds: 1100);

  @override
  State<MafiaTabletResultView> createState() => _MafiaTabletResultViewState();
}

class _MafiaTabletResultViewState extends State<MafiaTabletResultView>
    with SingleTickerProviderStateMixin {
  //=======================시안 기준 좌표(1194 × 834)==============================
  /// 명단판입니다. 시안은 반투명 검정(70%)에 모서리 30입니다.
  static const Rect _board = Rect.fromLTWH(117, 88, 965, 662);
  static const double _boardRadius = 30;
  static const Color _boardColor = Color(0xB3000000);

  /// 진영 이름 세 개입니다. 시안 48px입니다.
  static const double _headerTop = 144;
  static const double _headerHeight = 58;
  static const double _headerFontSize = 48;

  /// 명단 칸의 가운데 X입니다. 시안의 세 칸 간격은 290입니다.
  static const List<double> _columnCenters = [349.9, 639.9, 929.9];

  /// 명단 한 줄입니다. 시안은 189.809 × 45.489, 줄 간격 55.987입니다.
  static const double _rowWidth = 189.809;
  static const double _rowHeight = 45.489;
  static const double _rowPitch = 55.987;
  static const double _rowFirstTop = 256;
  static const double _rowFontSize = 32;

  /// 명단이 쓸 수 있는 아래 끝입니다(버튼 위로 여백을 둡니다).
  static const double _rowsBottom = 611;

  static const Rect _restartButton = Rect.fromLTWH(165, 627, 231, 79);
  static const Rect _homeButton = Rect.fromLTWH(805, 627, 231, 79);

  /// 시안의 진영 이름 색입니다.
  static const Map<MafiaFaction, Color> _headerColors = {
    MafiaFaction.mafia: Color(0xFFFF0000),
    MafiaFaction.citizen: Color(0xFF44ABFF),
    MafiaFaction.neutral: Color(0xFFFFFF00),
  };

  /// 시안대로 왼쪽부터 마피아 · 시민 · 중립 순입니다.
  static const List<MafiaFaction> _columns = [
    MafiaFaction.mafia,
    MafiaFaction.citizen,
    MafiaFaction.neutral,
  ];

  late final AnimationController _reveal;
  Timer? _posterTimer;
  bool _showsBoard = false;

  @override
  void initState() {
    super.initState();
    _reveal = AnimationController(
      vsync: this,
      duration: MafiaTabletResultView.revealDuration,
    );
    if (MafiaResultArt.tabletPoster(widget.winner) == null) {
      // 배경 그림이 없는 승리(중립 개별 조건)는 곧바로 명단을 보여 줍니다.
      _showsBoard = true;
      _reveal.value = 1;
      return;
    }
    _posterTimer = Timer(MafiaTabletResultView.posterHold, _openBoard);
  }

  /// 명단판을 올립니다. 시간이 다 됐거나 화면을 눌렀을 때입니다.
  void _openBoard() {
    if (!mounted || _showsBoard) return;
    _posterTimer?.cancel();
    setState(() => _showsBoard = true);
    _reveal.forward(from: 0);
  }

  /// 드러나는 중에 다시 누르면 끝까지 건너뜁니다.
  void _handleTap() {
    if (!_showsBoard) {
      _openBoard();
      return;
    }
    if (_reveal.isAnimating) _reveal.value = 1;
  }

  @override
  void dispose() {
    _posterTimer?.cancel();
    _reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final poster = MafiaResultArt.tabletPoster(widget.winner);

    return Stack(
      fit: StackFit.expand,
      children: [
        if (poster != null)
          poster.image(fit: BoxFit.cover, filterQuality: FilterQuality.high),
        // 배경만 보이는 동안 화면 어디를 눌러도 명단으로 넘어갑니다.
        // 버튼은 이 위에 있어 계속 눌립니다.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _handleTap,
          ),
        ),
        if (_showsBoard) ..._buildBoard(),
      ],
    );
  }

  //=======================명단판==============================
  List<Widget> _buildBoard() {
    final membersByFaction = {
      for (final faction in _columns) faction: _membersOf(faction),
    };
    // 12인 방은 시민 진영이 9명까지 나옵니다. 시안은 6줄이라, 줄이 넘칠 때는
    // 세 칸이 **같은 리듬**으로 좁아집니다(칸마다 다르면 줄이 어긋납니다).
    final maxRows = membersByFaction.values
        .map((members) => members.length)
        .fold(1, (a, b) => a > b ? a : b);
    final needed = (maxRows - 1) * _rowPitch + _rowHeight;
    final available = _rowsBottom - _rowFirstTop;
    final fit = needed <= available ? 1.0 : available / needed;

    return [
      _buildPanel(),
      for (var column = 0; column < _columns.length; column += 1) ...[
        _buildHeader(column),
        ..._buildRows(
          column: column,
          members: membersByFaction[_columns[column]]!,
          fit: fit,
        ),
      ],
      _buildButton(_restartButton, '다시하기', widget.onRestart),
      _buildButton(_homeButton, '홈으로', widget.onHome),
    ];
  }

  List<MafiaPlayer> _membersOf(MafiaFaction faction) {
    final members =
        widget.players.values
            .where(
              (player) => widget.revealedRoles[player.uid]?.faction == faction,
            )
            .toList()
          // 산 사람을 위로 올려 승패를 읽기 쉽게 합니다.
          ..sort((a, b) {
            if (a.isAlive != b.isAlive) return a.isAlive ? -1 : 1;
            return a.seatIndex.compareTo(b.seatIndex);
          });
    return members;
  }

  Widget _buildPanel() {
    return _Revealed(
      animation: _reveal,
      interval: const Interval(0, 0.35, curve: Curves.easeOutCubic),
      // 판은 살짝 커지며 올라옵니다.
      scaleFrom: 0.94,
      child: MafiaTabletBox(
        rect: _board,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _boardColor,
            borderRadius: BorderRadius.circular(_boardRadius),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(int column) {
    final faction = _columns[column];
    return _Revealed(
      animation: _reveal,
      interval: Interval(0.2 + column * 0.05, 0.55 + column * 0.05),
      child: MafiaTabletBox(
        rect: Rect.fromLTWH(
          _columnCenters[column] - _rowWidth / 2,
          _headerTop,
          _rowWidth,
          _headerHeight,
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${faction.displayName}진영',
              maxLines: 1,
              style: TextStyle(
                color: _headerColors[faction],
                fontSize: _headerFontSize,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildRows({
    required int column,
    required List<MafiaPlayer> members,
    required double fit,
  }) {
    final pitch = _rowPitch * fit;
    final height = _rowHeight * fit;

    return [
      for (var index = 0; index < members.length; index += 1)
        _Revealed(
          animation: _reveal,
          // 칸은 왼쪽부터, 줄은 위에서부터 차례로 드러납니다.
          interval: _rowInterval(column: column, index: index),
          child: MafiaTabletBox(
            rect: Rect.fromLTWH(
              _columnCenters[column] - _rowWidth / 2,
              _rowFirstTop + pitch * index,
              _rowWidth,
              height,
            ),
            child: _buildRow(members[index], fit),
          ),
        ),
    ];
  }

  /// 줄이 드러나는 구간입니다. 마지막 줄도 끝나기 전에 시작하도록 눌러 둡니다.
  Interval _rowInterval({required int column, required int index}) {
    final start = (0.35 + column * 0.04 + index * 0.03).clamp(0.0, 0.75);
    return Interval(start, (start + 0.25).clamp(0.0, 1.0));
  }

  /// 시안 문구가 `신분 + 닉네임`이라 그 순서로 적습니다.
  Widget _buildRow(MafiaPlayer player, double fit) {
    final role = widget.revealedRoles[player.uid];
    final label = role == null
        ? player.nickname
        : '${role.displayName} ${player.nickname}';

    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Opacity(
          // 사망자는 조금 흐리게 해 생존 여부를 함께 알려 줍니다.
          opacity: player.isAlive ? 1 : 0.55,
          child: Text(
            label,
            maxLines: 1,
            style: TextStyle(
              color: Colors.white,
              fontSize: _rowFontSize * fit,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButton(Rect rect, String label, VoidCallback? onTap) {
    return _Revealed(
      animation: _reveal,
      interval: const Interval(0.8, 1),
      child: MafiaTabletBox(
        rect: rect,
        ignorePointer: false,
        child: Semantics(
          button: true,
          enabled: onTap != null,
          label: label,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                // 시안 그림자입니다. 아래로 떨어집니다.
                boxShadow: const [
                  BoxShadow(
                    color: Color(0xB3000000),
                    blurRadius: 10,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 40,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

//=======================차례로 드러나는 요소==============================
/// [interval] 구간에 맞춰 떠오르는 요소입니다.
///
/// 명단판·진영 이름·줄·버튼이 같은 시계(하나의 [animation])를 나눠 써서
/// 서로 어긋나지 않게 합니다.
class _Revealed extends StatelessWidget {
  const _Revealed({
    required this.animation,
    required this.interval,
    required this.child,
    this.scaleFrom = 1,
  });

  final Animation<double> animation;
  final Interval interval;
  final Widget child;

  /// 1이 아니면 이 배율에서 커지며 나타납니다.
  final double scaleFrom;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final progress = interval.transform(animation.value.clamp(0.0, 1.0));
        final eased = Curves.easeOut.transform(progress);
        Widget content = Opacity(opacity: eased, child: child);
        if (scaleFrom != 1) {
          content = Transform.scale(
            scale: scaleFrom + (1 - scaleFrom) * eased,
            child: content,
          );
        }
        return content;
      },
    );
  }
}
