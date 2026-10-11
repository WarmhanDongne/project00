// [game_overlay.dart] 는 파이널콜에서 사용하는 태블릿 게임의 세부 진행 화면을 구성하는 파일이다.
//
// - [Package] : 파이널콜
// - [TabletScreen] : 태블릿 게임의 세부 진행 화면을 구성함
//
// 즉, 전체 참가자가 게임 단계와 결과를 함께 확인하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'package:flutter/material.dart';
import 'package:game_final_call/tablet/widgets/rulebook.dart';
import 'package:game_kit/tablet/widgets/game_settings_dialog.dart';
import 'package:game_kit/tablet/widgets/game_menu_overlay.dart';
import 'package:game_final_call/game_theme.dart';
import 'package:game_final_call/shared/widgets/party_pop.dart';
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
    return TabletGameMenuOverlay(
      visible: visible,
      // 휴대폰 상단바와 같은 Party Pop 원형 버튼 모양입니다.
      roleIcon: const _MenuGlyph(child: _QuestionMark()),
      settingIcon: const _MenuGlyph(
        child: Icon(Icons.settings_rounded, color: FinalCallColors.ink),
      ),
      roleDialogBuilder: (_) => FinalCallTabletRoleBook(provider: provider),
      settingDialogBuilder: (_) => TabletGameSettingsDialog(
        provider: provider,
        onRestartGame: onRestartGame,
        onEndGame: onEndGame,
      ),
    );
  }
}

/// 흰 바탕·남색 테두리의 원형 메뉴 아이콘입니다.
class _MenuGlyph extends StatelessWidget {
  const _MenuGlyph({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest.shortestSide;
      return Padding(
        padding: EdgeInsets.only(bottom: size * .08),
        child: FinalCallPopBox(
          radius: size,
          borderWidth: size * .07,
          shadowDepth: size * .07,
          child: Center(
            child: FractionallySizedBox(
              widthFactor: .52,
              heightFactor: .52,
              child: FittedBox(child: child),
            ),
          ),
        ),
      );
    },
  );
}

class _QuestionMark extends StatelessWidget {
  const _QuestionMark();

  @override
  Widget build(BuildContext context) =>
      Text('?', style: finalCallPopText(24, height: 1));
}
