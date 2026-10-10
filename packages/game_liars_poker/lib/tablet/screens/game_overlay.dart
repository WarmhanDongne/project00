// [game_overlay.dart] 게임 중 태블릿 위에
// 현재 기준 카드와 규칙·설정 메뉴를 겹쳐 표시하는 파일이다.

// ========================[ import ]==========================
import 'package:flutter/material.dart';
import 'package:game_liars_poker/shared/widgets/noir_ui.dart';
import 'package:game_liars_poker/tablet/widgets/rulebook.dart';
import 'package:game_kit/tablet/widgets/game_settings_dialog.dart';
import 'package:game_liars_poker/tablet/providers/game_stage.dart';
import 'package:game_kit/tablet/widgets/game_menu_overlay.dart';
import 'package:game_kit/models/game_room_context.dart';

// ============================================================

/// 게임 중 사용할 규칙/설정 메뉴와 현재 테이블 라벨을 화면 위에 배치합니다.
class LiarsPokerTabletGameOverlay extends StatelessWidget {
  const LiarsPokerTabletGameOverlay({
    super.key,
    required this.provider,
    required this.stage,
    required this.onRestartGame,
    required this.onEndGame,
  });

  final GameRoomContext provider;
  final LiarsPokerTabletStage stage;

  final VoidCallback onRestartGame;
  final VoidCallback onEndGame;

  @override
  Widget build(BuildContext context) {
    // 분배·결과처럼 전체 화면 연출이 필요한 단계에서는 사이드바를 숨깁니다.
    // 카드 배분 전과 배분 중에는 숨기고, RoundStartReveal이 테이블과 잔여
    // 카드를 띄우기 시작하는 roundStarting부터 함께 등장시킵니다.
    if (stage == LiarsPokerTabletStage.waiting ||
        stage == LiarsPokerTabletStage.dealing ||
        stage == LiarsPokerTabletStage.result ||
        stage == LiarsPokerTabletStage.finished) {
      return const SizedBox.expand();
    }

    // 오른쪽 위 규칙·설정 버튼입니다. 기준 카드는 테이블 원의 표식으로
    // 네 방향 모두에서 읽히므로 따로 라벨을 두지 않습니다.
    return TabletGameMenuOverlay(
      visible: true,
      roleIcon: const NoirRingGlyph(icon: Icons.question_mark_rounded),
      settingIcon: const NoirRingGlyph(icon: Icons.settings_rounded),
      roleDialogBuilder: (_) => LiarsPokerTabletRulebook(provider: provider),
      settingDialogBuilder: (_) => TabletGameSettingsDialog(
        provider: provider,
        onRestartGame: onRestartGame,
        onEndGame: onEndGame,
      ),
    );
  }
}
