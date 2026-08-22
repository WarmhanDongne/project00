import 'package:flutter/material.dart';
import 'package:project00/games/mafia/mafia_copy.dart';
import 'package:project00/games/mafia/models/mafia_player.dart';
import 'package:project00/games/mafia/models/mafia_role.dart';
import 'package:project00/games/mafia/models/mafia_state_models.dart';
import 'package:project00/games/mafia/widgets/phone/mafia_phone_layout.dart';

//=======================아침 발표 (휴대폰)==============================
/// 아침 발표 동안 휴대폰이 보여 주는 화면입니다.
///
/// 확정: **태블릿과 같은 발표 문구**를 보여 줍니다.
/// `○○님은 밤을 넘기지 못했습니다.` / `어제 밤, 아무도 죽지 않았습니다.`
/// 문구는 두 박자로 나뉘어 내려찍힙니다([MafiaPhoneAnnouncement]).
///
/// ⚠️ 전용 시안이 없어 배치는 임시입니다(낮 배경 + 가운데 문구). 시안이 오면
/// 좌표만 맞추면 됩니다.
class MafiaMorningAnnouncementView extends StatelessWidget {
  const MafiaMorningAnnouncementView({
    super.key,
    required this.role,
    required this.result,
    required this.players,
  });

  /// 내 역할입니다. 아래 보관 카드에만 씁니다.
  final MafiaRole? role;

  final MafiaMorningResult? result;
  final Map<String, MafiaPlayer> players;

  @override
  Widget build(BuildContext context) {
    final current = result;
    final deadNames = current == null
        ? const <String>[]
        : current.deadUids
              .map((uid) => players[uid]?.nickname ?? '플레이어')
              .toList(growable: false);
    // 확정(2026-08): 태블릿과 같은 말투로 내려찍고, 두 박자로 나눠 띄웁니다.
    final beats = <String>[
      ...deadNames.isEmpty
          ? MafiaCopy.noDeathBeats
          : MafiaCopy.deathBeats(deadNames.join(' · ')),
      // 기자가 취재에 성공한 아침이면 그 사실도 알립니다. 카드를 뒤집어
      // 보여 주는 것은 방 가운데 태블릿이 맡습니다.
      if (current?.hasExposure ?? false) ...MafiaCopy.exposureBeats,
    ];

    return Stack(
      fit: StackFit.expand,
      children: [
        const Positioned.fill(child: MafiaPhoneBackground.day()),
        MafiaPhoneAnnouncement(
          beats: beats,
          top: MafiaPhoneStatusText.announcementTop,
        ),
        MafiaStoredRoleCard(role: role),
      ],
    );
  }
}
