// [game_overlay.dart] 는 파이널콜에서 사용하는 태블릿 게임의 세부 진행 화면을 구성하는 파일이다.
//
// - [Package] : 파이널콜
// - [TabletScreen] : 태블릿 게임의 세부 진행 화면을 구성함
//
// 즉, 전체 참가자가 게임 단계와 결과를 함께 확인하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'package:flutter/material.dart';
import 'package:game_final_call/tablet/widgets/rolebook.dart';
import 'package:game_kit/widgets/tablet_game_settings_dialog.dart';
import 'package:game_kit/widgets/tablet_game_menu_overlay.dart';
import 'package:game_final_call/gen/assets.gen.dart';
import 'package:game_kit/models/game_room_context.dart';
// ============================================================

/// Final Call 정보와 자산을 공통 태블릿 사이드바에 연결합니다.
class FinalCallTabletGameOverlay extends StatelessWidget {
  const FinalCallTabletGameOverlay({
    super.key,
    required this.provider,
    required this.onRestartGame,
    required this.onEndGame,
    required this.visible,
  });

  final GameRoomContext provider;
  final VoidCallback onRestartGame;
  final VoidCallback onEndGame;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final icons = Assets.games.finalCall.images.icons;
    return TabletGameMenuOverlay(
      visible: visible,
      roleIcon: icons.iconRole.image(fit: BoxFit.contain),
      settingIcon: icons.iconSetting.image(fit: BoxFit.contain),
      roleDialogBuilder: (_) => FinalCallTabletRoleBook(provider: provider),
      settingDialogBuilder: (_) => TabletGameSettingsDialog(
        provider: provider,
        onRestartGame: onRestartGame,
        onEndGame: onEndGame,
      ),
    );
  }
}
