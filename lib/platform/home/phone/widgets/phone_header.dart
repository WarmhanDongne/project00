import 'package:project00/platform/localization/locale_settings_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:project00/platform/home/howtoplay/screens/how_to_play_route.dart';
import 'package:project00/platform/localization/platform_localizations.dart';
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
        decoration: const BoxDecoration(color: MosiColors.violet),
        child: Row(
          children: [
            const Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: MosiLogo(markSize: 26, titleSize: 18),
                ),
              ),
            ),
            const SizedBox(width: 4),
            // 그룹 참여 버튼은 화면 하단 고정 바(PhoneHome)로 옮겼습니다.
            IconButton(
              tooltip: context.l10n.howToPlay,
              onPressed: () => openHowToPlay(context),
              icon: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: MosiColors.white, width: 1.5),
                ),
                child: Text(
                  '?',
                  style: MosiFonts.grotesk(size: 20, color: MosiColors.white),
                ),
              ),
              padding: EdgeInsets.zero,
            ),
            const SizedBox(width: 4),
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: MosiColors.white, width: 1.5),
              ),
              child: const LocaleSettingsButton(),
            ),
            const SizedBox(width: 6),
            const PhoneProfile(),
          ],
        ),
      ),
    );
  }
}
