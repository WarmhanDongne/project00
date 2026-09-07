import 'package:flutter/material.dart';
import 'package:game_kit/games/shared/widgets/tablet_game_settings_dialog.dart';
import 'package:game_contract/games/shared/models/game_room_context.dart';

/// 기존 게임 API를 유지하면서 공용 태블릿 설정 화면을 사용합니다.
class Setting extends StatelessWidget {
  const Setting({
    super.key,
    required this.provider,
    this.onRestartGame,
    this.onEndGame,
  });

  final GameRoomContext provider;
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
