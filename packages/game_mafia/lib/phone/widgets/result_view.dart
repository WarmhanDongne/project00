// [result_view.dart] 는 마피아에서 사용하는 휴대폰 게임 화면에서 재사용하는 UI 조각을 구성하는 파일이다.
//
// - [Package] : 마피아
// - [PhoneWidget] : 휴대폰 게임 화면에서 재사용하는 UI 조각을 구성함
//
// 즉, 플레이어 조작과 상태 표시를 화면별로 나눠 관리하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'package:flutter/material.dart';
import 'package:game_mafia/shared/widgets/result_art.dart';
import 'package:game_mafia/game_assets.dart';
import 'package:game_mafia/game_theme.dart';
import 'package:game_mafia/gen/assets.gen.dart';
import 'package:game_mafia/shared/animations/announcement_reveal.dart';
import 'package:game_mafia/shared/models/player.dart';
import 'package:game_mafia/shared/models/role.dart';
import 'package:game_mafia/shared/widgets/noir.dart';
import 'package:game_mafia/phone/widgets/game_layout.dart';

// ============================================================

// ---------------------------------------------------------------------------
// P9 결과 화면
// ---------------------------------------------------------------------------
/// 게임 결과 화면입니다(시안 `phone-p9`).
///
/// 시안은 **화면 전체를 덮는 승리 포스터 한 장**입니다. 문구도 버튼도 없습니다.
/// 다시하기·홈으로 버튼은 시안상 **태블릿에만** 있고, 이는 의도된 것으로
/// 확인되었습니다. 태블릿이 공용 결과 화면입니다.
///
/// 포스터는 승리 진영으로 고릅니다([MafiaResultArt]). 중립 역할이 개별 조건으로
/// 이기는 경우(광대·처형자·생존자 등)에는 전용 포스터가 없으므로 승리 문구를
/// 대신 보여 줍니다. 결과 화면이 빈 화면으로 남는 것보다 낫기 때문입니다.
class MafiaResultView extends StatelessWidget {
  const MafiaResultView({
    super.key,
    required this.winner,
    this.winnerRoleIds = const {},
    this.winnerLabel,
    this.myRole,
    this.didWin,
    this.allies = const [],
    this.onConfirm,
  });

  final MafiaFaction? winner;
  final Set<String> winnerRoleIds;
  final String? winnerLabel;

  /// 내 신분입니다. 결과 카드로 보여 줍니다.
  final MafiaRole? myRole;

  /// 내가 이겼는지입니다. 모르면 띠를 두르지 않습니다.
  final bool? didWin;

  /// 함께한 동료입니다(서로 알고 시작한 같은 편).
  final List<MafiaPlayer> allies;

  /// '확인'을 누르면 전원 신분 명단으로 넘어갑니다.
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    final card = myRole?.card ?? Assets.games.mafia.images.cards.roleBack.game;
    final label = winnerLabel ?? MafiaResultArt.label(winner);
    final won = didWin;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = MafiaPhoneDesign.resolve(constraints);
        final scale = MafiaPhoneDesign.scaleOf(size);
        final cardWidth = 230 * scale;
        final cardHeight = 337 * scale;
        return Stack(
          fit: StackFit.expand,
          children: [
            const Positioned.fill(
              child: MafiaNoirRays.blood(origin: Alignment(0, -0.24)),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: MafiaPhoneDesign.top(size, 96),
              child: Text(
                'GAME OVER',
                textAlign: TextAlign.center,
                style: mafiaNoirBody(
                  13 * scale,
                  color: MafiaColors.noirBrass,
                  letterSpacing: 6.5 * scale,
                ),
              ),
            ),
            Positioned(
              left: MafiaPhoneDesign.left(size, 20),
              right: MafiaPhoneDesign.left(size, 20),
              top: MafiaPhoneDesign.top(size, 118),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: mafiaNoirDisplay(60 * scale, height: 1),
                ),
              ),
            ),
            Positioned(
              left: (size.width - 260 * scale) / 2,
              width: 260 * scale,
              top: MafiaPhoneDesign.top(size, 188),
              height: 8 * scale,
              child: ColoredBox(
                color: winner == MafiaFaction.citizen
                    ? MafiaColors.noirTeal
                    : MafiaColors.noirBlood,
              ),
            ),
            Positioned(
              left: (size.width - cardWidth) / 2,
              top: MafiaPhoneDesign.top(size, 226),
              width: cardWidth,
              height: cardHeight,
              child: MafiaAnnouncementReveal(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10 * scale),
                    border: Border.all(color: MafiaColors.noirBrass, width: 3),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0xB3000000),
                        blurRadius: 50,
                        offset: Offset(0, 24),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8 * scale),
                    child: Stack(
                      fit: StackFit.expand,
                      clipBehavior: Clip.hardEdge,
                      children: [
                        card.image(fit: BoxFit.cover),
                        if (won != null)
                          MafiaNoirBanner(
                            spec: MafiaNoirBannerSpec(
                              label: won ? '승리' : '패배',
                              color: won
                                  ? MafiaColors.noirBrass
                                  : MafiaColors.noirBlood,
                              textColor: won
                                  ? MafiaColors.noirInk
                                  : MafiaColors.noirPaper,
                              top: 0.68,
                              angle: -12,
                              letterSpacing: 0.4,
                            ),
                            cardWidth: cardWidth,
                            cardHeight: cardHeight,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (won != null)
              Positioned(
                left: 0,
                right: 0,
                top: MafiaPhoneDesign.top(size, 588),
                child: Text(
                  won ? '당신의 팀이 이겼습니다' : '당신의 팀이 졌습니다',
                  textAlign: TextAlign.center,
                  style: mafiaNoirDisplay(24 * scale),
                ),
              ),
            if (allies.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                top: MafiaPhoneDesign.top(size, 626),
                child: Center(
                  child: Transform.scale(
                    scale: scale,
                    child: MafiaNoirRuledLabel(
                      label: '함께한 동료',
                      value: '',
                      labelColor: MafiaColors.noirRose,
                      lineColor: const Color(0xFF3A3F3C),
                      valueWidget: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final ally in allies) ...[
                            SizedBox(
                              width: 32,
                              height: 32,
                              child: MafiaNoirFace(player: ally),
                            ),
                            const SizedBox(width: 6),
                            Text(ally.nickname, style: mafiaNoirDisplay(20)),
                            const SizedBox(width: 10),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            MafiaPhoneActionButton(
              label: '확인',
              onTap: onConfirm,
              enabled: onConfirm != null,
            ),
            Positioned(
              left: 0,
              right: 0,
              top: MafiaPhoneDesign.top(size, 784),
              child: Text(
                '다음 판은 태블릿에서 시작해요',
                textAlign: TextAlign.center,
                style: mafiaNoirBody(
                  13 * scale,
                  color: const Color(0xFF6E6A5D),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
