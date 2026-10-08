// [spectator_roster_view.dart] 는 마피아에서 사용하는 휴대폰 게임 화면에서 재사용하는 UI 조각을 구성하는 파일이다.
//
// - [Package] : 마피아
// - [PhoneWidget] : 휴대폰 게임 화면에서 재사용하는 UI 조각을 구성함
//
// 즉, 플레이어 조작과 상태 표시를 화면별로 나눠 관리하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'package:flutter/material.dart';
import 'package:game_mafia/shared/widgets/private_peek.dart';
import 'package:game_mafia/game_assets.dart';
import 'package:game_mafia/shared/models/player.dart';
import 'package:game_mafia/shared/models/role.dart';
import 'package:game_mafia/phone/widgets/game_layout.dart';
import 'package:game_mafia/gen/assets.gen.dart';
import 'package:game_mafia/game_theme.dart';
import 'package:game_mafia/shared/widgets/noir.dart';

// ============================================================

/// 관전자에게 공개된 플레이어 한 명입니다.
///
/// 신분은 **서버가 보낸 값을 그대로** 담습니다. 클라이언트가 다시 계산하면
/// 밀러·마피아 보스처럼 보이는 진영이 다른 역할에서 어긋납니다.
@immutable
class MafiaRevealedPlayer {
  const MafiaRevealedPlayer({required this.player, required this.role});

  final MafiaPlayer player;

  /// 공개된 신분입니다. 이 빌드가 모르는 신분이면 null입니다.
  final MafiaRole? role;
}

// ---------------------------------------------------------------------------
// P8 관전자 정보
// ---------------------------------------------------------------------------
/// 사망한 뒤 보는 관전 화면입니다. 시안 P8의 낮·밤 두 상태가 이 위젯 하나입니다.
///
/// 살아 있는 동안에는 볼 수 없던 **모든 플레이어의 신분**을 격자로 보여 줍니다.
/// 낮과 밤의 차이는 배경과 글자색뿐입니다.
///
/// 역할 이름으로 분기하지 않고 [MafiaRole]의 값만 읽으므로, 새 신분을 추가해도
/// 이 화면은 수정할 필요가 없습니다.
class MafiaSpectatorRosterView extends StatelessWidget {
  const MafiaSpectatorRosterView({
    super.key,
    required this.myRole,
    required this.revealed,
    required this.isNight,
    this.myUid,
    this.isFinished = false,
  });

  final MafiaRole? myRole;
  final List<MafiaRevealedPlayer> revealed;

  /// 지금 밤인지입니다. Noir 시안의 관전 화면은 밤낮 모두 먹색 바탕입니다.
  final bool isNight;
  final String? myUid;
  final bool isFinished;

  static const double _labelTop = 96;
  static const double _titleTop = 116;
  static const double _warningTop = 166;
  static const double listTop = 206;
  static const double _listBottom = 780;

  static const String spectatingTitle = '관전 중';
  static const String finishedTitle = '신분 정보';
  static const String _warning = '살아 있는 사람에게 화면을 보여주지 마세요';

  @override
  Widget build(BuildContext context) {
    // 살아 있는 사람을 먼저, 떠난 사람을 뒤에 둡니다(시안).
    final ordered = [
      ...revealed.where((entry) => entry.player.isAlive),
      ...revealed.where((entry) => !entry.player.isAlive),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = MafiaPhoneDesign.resolve(constraints);
        final scale = MafiaPhoneDesign.scaleOf(size);
        final listHeight = (_listBottom - listTop) * scale;
        final rowHeight = (listHeight / ordered.length.clamp(1, 99)).clamp(
          44.0 * scale,
          69.0 * scale,
        );
        final list = _buildList(ordered, scale, rowHeight);
        return Stack(
          fit: StackFit.expand,
          children: [
            const Positioned.fill(child: MafiaNoirRays.night()),
            Positioned(
              left: 0,
              right: 0,
              top: MafiaPhoneDesign.top(size, _labelTop),
              child: Text(
                '모든 신분',
                textAlign: TextAlign.center,
                style: mafiaNoirBody(
                  13 * scale,
                  color: MafiaColors.noirBrass,
                  letterSpacing: 6 * scale,
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: MafiaPhoneDesign.top(size, _titleTop),
              child: Text(
                isFinished ? finishedTitle : spectatingTitle,
                textAlign: TextAlign.center,
                style: mafiaNoirDisplay(32 * scale),
              ),
            ),
            if (!isFinished)
              Positioned(
                left: 0,
                right: 0,
                top: MafiaPhoneDesign.top(size, _warningTop),
                child: Container(
                  color: MafiaColors.noirBlood,
                  padding: EdgeInsets.symmetric(vertical: 5 * scale),
                  child: Text(
                    _warning,
                    textAlign: TextAlign.center,
                    style: mafiaNoirBody(
                      13 * scale,
                      color: MafiaColors.noirPaper,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            Positioned(
              left: MafiaPhoneDesign.left(size, 24),
              right: MafiaPhoneDesign.left(size, 24),
              top: MafiaPhoneDesign.top(size, listTop),
              height: listHeight,
              child: isFinished
                  ? list
                  : MafiaPrivatePeek(
                      foregroundColor: MafiaColors.noirPaper,
                      height: listHeight,
                      child: list,
                    ),
            ),
            MafiaStoredRoleCard(role: myRole),
          ],
        );
      },
    );
  }

  Widget _buildList(
    List<MafiaRevealedPlayer> ordered,
    double scale,
    double rowHeight,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < ordered.length; index++)
          SizedBox(
            height: rowHeight,
            child: _MafiaRosterRow(
              entry: ordered[index],
              isMe: ordered[index].player.uid == myUid,
              last: index == ordered.length - 1,
              scale: scale,
              rowHeight: rowHeight,
            ),
          ),
      ],
    );
  }
}

/// 관전 명단 한 줄입니다. 신분 카드 · 얼굴 · 이름 · 신분(사망 사유)입니다.
class _MafiaRosterRow extends StatelessWidget {
  const _MafiaRosterRow({
    required this.entry,
    required this.isMe,
    required this.last,
    required this.scale,
    required this.rowHeight,
  });

  final MafiaRevealedPlayer entry;
  final bool isMe;
  final bool last;
  final double scale;
  final double rowHeight;

  /// 사망 사유를 신분 뒤에 붙입니다(예: `경찰 · 처형`).
  static String? deathLabel(MafiaPlayer player) {
    if (player.isAlive) return null;
    if (player.wasExecuted) return '처형';
    if (player.diedAtNight) return '사망';
    return '퇴장';
  }

  @override
  Widget build(BuildContext context) {
    final player = entry.player;
    final role = entry.role;
    final alive = player.isAlive;
    final death = deathLabel(player);
    final roleName = role?.displayName ?? '알 수 없음';
    final roleColor = !alive
        ? MafiaColors.noirPaper
        : role == null
        ? MafiaColors.noirDust
        : role.faction.isMafia
        ? MafiaColors.noirRose
        : role.faction.isNeutral
        ? MafiaColors.noirBrass
        : role.id == 'citizen'
        ? const Color(0xFFA39A86)
        : const Color(0xFF7FB0A2);
    final thumbHeight = rowHeight - 12 * scale;
    final card = role?.card ?? Assets.games.mafia.images.cards.roleBack.game;
    return Semantics(
      label: '${player.nickname} $roleName${death == null ? '' : ' $death'}',
      excludeSemantics: true,
      child: Opacity(
        opacity: alive ? 1 : 0.45,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 4 * scale),
          decoration: BoxDecoration(
            border: last
                ? null
                : const Border(bottom: BorderSide(color: Color(0xFF2A2F2C))),
          ),
          child: Row(
            children: [
              Container(
                width: thumbHeight * 38 / 56,
                height: thumbHeight,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: role?.faction.isMafia ?? false
                        ? MafiaColors.noirBlood
                        : MafiaColors.noirFaded,
                  ),
                ),
                child: card.image(fit: BoxFit.cover),
              ),
              SizedBox(width: 12 * scale),
              SizedBox(
                width: thumbHeight * 0.72,
                height: thumbHeight * 0.72,
                child: MafiaNoirFace(player: player, grayscale: !alive),
              ),
              SizedBox(width: 12 * scale),
              Expanded(
                child: Text(
                  isMe ? '${player.nickname} (나)' : player.nickname,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: mafiaNoirDisplay(20 * scale),
                ),
              ),
              Text(
                death == null ? roleName : '$roleName · $death',
                style: mafiaNoirBody(
                  14 * scale,
                  color: roleColor,
                  weight: alive ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
