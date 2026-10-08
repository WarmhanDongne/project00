// [result_sequence.dart] 는 마피아에서 사용하는 휴대폰 게임 화면에서 재사용하는 UI 조각을 구성하는 파일이다.
//
// - [Package] : 마피아
// - [PhoneWidget] : 휴대폰 게임 화면에서 재사용하는 UI 조각을 구성함
//
// 즉, 플레이어 조작과 상태 표시를 화면별로 나눠 관리하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'package:flutter/material.dart';
import 'package:game_mafia/shared/animations/announcement_reveal.dart';
import 'package:game_mafia/shared/models/player.dart';
import 'package:game_mafia/shared/models/role.dart';
import 'package:game_mafia/phone/widgets/result_view.dart';
import 'package:game_mafia/phone/widgets/spectator_roster_view.dart';

// ============================================================

// ---------------------------------------------------------------------------
// P9 휴대폰 결과 순서
// ---------------------------------------------------------------------------
/// 승리 포스터를 보여 주고, '확인'을 누르면 전원 신분 명단으로 넘어갑니다.
///
/// Noir 시안(2026-10-08): 휴대폰 결과는 내 신분 카드에 승리/패배 띠를 두른
/// 포스터이고, 사용자가 확인을 누를 때 명단으로 넘어갑니다.
///
/// | 박자 | 내용 |
/// |---|---|
/// | 1 | 승리 포스터(Noir 시안 ⑪): 승패 문구, 내 신분 카드, 함께한 동료, 확인 |
/// | 2 | '확인'을 누르면 전원 신분 명단 |
///
/// 다시하기·홈으로 버튼은 시안대로 **태블릿에만** 있습니다. 휴대폰은 결과를
/// 확인하는 화면입니다.
class MafiaPhoneResultSequence extends StatefulWidget {
  const MafiaPhoneResultSequence({
    super.key,
    required this.winner,
    required this.players,
    required this.revealedRoles,
    this.myUid,
    this.myRole,
    this.winnerRoleIds = const {},
    this.winnerLabel,
    this.didWin,
    this.allies = const [],
  });

  /// 승리 진영입니다. 중립 개별 승리는 전용 그림이 없어 문구로 대신합니다.
  final MafiaFaction? winner;

  /// 자리 순서대로 정렬된 플레이어입니다.
  final List<MafiaPlayer> players;

  /// 전원 신분입니다. 게임이 끝나면 서버가 모두 공개합니다.
  final Map<String, MafiaRole?> revealedRoles;

  /// 내 uid입니다. 명단에서 내 닉네임을 빨간색으로 표시합니다.
  final String? myUid;

  /// 내 신분입니다. 명단 화면의 아래 카드에 씁니다.
  final MafiaRole? myRole;

  /// 이긴 사람들의 역할 id입니다. 중립 포스터를 고르는 데 씁니다.
  ///
  /// 중립은 진영이 같아도 이긴 역할에 따라 그림이 다릅니다(광대/처형자/
  /// 연쇄살인마/교단).
  final Set<String> winnerRoleIds;

  /// 승리 문구를 덮어쓸 때 씁니다(예: `광대 승리`).
  ///
  /// 포스터가 있는 승리는 그림에 문구가 들어 있어 쓰이지 않습니다.
  final String? winnerLabel;

  /// 내가 이겼는지입니다.
  final bool? didWin;

  /// 함께한 동료입니다.
  final List<MafiaPlayer> allies;

  @override
  State<MafiaPhoneResultSequence> createState() =>
      _MafiaPhoneResultSequenceState();
}

class _MafiaPhoneResultSequenceState extends State<MafiaPhoneResultSequence> {
  /// 결과 포스터에서 '확인'을 누르면 전원 신분 명단으로 넘어갑니다.
  bool _showsRoster = false;

  @override
  Widget build(BuildContext context) {
    // 그림에서 명단으로 넘어갈 때, 다른 발표들과 같은 말투로 떠오릅니다.
    return Stack(
      fit: StackFit.expand,
      children: [
        if (!_showsRoster)
          MafiaResultView(
            winner: widget.winner,
            winnerRoleIds: widget.winnerRoleIds,
            winnerLabel: widget.winnerLabel,
            myRole: widget.myRole,
            didWin: widget.didWin,
            allies: widget.allies,
            onConfirm: () => setState(() => _showsRoster = true),
          )
        else
          MafiaAnnouncementReveal(
            child: MafiaSpectatorRosterView(
              myRole: widget.myRole,
              myUid: widget.myUid,
              // 게임이 끝난 뒤의 명단입니다('신분 정보', 안내 문구 없음).
              isFinished: true,
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
