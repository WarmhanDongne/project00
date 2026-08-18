import 'package:flutter/material.dart';
import 'package:project00/games/shared/widgets/tablet_game_settings_dialog.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';

/// 기존 게임 API를 유지하면서 공용 태블릿 설정 화면을 사용합니다.
class FinalCallTabletSetting extends StatelessWidget {
  const FinalCallTabletSetting({
    super.key,
    required this.provider,
    this.onRestartGame,
    this.onEndGame,
  });

  final RoomProvider provider;
  final VoidCallback? onRestartGame;
  final VoidCallback? onEndGame;

  @override
  Widget build(BuildContext context) {
    return TabletGameSettingsDialog(
      provider: provider,
      onRestartGame: onRestartGame,
      onEndGame: onEndGame,
    );
  }
}
