// [morning_announcement_view.dart] 는 마피아에서 사용하는 휴대폰 게임 화면에서 재사용하는 UI 조각을 구성하는 파일이다.
//
// - [Package] : 마피아
// - [PhoneWidget] : 휴대폰 게임 화면에서 재사용하는 UI 조각을 구성함
//
// 즉, 플레이어 조작과 상태 표시를 화면별로 나눠 관리하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'package:flutter/material.dart';
import 'package:game_mafia/game_theme.dart';
import 'package:game_mafia/shared/animations/announcement_reveal.dart';
import 'package:game_mafia/shared/models/presentation_timing.dart';
import 'package:game_mafia/shared/widgets/noir.dart';
import 'package:game_mafia/shared/models/player.dart';
import 'package:game_mafia/shared/models/role.dart';
import 'package:game_mafia/shared/models/state_models.dart';
import 'package:game_mafia/phone/widgets/game_layout.dart';

// ============================================================

// ---------------------------------------------------------------------------
// 아침 발표 (휴대폰)
// ---------------------------------------------------------------------------
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
    this.hold = MafiaPresentationTiming.morningDeaths,
  });

  final MafiaRole? role;
  final MafiaMorningResult? result;
  final Map<String, MafiaPlayer> players;

  /// 이 발표가 머무는 시간입니다. 아래 진행 막대가 이 시간 동안 찹니다.
  final Duration hold;

  @override
  Widget build(BuildContext context) {
    final dead = [
      for (final uid in result?.deadUids ?? const <String>[]) ?players[uid],
    ];
    final names = dead.map((player) => player.nickname).join(' · ');
    final headline = dead.isEmpty
        ? '어젯밤은 아무도 쓰러지지 않았다'
        : '어젯밤, ${mafiaJosa(names, '이', '가')} 쓰러졌다';
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = MafiaPhoneDesign.resolve(constraints);
        final scale = MafiaPhoneDesign.scaleOf(size);
        final posterWidth = 250 * scale;
        final posterHeight = 340 * scale;
        return Stack(
          fit: StackFit.expand,
          children: [
            const Positioned.fill(child: MafiaPhoneBackground.day()),
            Positioned(
              left: 0,
              right: 0,
              top: MafiaPhoneDesign.top(size, 106),
              child: Text(
                '아침이 밝았다',
                textAlign: TextAlign.center,
                style: mafiaNoirDisplay(
                  50 * scale,
                  color: MafiaColors.noirInk,
                  height: 1,
                ),
              ),
            ),
            if (dead.isNotEmpty)
              Positioned(
                left: (size.width - posterWidth) / 2,
                top: MafiaPhoneDesign.top(size, 190),
                width: posterWidth,
                height: posterHeight,
                child: MafiaAnnouncementReveal(
                  child: MafiaNoirPoster(
                    player: dead.first,
                    width: posterWidth,
                    height: posterHeight,
                    banner: const MafiaNoirBannerSpec(
                      label: '어젯밤 사망',
                      top: 0.53,
                      angle: -14,
                    ),
                  ),
                ),
              )
            else
              Positioned(
                left: 0,
                right: 0,
                top: MafiaPhoneDesign.top(size, 210),
                child: Center(
                  child: MafiaNoirCityscape(
                    width: 300 * scale,
                    height: 220 * scale,
                  ),
                ),
              ),
            Positioned(
              left: MafiaPhoneDesign.left(size, 20),
              right: MafiaPhoneDesign.left(size, 20),
              top: MafiaPhoneDesign.top(size, 556),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  headline,
                  maxLines: 1,
                  style: mafiaNoirDisplay(
                    26 * scale,
                    color: MafiaColors.noirInk,
                  ),
                ),
              ),
            ),
            Positioned(
              left: MafiaPhoneDesign.left(size, 51),
              width: 300 * scale,
              top: MafiaPhoneDesign.top(size, 676),
              child: MafiaNoirProgress(duration: hold, label: '잠시 후 토론을 시작합니다'),
            ),
            MafiaStoredRoleCard(role: role),
          ],
        );
      },
    );
  }
}
