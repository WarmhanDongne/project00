import 'package:flutter/material.dart';
import 'package:project00/games/shared/widgets/game_reconnect_screen.dart';

//=======================Shorebird 패치 화면==============================
/// Shorebird 패치를 받아 적용하는 동안 보여 주는 화면입니다.
///
/// `ShorebirdPatchGate`에서 새 패치를 받는 구간과 재시작 안내에
/// 연결해 사용합니다.
///
/// 재접속 화면([GameReconnectScreen])과 배경·움직임·문구 배치를 그대로 쓰고
/// **가운데 그림과 문구만** 다릅니다. 같은 골격을 두 번 그리면 한쪽만 고쳐져
/// 갈라지므로 재접속 화면을 감싸서 씁니다.
class ShorebirdPatchScreen extends StatelessWidget {
  const ShorebirdPatchScreen({
    super.key,
    this.title = '업데이트를 받는 중',
    this.message = '잠시만 기다려 주세요',
    this.buttonDelay = GameReconnectScreen.defaultHomeButtonDelay,
    this.buttonLabel = '나중에 하기',
    this.onSkip,
  });

  /// 가운데 그림입니다. 파일을 넣으면 자동으로 보입니다.
  static const String illustrationAsset =
      'assets/images/patch/game_update.webp';

  /// 가운데 큰 문구입니다.
  final String title;

  /// 그 아래 작은 문구입니다.
  final String message;

  /// 이 시간이 지나도 끝나지 않으면 기다림 표시가 버튼으로 바뀝니다.
  final Duration buttonDelay;

  /// 시간이 지난 뒤 나타나는 버튼 문구입니다.
  final String buttonLabel;

  /// 그 버튼을 눌렀을 때입니다. null이면 눌러도 아무 일도 하지 않습니다.
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    return GameReconnectScreen(
      title: title,
      message: message,
      illustrationAsset: illustrationAsset,
      homeButtonDelay: buttonDelay,
      homeLabel: buttonLabel,
      onHome: onSkip,
    );
  }
}
