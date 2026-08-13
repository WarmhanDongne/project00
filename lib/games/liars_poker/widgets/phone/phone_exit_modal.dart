import 'package:flutter/material.dart';
import 'package:project00/games/shared/widgets/phone_exit_modal.dart';
import 'package:project00/gen/assets.gen.dart';

/// Liar's Poker 테마를 공용 퇴장 모달에 연결합니다.
class PhoneExitModal extends StatelessWidget {
  const PhoneExitModal({super.key});

  static Future<bool?> show(BuildContext context) {
    return SharedPhoneExitModal.show(
      context,
      doorImage: Assets.games.liarsPoker.images.modal.modalImageDoor.image(
        fit: BoxFit.contain,
      ),
      surfaceColor: const Color(0xFF142119),
      primaryColor: const Color(0xFF092014),
      titleColor: Colors.white,
      descriptionColor: const Color(0xFFB9C7BE),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SharedPhoneExitModal(
      doorImage: Assets.games.liarsPoker.images.modal.modalImageDoor.image(
        fit: BoxFit.contain,
      ),
      surfaceColor: const Color(0xFF142119),
      primaryColor: const Color(0xFF092014),
      titleColor: Colors.white,
      descriptionColor: const Color(0xFFB9C7BE),
    );
  }
}
