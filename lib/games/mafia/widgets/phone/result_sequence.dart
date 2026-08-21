import 'dart:async';

import 'package:flutter/material.dart';
import 'package:project00/games/mafia/animations/announcement_reveal.dart';
import 'package:project00/games/mafia/models/mafia_player.dart';
import 'package:project00/games/mafia/models/mafia_role.dart';
import 'package:project00/games/mafia/widgets/phone/result_view.dart';
import 'package:project00/games/mafia/widgets/phone/spectator_roster_view.dart';

//=======================P9 휴대폰 결과 순서==============================
/// 승리 그림을 잠깐 보여 준 뒤 전원 신분 명단으로 넘어갑니다.
///
/// 확정(2026-08): 승리 화면은 **2초만** 두고 곧바로 결과(전원 신분)로
/// 넘어갑니다. 태블릿도 같은 2초입니다
/// ([MafiaTabletResultView.posterHold]).
///
/// | 박자 | 내용 |
/// |---|---|
/// | 1 | 승리 그림 한 장(시민 승리 / 마피아 승리). 문구·버튼 없음 |
/// | 2 | 전원 신분 명단. 누가 무엇이었는지 확인합니다 |
///
/// 다시하기·홈으로 버튼은 시안대로 **태블릿에만** 있습니다. 휴대폰은 결과를
/// 확인하는 화면입니다.
class MafiaPhoneResultSequence extends StatefulWidget {
  const MafiaPhoneResultSequence({
    super.key,
    required this.winner,
    required this.players,
    required this.revealedRoles,
    this.myRole,
    this.winnerLabel,
    this.posterHold = defaultPosterHold,
  });

  /// 승리 진영입니다. 중립 개별 승리는 전용 그림이 없어 문구로 대신합니다.
  final MafiaFaction? winner;

  /// 자리 순서대로 정렬된 플레이어입니다.
  final List<MafiaPlayer> players;

  /// 전원 신분입니다. 게임이 끝나면 서버가 모두 공개합니다.
  final Map<String, MafiaRole?> revealedRoles;

  /// 내 신분입니다. 명단 화면의 아래 카드에 씁니다.
  final MafiaRole? myRole;

  /// 승리 문구를 덮어쓸 때 씁니다(예: `광대 승리`).
  final String? winnerLabel;

  /// 승리 그림을 보여 주는 시간입니다.
  final Duration posterHold;

  /// 확정 값입니다(태블릿과 같은 2초).
  static const Duration defaultPosterHold = Duration(seconds: 2);

  @override
  State<MafiaPhoneResultSequence> createState() =>
      _MafiaPhoneResultSequenceState();
}

class _MafiaPhoneResultSequenceState extends State<MafiaPhoneResultSequence> {
  bool _showsRoster = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.posterHold, () {
      if (mounted) setState(() => _showsRoster = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 그림에서 명단으로 넘어갈 때, 다른 발표들과 같은 말투로 떠오릅니다.
    return Stack(
      fit: StackFit.expand,
      children: [
        if (!_showsRoster)
          MafiaResultView(
            winner: widget.winner,
            winnerLabel: widget.winnerLabel,
          )
        else
          MafiaAnnouncementReveal(
            child: MafiaSpectatorRosterView(
              myRole: widget.myRole,
              // 결과 화면은 낮 배경으로 둡니다. 밤에 끝났더라도 게임이 끝난
              // 뒤이므로 어두운 배경을 유지할 이유가 없습니다.
              isNight: false,
              revealed: [
                for (final player in widget.players)
                  MafiaRevealedPlayer(
                    player: player,
                    role: widget.revealedRoles[player.uid],
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
