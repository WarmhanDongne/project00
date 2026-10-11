// [top_bar.dart] 휴대폰 상단에 내 프로필·차례·룰렛 단계와
// 규칙·나가기 버튼을 표시하는 상단바 파일이다.

// ========================[ import ]==========================
import 'package:flutter/material.dart';
import 'package:game_kit/phone/animations/control_entry_animation.dart';
import 'package:game_liars_poker/game_theme.dart';
import 'package:game_liars_poker/shared/widgets/noir_ui.dart';

// ============================================================

/// 내 얼굴, `이름 · 상태`, 룰렛 단계와 오른쪽 규칙·나가기 버튼입니다.
class PhoneGameTopBar extends StatelessWidget {
  const PhoneGameTopBar({
    super.key,
    required this.characterId,
    required this.nickname,
    required this.penaltyCount,
    required this.onTipPressedAt,
    required this.onOutPressedAt,
    this.statusLabel,
    this.statusColor = LiarsPokerColors.goldLight,
    this.eliminated = false,
    this.entryAnimation,
  });

  final String characterId;
  final String nickname;
  final int penaltyCount;
  final String? statusLabel;
  final Color statusColor;

  /// 탈락했으면 룰렛 단계 대신 상태 문구만 보여 줍니다.
  final bool eliminated;
  final Animation<double>? entryAnimation;
  final ValueChanged<Offset> onTipPressedAt;
  final ValueChanged<Offset> onOutPressedAt;

  @override
  Widget build(BuildContext context) {
    final status = statusLabel;
    final identity = Row(
      children: [
        NoirAvatar(
          characterId: characterId,
          size: 44,
          ringColor: eliminated ? LiarsPokerColors.dim : LiarsPokerColors.gold,
          ringWidth: 3,
          grayscale: eliminated,
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: nickname),
                      if (status != null) ...[
                        const TextSpan(text: ' · '),
                        TextSpan(
                          text: status,
                          style: TextStyle(color: statusColor),
                        ),
                      ],
                    ],
                  ),
                  maxLines: 1,
                  style: LiarsPokerFonts.text(
                    size: 16,
                    weight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ),
              if (!eliminated) ...[
                const SizedBox(height: 4),
                NoirRouletteStatus(
                  penaltyCount: penaltyCount,
                  dotSize: 10,
                  fontSize: 11,
                  prefix: '다음 룰렛',
                ),
              ],
            ],
          ),
        ),
      ],
    );
    final buttons = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        NoirIconButton(
          icon: Icons.question_mark_rounded,
          label: '게임 규칙 열기',
          onPressed: onTipPressedAt,
        ),
        const SizedBox(width: 8),
        NoirIconButton(
          icon: Icons.logout_rounded,
          label: '게임과 그룹 나가기',
          onPressed: onOutPressedAt,
        ),
      ],
    );
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          Expanded(child: _entry(0, identity)),
          const SizedBox(width: 10),
          _entry(1, buttons),
        ],
      ),
    );
  }

  Widget _entry(int index, Widget child) {
    final animation = entryAnimation;
    if (animation == null) return child;
    return ControlEntryAnimation(
      animation: animation,
      style: ControlEntryStyle.header,
      begin: index == 0 ? 0 : 0.06,
      end: index == 0 ? 0.76 : 0.86,
      child: child,
    );
  }
}
