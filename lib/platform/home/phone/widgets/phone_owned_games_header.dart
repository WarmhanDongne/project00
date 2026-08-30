import 'package:flutter/material.dart';
import 'package:project00/platform/theme/platform_theme.dart';

/// 휴대폰 홈의 보유 게임 제목입니다.
///
/// 좁은 화면에서는 설명을 다음 줄로 보내 제목과 함께 화면 밖으로 밀려나지 않게
/// 합니다. 고정 [Row]는 Galaxy S20+ 폭에서 43px overflow를 만들었습니다.
class PhoneOwnedGamesHeader extends StatelessWidget {
  const PhoneOwnedGamesHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    return Wrap(
      spacing: 10,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text(
          '보유 중인 게임',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        Text(
          '모바일에서는 방에 참여해 플레이합니다.',
          style: TextStyle(color: colors.textMuted, fontSize: 10),
        ),
      ],
    );
  }
}
