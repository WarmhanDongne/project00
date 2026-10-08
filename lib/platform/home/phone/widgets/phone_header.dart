import 'package:project00/platform/localization/locale_settings_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:project00/platform/home/howtoplay/widgets/how_to_play_button.dart';
import 'package:project00/platform/home/phone/widgets/phone_profile.dart';

/// 휴대폰 홈 머리: 보라 띠 위 로고 + 플레이 방법 + 내 프로필.
class PhoneHeader extends StatelessWidget {
  const PhoneHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          18,
          MediaQuery.paddingOf(context).top + 12,
          14,
          16,
        ),
        decoration: const BoxDecoration(
          color: MosiColors.violet,
          border: Border(bottom: BorderSide(color: MosiColors.ink, width: 3)),
        ),
        child: const Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: MosiLogo(markSize: 34, titleSize: 22),
                ),
              ),
            ),
            SizedBox(width: 10),
            // 그룹 참여 버튼은 화면 하단 고정 바(PhoneHome)로 옮겼습니다.
            HowToPlayButton(foreground: MosiColors.white),
            SizedBox(width: 10),
            LocaleSettingsButton(),
            SizedBox(width: 6),
            PhoneProfile(),
          ],
        ),
      ),
    );
  }
}
