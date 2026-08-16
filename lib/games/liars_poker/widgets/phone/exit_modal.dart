import 'package:flutter/material.dart';
import 'package:project00/games/shared/widgets/phone_exit_modal.dart';
import 'package:project00/gen/assets.gen.dart';

/// Liar's Poker 테마를 공용 퇴장 모달에 연결합니다.
class PhoneExitModal extends StatelessWidget {
  const PhoneExitModal({super.key});

  static Future<bool?> show(BuildContext context, {Offset? origin}) {
    return SharedPhoneExitModal.show(
      context,
      origin: origin,
      doorImage: Assets.games.liarsPoker.images.modal.modalImageDoor.image(
        fit: BoxFit.contain,
      ),

      // 모달 전체 배경 - 문 프레임과 연결되는 딥 퍼플
      surfaceColor: const Color(0xFF1B1022),

      // 주요 버튼 - 문 안쪽의 보라빛을 톤다운한 컬러
      primaryColor: const Color(0xFF6E2A82),

      // 제목
      titleColor: const Color(0xFFF8F4FA),

      // 설명
      descriptionColor: const Color(0xFFC7B8CC),
      showSurface: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SharedPhoneExitModal(
      doorImage: Assets.games.liarsPoker.images.modal.modalImageDoor.image(
        fit: BoxFit.contain,
      ),
      surfaceColor: const Color(0xFF1B1022),
      primaryColor: const Color(0xFF6E2A82),
      titleColor: const Color(0xFFF8F4FA),
      descriptionColor: const Color(0xFFC7B8CC),
      showSurface: false,
    );
  }
}
