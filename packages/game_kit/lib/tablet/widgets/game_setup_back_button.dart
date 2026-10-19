// [game_setup_back_button.dart] 는 태블릿의 게임 설정 화면에서 공통으로 사용하는 뒤로가기 버튼이다.
//
// - [Package] : 게임 공통 기반
// - [Widget] : 게임 화면에서 반복 사용하는 공통 UI를 구성함
//
// 즉, 같은 표시와 조작 방식을 여러 화면에서 재사용하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'package:flutter/material.dart';
import 'package:game_kit/localization/game_locale.dart';

// ============================================================

//=======================준비 화면 뒤로가기==============================
/// 게임 시작 전 **준비 화면**의 뒤로가기 버튼입니다.
///
/// 자리 배치(`PlayerLayoutEditor`)와 마피아 역할 배치가 같은 버튼을 씁니다.
/// 준비 화면마다 따로 만들면 위치·모양·누르는 동안의 표시가 조금씩 달라져,
/// 화면을 옮겨 다닐 때 같은 버튼이 아닌 것처럼 보입니다.
///
/// 누른 뒤에도 화살표 모양을 유지하고 중복 입력만 막습니다. 실제 서버 선택
/// 해제는 로비 복귀 전환과 겹쳐 처리하므로 회전 로딩을 표시하지 않습니다.
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
      tooltip: '뒤로가기'.localized,
      onPressed: isBusy ? null : onPressed,
      icon: const Icon(Icons.arrow_back),
    );
  }
}
