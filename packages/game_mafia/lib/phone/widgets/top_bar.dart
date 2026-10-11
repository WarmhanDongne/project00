// [top_bar.dart] 는 마피아에서 사용하는 휴대폰 게임 화면에서 재사용하는 UI 조각을 구성하는 파일이다.
//
// - [Package] : 마피아
// - [PhoneWidget] : 휴대폰 게임 화면에서 재사용하는 UI 조각을 구성함
//
// 즉, 플레이어 조작과 상태 표시를 화면별로 나눠 관리하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'package:flutter/material.dart';
import 'package:game_mafia/game_copy.dart';
import 'package:game_kit/phone/widgets/rule_dialog.dart';
import 'package:game_kit/phone/widgets/ripple_dialog.dart';
import 'package:game_mafia/shared/models/player.dart';
import 'package:game_mafia/shared/widgets/noir.dart';
import 'package:game_mafia/game_theme.dart';

// ============================================================

/// 상단바가 차지하는 높이입니다(시안: 위 20 + 바 46).
///
/// 상단바는 공용 셸이 화면 위에 겹쳐 그리므로, 게임 화면은 이 높이를 비워 두어야
/// 시안 좌표가 밀리지 않습니다.
const double mafiaPhoneTopBarHeight = 66;

/// 마피아 휴대폰 상단바입니다(Noir Poster 시안).
///
/// 왼쪽은 내 얼굴·이름과 `3일째 밤` 같은 진행 꼬리표, 오른쪽은 규칙·나가기입니다.
/// 표시 시점과 등장 연출은 공용 셸이 제어하고 이 위젯은 내용만 그립니다.
class MafiaPhoneTopBar extends StatelessWidget {
  const MafiaPhoneTopBar({
    super.key,
    required this.onExitRoom,
    required this.onRulesPressed,
    this.me,
    this.subtitle,
    this.isNight = false,
    this.spectating = false,
  });

  final VoidCallback onExitRoom;
  final ValueChanged<Offset?> onRulesPressed;

  /// 내 프로필입니다. 아직 모르면 버튼만 그립니다.
  final MafiaPlayer? me;

  /// 이름 아래 진행 꼬리표입니다(예: `3일째 밤`).
  final String? subtitle;

  /// 밤(먹색 바탕)인지입니다. 글자색을 바꿉니다.
  final bool isNight;

  /// 사망 후 관전 중인지입니다. 얼굴을 흑백으로, 이름 옆에 `관전`을 붙입니다.
  final bool spectating;

  /// 단계와 라운드로 진행 꼬리표를 만듭니다.
  static String? subtitleFor({required String phase, required int round}) {
    if (round <= 0) return null;
    final part = switch (phase) {
      'night' => '밤',
      'morning' => '아침',
      'day' => '낮',
      'voting' || 'voteResult' => '낮 · 투표',
      _ => null,
    };
    return part == null ? null : '$round일째 $part';
  }

  @override
  Widget build(BuildContext context) {
    final me = this.me;
    final dark = isNight || spectating;
    final nameColor = dark ? MafiaColors.noirPaper : MafiaColors.noirInk;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 0),
      child: SizedBox(
        height: 46,
        child: Row(
          children: [
            if (me != null) ...[
              MafiaNoirFaceTile(
                player: me,
                borderColor: spectating
                    ? MafiaColors.noirFaded
                    : dark
                    ? MafiaColors.noirBrass
                    : MafiaColors.noirInk,
                grayscale: spectating,
              ),
              const SizedBox(width: 10),
              // 이름 칸이 버튼 앞까지 남은 폭을 모두 씁니다. 그래도 길면
              // (닉네임 8자 + 관전, 작은 휴대폰) 자르지 않고 줄입니다.
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text.rich(
                        TextSpan(
                          text: me.nickname,
                          children: [
                            if (spectating)
                              TextSpan(
                                text: '  관전',
                                style: mafiaNoirBody(
                                  12,
                                  color: MafiaColors.noirBlood,
                                  weight: FontWeight.w700,
                                ),
                              ),
                          ],
                        ),
                        maxLines: 1,
                        style: mafiaNoirDisplay(18, color: nameColor),
                      ),
                    ),
                    if (subtitle != null)
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          spectating ? '$subtitle 진행 중' : subtitle!,
                          maxLines: 1,
                          style: mafiaNoirBody(
                            12,
                            color: dark
                                ? MafiaColors.noirDust
                                : MafiaColors.noirUmber,
                            height: 1.3,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
            ] else
              const Spacer(),
            Builder(
              builder: (buttonContext) => MafiaNoirIconButton(
                semanticLabel: '게임 규칙 열기',
                color: dark ? MafiaColors.noirSlab : MafiaColors.noirInk,
                onTap: () {
                  final box = buttonContext.findRenderObject() as RenderBox?;
                  onRulesPressed(
                    box?.localToGlobal(box.size.center(Offset.zero)),
                  );
                },
                child: Text(
                  '?',
                  style: mafiaNoirDisplay(20, color: MafiaColors.noirBrass),
                ),
              ),
            ),
            const SizedBox(width: 10),
            MafiaNoirIconButton(
              semanticLabel: '게임과 그룹 나가기',
              color: dark ? MafiaColors.noirSlab : MafiaColors.noirInk,
              onTap: onExitRoom,
              child: const MafiaNoirExitGlyph(),
            ),
          ],
        ),
      ),
    );
  }
}

/// 룰 다이얼로그를 엽니다. 상단바 책 버튼이 부릅니다.
///
/// 배경이 밝은 시안이라 파이널콜과 달리 흰 바탕 + 검은 글자를 씁니다.
void showMafiaRules(BuildContext context, [Offset? origin, String? rules]) {
  final screenSize = MediaQuery.sizeOf(context);
  showPhoneRippleDialog<void>(
    context: context,
    origin: origin ?? Offset(screenSize.width - 82, 28),
    builder: (_) => PhoneGameRuleDialog(
      title: '마피아',
      rules: rules ?? MafiaCopy.phoneRules,
      surfaceColor: MafiaColors.noirInk,
      foregroundColor: MafiaColors.noirPaper,
      dismissOnAnyTap: true,
    ),
  );
}
