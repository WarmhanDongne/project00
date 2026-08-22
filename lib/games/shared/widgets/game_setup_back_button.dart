import 'package:flutter/material.dart';

//=======================준비 화면 뒤로가기==============================
/// 게임 시작 전 **준비 화면**의 뒤로가기 버튼입니다.
///
/// 자리 배치(`PlayerLayoutEditor`)와 마피아 역할 배치가 같은 버튼을 씁니다.
/// 준비 화면마다 따로 만들면 위치·모양·누르는 동안의 표시가 조금씩 달라져,
/// 화면을 옮겨 다닐 때 같은 버튼이 아닌 것처럼 보입니다.
///
/// 누르는 동안에는 동그라미가 돌고 다시 눌리지 않습니다. 뒤로 가기는 서버에
/// 게임 선택 해제를 알리는 일이라 두 번 보내면 안 됩니다.
class GameSetupBackButton extends StatelessWidget {
  const GameSetupBackButton({
    super.key,
    required this.onPressed,
    required this.isBusy,
  });

  final VoidCallback onPressed;

  /// 뒤로 가기를 처리하는 중인지입니다.
  final bool isBusy;

  /// 버튼이 놓이는 줄의 높이입니다(자리 배치 화면과 같은 값).
  static const double rowHeight = 48;

  /// 줄 바깥 여백입니다(자리 배치 화면과 같은 값).
  static const EdgeInsets rowPadding = EdgeInsets.fromLTRB(16, 12, 16, 0);

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      tooltip: '뒤로가기',
      onPressed: isBusy ? null : onPressed,
      icon: isBusy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.arrow_back),
    );
  }
}
