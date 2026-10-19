import 'package:flutter/material.dart';
import 'package:game_kit/localization/game_locale.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';
import 'package:project00/platform/widgets/platform_components.dart';

/// 대기실의 `그룹 나가기` 버튼입니다.
///
/// 퇴장이 진행되는 동안 버튼을 잠가 중복 탭이 두 번째 요청을 만들지 않게 합니다.
/// 예전에는 잠금이 없어, 삼켜진 두 번째 탭이 첫 퇴장이 성공하는 중에도 실패
/// 안내를 띄웠습니다.
///
/// 헤더에서 분리한 이유는 `PhoneProfile`이 `FirebaseAuth`를 직접 구독해
/// 헤더 안에서는 이 버튼만 따로 위젯 테스트할 수 없기 때문입니다.
class PhoneRoomLeaveButton extends StatelessWidget {
  const PhoneRoomLeaveButton({
    super.key,
    required this.provider,
    required this.onPressed,
  });

  final RoomProvider provider;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: provider,
      builder: (context, _) {
        // 고정 폭을 두면 글자 배율이 큰 기기에서 문구가 잘립니다.
        return PlatformButton(
          label: '그룹 나가기'.localized,
          height: 44,
          expand: false,
          style: PlatformButtonStyle.secondary,
          // 응답 유실 뒤에는 leave intent를 유지하지만 요청 자체는 끝났습니다.
          // 그 상태까지 계속 spinner로 보이면 사용자가 재시도할 수 없습니다.
          loading: provider.isLeaving && provider.isLoading,
          onPressed: onPressed,
        );
      },
    );
  }
}
