// [exit_modal.dart] 라이어스 포커 테마와 자산을
// 공용 휴대폰 게임 퇴장 모달에 연결하는 파일이다.

// ========================[ import ]==========================
import 'package:flutter/material.dart';
import 'package:game_kit/widgets/phone_exit_modal.dart';
import 'package:game_liars_poker/gen/assets.gen.dart';
import 'package:game_liars_poker/game_assets.dart';
import 'package:game_liars_poker/game_theme.dart';
// ============================================================

/// Liar's Poker 테마를 공용 퇴장 모달에 연결합니다.
class PhoneExitModal extends StatelessWidget {
  const PhoneExitModal({super.key});

  static Future<bool?> show(BuildContext context, {Offset? origin}) {
    return SharedPhoneExitModal.show(
      context,
      origin: origin,
      doorImage: Assets.games.liarsPoker.images.modal.modalImageDoor.game.image(
        fit: BoxFit.contain,
      ),
      surfaceColor: LiarsPokerColors.surface,
      primaryColor: LiarsPokerColors.primary,
      titleColor: LiarsPokerColors.title,
      descriptionColor: LiarsPokerColors.description,
      showSurface: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SharedPhoneExitModal(
      doorImage: Assets.games.liarsPoker.images.modal.modalImageDoor.game.image(
        fit: BoxFit.contain,
      ),
      surfaceColor: LiarsPokerColors.surface,
      primaryColor: LiarsPokerColors.primary,
      titleColor: LiarsPokerColors.title,
      descriptionColor: LiarsPokerColors.description,
      showSurface: false,
    );
  }
}
