import 'dart:async';

import 'package:flutter/material.dart';
import 'package:project00/games/mafia/mafia_result_art.dart';
import 'package:project00/games/mafia/models/mafia_player.dart';
import 'package:project00/games/mafia/models/mafia_role.dart';
import 'package:project00/games/mafia/screens/tablet/tablet_game_layout.dart';

//=======================태블릿 결과 화면==============================
/// 승리 진영을 알리고 전원 신분을 공개합니다(시안 `tablet-p9`).
///
/// 시안이 두 장입니다. **포스터 한 장 → 명단**으로 이어집니다.
///
/// | 박자 | 시안 | 내용 |
/// |---|---|---|
/// | 1 | `tablet-p9` (포스터) | 화면 전체를 덮는 승리 그림. 문구·버튼 없음 |
/// | 2 | `tablet-p9` (명단) | 배너 2장 + 진영별 명단 + 다시하기·홈으로 |
///
/// 명단은 플레이어별이 아니라 **진영별**입니다. 왼쪽이 승리 진영, 오른쪽이 패배
/// 진영이고 각 진영 구성원을 자기 배너 옆에 적습니다.
///
/// ⚠️ 배너 4장에 투명 채널이 없어 지금은 종이 배경 위에서 검은 사각형으로
/// 보입니다. 투명 PNG를 받으면 그대로 해결됩니다.
class MafiaTabletResultView extends StatefulWidget {
  const MafiaTabletResultView({
    super.key,
    required this.winner,
    required this.players,
    required this.revealedRoles,
    this.onRestart,
    this.onHome,
  });

  /// 승리 진영입니다. 중립 개별 승리는 포스터가 없어 명단만 보여 줍니다.
  final MafiaFaction? winner;

  final Map<String, MafiaPlayer> players;

  /// 전원 신분입니다. 게임이 끝나면 서버가 모두 공개합니다.
  final Map<String, MafiaRole?> revealedRoles;

  final VoidCallback? onRestart;
  final VoidCallback? onHome;

  /// 포스터를 보여 주는 시간입니다.
  static const Duration posterHold = Duration(milliseconds: 3400);

  @override
  State<MafiaTabletResultView> createState() => _MafiaTabletResultViewState();
}

class _MafiaTabletResultViewState extends State<MafiaTabletResultView> {
  //=======================시안 기준 좌표==============================
  /// 배너입니다. 왼쪽이 승리, 오른쪽이 패배 진영입니다.
  static const Rect _bannerLeft = Rect.fromLTWH(12, -11, 236, 716);
  static const Rect _bannerRight = Rect.fromLTWH(579, -11, 236, 716);

  /// 명단 한 줄입니다. 시안은 216.949 × 45.489, 줄 간격 55.987입니다.
  static const double _rowWidth = 216.949;
  static const double _rowHeight = 45.489;
  static const double _rowPitch = 55.987;
  static const double _rowFirstTop = 209;
  static const double _leftColumnLeft = 313;
  static const double _rightColumnLeft = 879;

  /// 한 진영에 보여 줄 최대 줄 수입니다(시안 6줄).
  static const int _rowsPerSide = 6;

  static const Rect _restartButton = Rect.fromLTWH(323, 705, 231, 79);
  static const Rect _homeButton = Rect.fromLTWH(756, 705, 231, 79);

  Timer? _posterTimer;
  bool _showsRoster = false;

  @override
  void initState() {
    super.initState();
    final poster = MafiaResultArt.tabletPoster(widget.winner);
    if (poster == null) {
      // 포스터가 없는 승리(중립 개별 조건)는 곧바로 명단을 보여 줍니다.
      _showsRoster = true;
      return;
    }
    _posterTimer = Timer(MafiaTabletResultView.posterHold, () {
      if (mounted) setState(() => _showsRoster = true);
    });
  }

  @override
  void dispose() {
    _posterTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final poster = MafiaResultArt.tabletPoster(widget.winner);
    if (!_showsRoster && poster != null) {
      return poster.image(fit: BoxFit.cover, filterQuality: FilterQuality.high);
    }
    return _buildRoster();
  }

  Widget _buildRoster() {
    final winnerBanner = MafiaResultArt.winnerBanner(widget.winner);
    final loserBanner = MafiaResultArt.loserBanner(widget.winner);
    final loser = MafiaResultArt.loserOf(widget.winner);

    return Stack(
      fit: StackFit.expand,
      children: [
        if (winnerBanner != null)
          MafiaTabletBox(
            rect: _bannerLeft,
            child: winnerBanner.image(fit: BoxFit.fill),
          ),
        if (loserBanner != null)
          MafiaTabletBox(
            rect: _bannerRight,
            child: loserBanner.image(fit: BoxFit.fill),
          ),
        ..._buildColumn(widget.winner, _leftColumnLeft),
        ..._buildColumn(loser, _rightColumnLeft),
        _buildButton(_restartButton, '다시하기', widget.onRestart),
        _buildButton(_homeButton, '홈으로', widget.onHome),
      ],
    );
  }

  /// 한 진영의 명단입니다. 시안 문구가 `신분 + 닉네임`이라 그 순서로 적습니다.
  List<Widget> _buildColumn(MafiaFaction? faction, double left) {
    if (faction == null) return const <Widget>[];
    final members = widget.players.values
        .where((player) {
          final role = widget.revealedRoles[player.uid];
          return role != null && role.faction == faction;
        })
        .toList(growable: false);

    return [
      for (
        var index = 0;
        index < members.length && index < _rowsPerSide;
        index += 1
      )
        MafiaTabletBox(
          rect: Rect.fromLTWH(
            left,
            _rowFirstTop + _rowPitch * index,
            _rowWidth,
            _rowHeight,
          ),
          child: _buildRow(members[index]),
        ),
    ];
  }

  Widget _buildRow(MafiaPlayer player) {
    final role = widget.revealedRoles[player.uid];
    final label = role == null
        ? player.nickname
        : '${role.displayName} ${player.nickname}';
    return Align(
      alignment: Alignment.centerLeft,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Opacity(
          // 사망자는 조금 흐리게 해 생존 여부를 함께 알려 줍니다.
          opacity: player.isAlive ? 1 : 0.55,
          child: Text(
            label,
            maxLines: 1,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 32,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
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
