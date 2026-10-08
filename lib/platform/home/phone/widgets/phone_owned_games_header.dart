import 'package:project00/platform/localization/platform_localizations.dart';
import 'package:flutter/material.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';

/// 휴대폰 홈의 보유 게임 제목입니다.
///
/// 좁은 화면에서는 설명을 다음 줄로 보내 제목과 함께 화면 밖으로 밀려나지 않게
/// 합니다. 고정 [Row]는 Galaxy S20+ 폭에서 43px overflow를 만들었습니다.
class PhoneOwnedGamesHeader extends StatelessWidget {
  const PhoneOwnedGamesHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          context.l10n.ownedGames,
          style: MosiFonts.sans(
            locale: Localizations.maybeLocaleOf(context),
            size: 20,
            weight: FontWeight.w700,
            color: MosiColors.navy,
            letterSpacing: -0.5,
          ),
        ),
        Text(
          context.l10n.phonePlayHint,
          style: MosiFonts.sans(
            locale: Localizations.maybeLocaleOf(context),
            size: 12,
            color: MosiColors.muted,
          ),
        ),
      ],
    );
  }
}
