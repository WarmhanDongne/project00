import 'dart:async';

import 'package:flutter/material.dart';
import 'package:project00/core/assets/game_image.dart';
import 'package:project00/games/mafia/mafia_result_art.dart';
import 'package:project00/games/mafia/models/mafia_player.dart';
import 'package:project00/games/mafia/models/mafia_role.dart';
import 'package:project00/games/mafia/screens/tablet/tablet_game_layout.dart';
import 'package:project00/games/mafia/widgets/mafia_flip_card.dart';
import 'package:project00/gen/assets.gen.dart';

//=======================태블릿 결과 화면==============================
/// 승리 진영을 알리고 전원 신분을 공개합니다(시안 `tablet-p9`).
///
/// 확정된 순서(2026-08):
///
/// | 박자 | 내용 |
/// |---|---|
/// | 1 | 승리 배경만 화면을 덮습니다. 문구·버튼 없음 |
/// | 2 | **2초 뒤 또는 화면을 누르면** 인물 그림과 흰 판이 올라옵니다 |
/// | 3 | 신분 카드가 **한 장씩 차례로** 뒷면으로 놓입니다 |
/// | 4 | 놓인 순서대로(앞 카드부터) **뒤집혀 신분이 드러납니다** |
///
/// 카드는 자리 순서대로 놓습니다. 진영별로 묶지 않는 이유는, 뒤집기 전에
/// 자리만 보고 진영을 짐작할 수 있으면 공개하는 재미가 사라지기 때문입니다.
class MafiaTabletResultView extends StatefulWidget {
  const MafiaTabletResultView({
    super.key,
    required this.winner,
    this.winnerRoleIds = const {},
    this.winnerLabel,
    required this.players,
    required this.revealedRoles,
    this.onRestart,
    this.onHome,
  });

  /// 승리 진영입니다. 중립 개별 승리는 배경이 없어 판부터 보여 줍니다.
  final MafiaFaction? winner;

  /// 이긴 사람들의 역할 id입니다. 중립 포스터를 고르는 데 씁니다.
  ///
  /// 중립은 진영이 같아도 이긴 역할에 따라 그림이 다릅니다(광대/처형자/
  /// 연쇄살인마/교단).
  final Set<String> winnerRoleIds;

  /// 승리 문구입니다(예: `광대 승리`).
  ///
  /// 승리 **배경 그림이 있는 경우에는 쓰지 않습니다.** 그림에 이미 문구가
  /// 들어 있어 두 번 겹칩니다. 중립 개별 승리처럼 그림이 없을 때만 판 위에
  /// 한 줄로 알려 줍니다.
  final String? winnerLabel;

  final Map<String, MafiaPlayer> players;

  /// 전원 신분입니다. 게임이 끝나면 서버가 모두 공개합니다.
  final Map<String, MafiaRole?> revealedRoles;

  final VoidCallback? onRestart;
  final VoidCallback? onHome;

  /// 승리 배경만 보여 주는 시간입니다. 화면을 누르면 기다리지 않습니다.
  static const Duration posterHold = Duration(seconds: 2);

  //=======================연출 시간==============================
  /// 인물 그림과 흰 판이 올라오는 시간입니다.
  static const Duration panelIn = Duration(milliseconds: 420);

  /// 카드 한 장이 놓이는 시간과 장 사이 간격입니다.
  static const Duration cardIn = Duration(milliseconds: 320);
  static const Duration cardGap = Duration(milliseconds: 90);

  /// 카드 한 장이 뒤집히는 시간과 장 사이 간격입니다.
  static const Duration cardFlip = Duration(milliseconds: 520);
  static const Duration flipGap = Duration(milliseconds: 170);

  /// 카드가 다 놓인 뒤 뒤집기를 시작하기까지 쉬는 시간입니다.
  static const Duration flipDelay = Duration(milliseconds: 260);

  @override
  State<MafiaTabletResultView> createState() => _MafiaTabletResultViewState();
}

class _MafiaTabletResultViewState extends State<MafiaTabletResultView>
    with SingleTickerProviderStateMixin {
  //=======================시안 기준 좌표(1194 × 834)==============================
  // 시안 `tablet-p9`(node 988:368)입니다. 시안이 −90° 회전 상태로 그려져 있어
  // 프로젝트 규칙대로 환산했습니다:
  //   real_left = 1194 − (wrapperTop + wrapperHeight), real_top = wrapperLeft
  /// 흰 판입니다.
  static const Rect _panel = Rect.fromLTWH(44, 133, 1105, 662);
  static const double _panelRadius = 30;

  /// 판 뒤에서 머리만 내미는 인물 그림입니다(아래쪽은 판에 가려집니다).
  ///
  /// 시안은 화면 위로 14 넘겨 배치했습니다. 그림 비율(2172 : 724 = 3.0)이
  /// 이 자리(727 : 242 = 3.004)와 같아 찌그러지지 않습니다.
  static const Rect _characters = Rect.fromLTWH(236, -14, 727, 242);

  /// 승리 문구 자리입니다. 판(_panel)의 위쪽 여백에 한 줄로 올립니다.
  static const Rect _winnerLabelRect = Rect.fromLTWH(44, 60, 1105, 60);

  /// 카드 한 장의 크기와 간격입니다(시안 141 × 206.762, 6열 · 간격 170).
  static const double _cardWidth = 141;
  static const double _cardAspectRatio = 286 / 419.39;
  static const double _cardStep = 170;
  static const int _columns = 6;

  /// 카드가 놓이는 세로 구간입니다(시안 첫 줄 154, 둘째 줄 419).
  static const double _cardsTop = 154;
  static const double _cardsBottom = 650.6;

  /// 카드와 닉네임 사이 여백, 닉네임 줄 높이입니다(시안 값).
  static const double _nicknameGap = 6.4;
  static const double _nicknameHeight = 18.464;

  /// 두 줄 사이 여백입니다(줄 간격 265 − 한 칸 높이).
  static const double _rowGap = 33.4;

  static const Rect _restartButton = Rect.fromLTWH(99, 684, 231, 79);
  static const Rect _homeButton = Rect.fromLTWH(859, 684, 231, 79);

  late final AnimationController _reveal;
  Timer? _posterTimer;
  bool _showsBoard = false;

  /// 카드 놓는 순서입니다. 자리 번호대로 정렬합니다.
  late final List<MafiaPlayer> _ordered;

  /// 승리 배경입니다. 없는 승리(그림 미제작)면 null이라 판부터 보여 줍니다.
  GameImage? get _poster => MafiaResultArt.tabletPoster(
    widget.winner,
    winnerRoleIds: widget.winnerRoleIds,
  );

  @override
  void initState() {
    super.initState();
    _ordered = widget.players.values.toList()
      ..sort((a, b) => a.seatIndex.compareTo(b.seatIndex));
    _reveal = AnimationController(vsync: this, duration: _totalDuration);
    if (_poster == null) {
      // 배경 그림이 없는 승리(중립 개별 조건)는 곧바로 판을 보여 줍니다.
      _showsBoard = true;
      _reveal.forward();
      return;
    }
    _posterTimer = Timer(MafiaTabletResultView.posterHold, _openBoard);
  }

  /// 판을 올립니다. 시간이 다 됐거나 화면을 눌렀을 때입니다.
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

  //=======================연출 진행도==============================
  /// 판 등장 + 카드 놓기 + 뒤집기를 합한 전체 시간입니다.
  Duration get _totalDuration {
    final count = _ordered.length;
    if (count == 0) return MafiaTabletResultView.panelIn;
    return MafiaTabletResultView.panelIn +
        MafiaTabletResultView.cardGap * (count - 1) +
        MafiaTabletResultView.cardIn +
        MafiaTabletResultView.flipDelay +
        MafiaTabletResultView.flipGap * (count - 1) +
        MafiaTabletResultView.cardFlip;
  }

  double get _elapsedMs => _reveal.value * _totalDuration.inMilliseconds;

  /// 판이 올라온 진행도입니다.
  double get _panelProgress => Curves.easeOutCubic.transform(
    (_elapsedMs / MafiaTabletResultView.panelIn.inMilliseconds).clamp(0.0, 1.0),
  );

  /// [index]번째 카드가 놓인 진행도입니다.
  double _cardProgress(int index) {
    final start =
        MafiaTabletResultView.panelIn.inMilliseconds +
        MafiaTabletResultView.cardGap.inMilliseconds * index;
    return Curves.easeOutBack.transform(
      ((_elapsedMs - start) / MafiaTabletResultView.cardIn.inMilliseconds)
          .clamp(0.0, 1.0),
    );
  }

  /// [index]번째 카드가 뒤집힌 진행도입니다.
  double _flipProgress(int index) {
    final count = _ordered.length;
    final start =
        MafiaTabletResultView.panelIn.inMilliseconds +
        MafiaTabletResultView.cardGap.inMilliseconds * (count - 1) +
        MafiaTabletResultView.cardIn.inMilliseconds +
        MafiaTabletResultView.flipDelay.inMilliseconds +
        MafiaTabletResultView.flipGap.inMilliseconds * index;
    final raw =
        ((_elapsedMs - start) / MafiaTabletResultView.cardFlip.inMilliseconds)
            .clamp(0.0, 1.0);
    // 종이 카드처럼 시작·끝을 눙깁니다(다른 카드 연출과 같은 곡선).
    return Curves.easeInOutCubic.transform(raw);
  }

  /// 버튼이 나타난 진행도입니다. 카드가 다 놓이면 바로 누를 수 있습니다.
  double get _buttonProgress {
    final count = _ordered.length;
    final placed =
        MafiaTabletResultView.panelIn.inMilliseconds +
        MafiaTabletResultView.cardGap.inMilliseconds *
            (count == 0 ? 0 : count - 1) +
        MafiaTabletResultView.cardIn.inMilliseconds;
    return Curves.easeOut.transform(
      ((_elapsedMs - placed) / 300).clamp(0.0, 1.0),
    );
  }

  //=======================자리 계산==============================
  double get _cardHeight => _cardWidth / _cardAspectRatio;

  /// 한 칸(카드 + 닉네임)의 높이입니다.
  double get _cellHeight => _cardHeight + _nicknameGap + _nicknameHeight;

  int get _rowCount => (_ordered.length / _columns).ceil().clamp(1, 2);

  /// 카드 묶음이 시작하는 top입니다. 한 줄이면 구간 가운데에 옵니다.
  double get _blockTop {
    final blockHeight = _cellHeight * _rowCount + _rowGap * (_rowCount - 1);
    final band = _cardsBottom - _cardsTop;
    return _cardsTop + (band - blockHeight) / 2;
  }

  /// [index]번째 카드의 사각형입니다. 줄마다 가운데 정렬합니다.
  Rect _cardRect(int index) {
    final row = index ~/ _columns;
    final column = index % _columns;
    final inRow = row == 0
        ? (_ordered.length < _columns ? _ordered.length : _columns)
        : _ordered.length - _columns;
    final rowWidth = _cardStep * (inRow - 1) + _cardWidth;
    final left = _panel.center.dx - rowWidth / 2 + _cardStep * column;
    return Rect.fromLTWH(
      left,
      _blockTop + (_cellHeight + _rowGap) * row,
      _cardWidth,
      _cardHeight,
    );
  }

  @override
  Widget build(BuildContext context) {
    final poster = _poster;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (poster != null)
          poster.image(fit: BoxFit.cover, filterQuality: FilterQuality.high),
        // 배경만 보이는 동안 화면 어디를 눌러도 결과로 넘어갑니다.
        // 버튼은 이 위에 있어 계속 눌립니다.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _handleTap,
          ),
        ),
        if (_showsBoard)
          AnimatedBuilder(
            animation: _reveal,
            builder: (context, _) =>
                Stack(fit: StackFit.expand, children: _buildBoard()),
          ),
      ],
    );
  }

  //=======================판·카드·버튼==============================
  List<Widget> _buildBoard() {
    final label = widget.winnerLabel;
    final showsLabel = label != null && label.isNotEmpty && _poster == null;

    return [
      // 인물 그림은 판 뒤에서 머리만 내밉니다.
      // 승리 그림이 없는 경우(중립 개별 승리)에만 문구로 알려 줍니다.
      if (showsLabel)
        _lifted(
          progress: _panelProgress,
          child: MafiaTabletBox(
            rect: _winnerLabelRect,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    color: MafiaResultArt.color(widget.winner),
                    fontSize: 44,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      _lifted(
        progress: _panelProgress,
        child: MafiaTabletBox(
          rect: _characters,
          child: Assets.games.mafia.images.other.resultCharacters.game.image(
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
      _lifted(
        progress: _panelProgress,
        child: MafiaTabletBox(
          rect: _panel,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(_panelRadius),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x59000000),
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
              ],
            ),
          ),
        ),
      ),
      for (var index = 0; index < _ordered.length; index += 1)
        ..._buildCard(index),
      _lifted(
        progress: _buttonProgress,
        child: _buildButton(_restartButton, '다시하기', widget.onRestart),
      ),
      _lifted(
        progress: _buttonProgress,
        child: _buildButton(_homeButton, '홈으로', widget.onHome),
      ),
    ];
  }

  /// 아래에서 살짝 올라오며 떠오르는 요소입니다.
  Widget _lifted({required double progress, required Widget child}) {
    if (progress <= 0) return const SizedBox.shrink();
    return Opacity(
      opacity: progress.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, 18 * (1 - progress)),
        child: child,
      ),
    );
  }

  List<Widget> _buildCard(int index) {
    final placed = _cardProgress(index);
    if (placed <= 0) return const [];

    final player = _ordered[index];
    final role = widget.revealedRoles[player.uid];
    final rect = _cardRect(index);
    final flip = _flipProgress(index);

    return [
      MafiaTabletBox(
        rect: rect,
        child: Opacity(
          // 놓이는 동안만 살짝 흐립니다.
          opacity: placed.clamp(0.0, 1.0),
          child: Transform.scale(
            // 살짝 작게 나타나 제 크기가 됩니다.
            scale: 0.86 + 0.14 * placed.clamp(0.0, 1.0),
            child: MafiaFlipCard(
              progress: flip,
              front: role?.card,
              back: Assets.games.mafia.images.cards.roleBack.game,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
      // 닉네임은 카드 아래에 늘 그대로 있습니다.
      MafiaTabletBox(
        rect: Rect.fromLTWH(
          rect.left - _cardStep / 2 + _cardWidth / 2,
          rect.bottom + _nicknameGap,
          _cardStep,
          _nicknameHeight,
        ),
        child: Opacity(
          opacity: placed.clamp(0.0, 1.0),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                player.nickname,
                maxLines: 1,
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  // 사망자는 조금 흐리게 해 생사도 함께 알려 줍니다.
                  height: 1.1,
                  decoration: player.isAlive
                      ? TextDecoration.none
                      : TextDecoration.lineThrough,
                ),
              ),
            ),
          ),
        ),
      ),
    ];
  }

  Widget _buildButton(Rect rect, String label, VoidCallback? onTap) {
    return MafiaTabletBox(
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
    );
  }
}
