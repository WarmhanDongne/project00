// [top_bar.dart] 는 파이널콜에서 사용하는 휴대폰 게임 화면에서 재사용하는 UI를 구성하는 파일이다.
//
// - [Package] : 파이널콜
// - [PhoneWidget] : 휴대폰 게임 화면에서 재사용하는 UI를 구성함
//
// 즉, 플레이어 입력과 상태 표시를 작은 책임으로 나눠 관리하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'package:flutter/material.dart';
import 'package:game_final_call/shared/providers/game_controller.dart';
import 'package:game_final_call/game_copy.dart';
import 'package:game_final_call/shared/models/game_models.dart';
import 'package:game_kit/phone/widgets/rule_dialog.dart';
import 'package:game_kit/phone/widgets/ripple_dialog.dart';
import 'package:game_final_call/game_theme.dart';
import 'package:game_final_call/phone/widgets/turn_timer.dart';
import 'package:game_final_call/shared/widgets/party_pop.dart';

// ============================================================

/// 상단바가 차지하는 높이입니다(시안 58).
///
/// 상단바는 공용 셸이 화면 위에 겹쳐 그리므로, 게임 화면은 같은 높이를 비워
/// 두어야 카드·조작부 위치가 달라지지 않습니다.
const double finalCallPhoneTopBarHeight = 58;

/// Final Call 휴대폰 상단바입니다(Party Pop 시안).
///
/// 왼쪽은 내 얼굴·이름·하트, 가운데는 지금 해야 할 일과 남은 시간, 오른쪽은
/// 규칙·나가기 버튼입니다. 표시 시점과 등장 연출은 공용 셸이 제어합니다.
class FinalCallPhoneTopBar extends StatelessWidget {
  const FinalCallPhoneTopBar({
    super.key,
    required this.controller,
    required this.onExitRoom,
    required this.onRulesPressed,
    this.visibleCallerUid,
  });

  final FinalCallController controller;
  final VoidCallback onExitRoom;
  final ValueChanged<Offset?> onRulesPressed;

  /// CALL 안내를 강조해서 보여 줄 선언자입니다.
  final String? visibleCallerUid;

  @override
  Widget build(BuildContext context) {
    final me = controller.players[controller.uid];
    return SizedBox(
      height: finalCallPhoneTopBarHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            if (me != null) _ProfileChip(player: me),
            const SizedBox(width: 12),
            Expanded(
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _StatusPill(
                    controller: controller,
                    visibleCallerUid: visibleCallerUid,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Builder(
              builder: (buttonContext) => FinalCallPopIconButton(
                semanticLabel: '게임 규칙 열기',
                onPressed: () {
                  final box = buttonContext.findRenderObject() as RenderBox?;
                  onRulesPressed(
                    box?.localToGlobal(box.size.center(Offset.zero)),
                  );
                },
                child: Text('?', style: finalCallPopText(20, height: 1)),
              ),
            ),
            const SizedBox(width: 12),
            FinalCallPopIconButton(
              semanticLabel: '게임과 그룹 나가기',
              onPressed: onExitRoom,
              child: const FinalCallExitGlyph(),
            ),
          ],
        ),
      ),
    );
  }
}

/// 내 얼굴·이름·하트입니다.
class _ProfileChip extends StatelessWidget {
  const _ProfileChip({required this.player});

  final FinalCallPlayer player;

  @override
  Widget build(BuildContext context) {
    final color = finalCallTeamColor(player.team);
    final lives = player.status == 'eliminated' ? 0 : player.lives;
    return FinalCallPopBox(
      radius: 14,
      borderWidth: 3,
      shadowDepth: 3,
      padding: const EdgeInsets.fromLTRB(3, 3, 10, 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FinalCallPopAvatar(characterId: player.characterId, color: color),
          const SizedBox(width: 6),
          // 닉네임(최대 8자)을 자르지 않고 칸에 맞춰 줄입니다.
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 124),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                player.nickname,
                maxLines: 1,
                style: finalCallPopText(15),
              ),
            ),
          ),
          const SizedBox(width: 6),
          for (var index = 0; index < 3; index++)
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: FinalCallPopHeart(
                key: index < lives
                    ? ValueKey('final-call-${player.team.name}-heart-$index')
                    : null,
                color: color,
                filled: index < lives,
              ),
            ),
        ],
      ),
    );
  }
}

/// 지금 해야 할 일을 알려 주는 가운데 알약입니다.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.controller, this.visibleCallerUid});

  final FinalCallController controller;
  final String? visibleCallerUid;

  @override
  Widget build(BuildContext context) {
    final game = controller;
    if (game.isEliminated || game.isFinished || game.status != 'playing') {
      return const SizedBox.shrink();
    }
    final deadline = game.turnDeadlineAt;
    final timer = deadline == null || game.phase == 'dealing'
        ? null
        : FinalCallTimer(
            key: ValueKey(deadline),
            deadline: deadline,
            withTickSound: game.isMyTurn,
            dark: game.isMyTurn,
          );
    final caller = game.players[game.callerUid];
    final callerName = caller == null
        ? null
        : caller.uid == game.uid
        ? FinalCallCopy.me
        : caller.nickname;

    // CALL 이후 최종 조합 제출: 노란 알약에 선언자를 붉게 강조합니다.
    if (game.isFinalSubmitPhase) {
      return _pill(
        color: FinalCallColors.yellow,
        children: [
          if (callerName != null)
            Text(
              FinalCallCopy.callBy(callerName),
              style: finalCallPopText(16, color: const Color(0xFFD93A40)),
            ),
          Text(FinalCallCopy.submitFinal, style: finalCallPopText(16)),
          ?timer,
        ],
      );
    }

    if (game.isMyTurn) {
      final label = game.pendingDraw != null
          ? FinalCallCopy.pickOrDiscard
          : game.phase == 'finalTurns'
          ? FinalCallCopy.lastSwap
          : FinalCallCopy.myTurn;
      return _pill(
        color: FinalCallColors.violet,
        children: [
          Text(
            label,
            style: finalCallPopText(
              17,
              color: Colors.white,
              shadows: finalCallPopOutline(),
            ),
          ),
          ?timer,
        ],
      );
    }

    final turnPlayer = game.turnPlayer;
    final showCall = visibleCallerUid != null && callerName != null;
    return _pill(
      color: showCall ? FinalCallColors.yellow : Colors.white,
      children: [
        if (showCall)
          Text(
            FinalCallCopy.callBy(callerName),
            style: finalCallPopText(16, color: const Color(0xFFD93A40)),
          ),
        if (turnPlayer != null) ...[
          FinalCallPopAvatar(
            characterId: turnPlayer.characterId,
            color: finalCallTeamColor(turnPlayer.team),
            size: 30,
          ),
          Text(
            FinalCallCopy.turnOf(turnPlayer.nickname),
            style: finalCallPopText(17),
          ),
        ],
        ?timer,
      ],
    );
  }

  Widget _pill({required Color color, required List<Widget> children}) {
    return FinalCallPopBox(
      color: color,
      radius: 14,
      borderWidth: 3,
      shadowDepth: 3,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0) const SizedBox(width: 10),
            children[index],
          ],
        ],
      ),
    );
  }
}

/// Final Call 규칙 다이얼로그를 엽니다.
void showFinalCallRules(BuildContext context, [Offset? origin]) {
  final screenSize = MediaQuery.sizeOf(context);
  showPhoneRippleDialog<void>(
    context: context,
    origin: origin ?? Offset(screenSize.width - 82, 28),
    builder: (_) => const PhoneGameRuleDialog(
      title: 'FINAL CALL',
      rules: FinalCallCopy.phoneRules,
      surfaceColor: Color.fromARGB(255, 0, 0, 0),
      foregroundColor: Color.fromARGB(255, 255, 255, 255),
      showSurface: false,
      dismissOnAnyTap: true,
    ),
  );
}
