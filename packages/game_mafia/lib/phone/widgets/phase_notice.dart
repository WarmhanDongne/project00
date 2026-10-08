import 'package:flutter/material.dart';
import 'package:game_mafia/game_theme.dart';
import 'package:game_mafia/shared/widgets/noir.dart';

/// 중간 단계 안내. 배경과 상단바는 board에 남기고 내용만 바꿉니다.
///
/// Noir 시안의 포스터 제목처럼 크게 찍고, 아래에 가는 놋쇠 선을 긋습니다.
class MafiaPhonePhaseNotice extends StatelessWidget {
  const MafiaPhonePhaseNotice({
    super.key,
    required this.message,
    this.detail,
    this.dark = false,
  });

  final String message;
  final String? detail;

  /// 먹색 바탕 위인지입니다. 글자를 종이색으로 바꿉니다.
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final color = dark ? MafiaColors.noirPaper : MafiaColors.noirInk;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 520),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) => Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 14 * (1 - value)),
              child: child,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message,
                textAlign: TextAlign.center,
                style: mafiaNoirDisplay(34, color: color),
              ),
              const SizedBox(height: 12),
              Container(width: 160, height: 3, color: MafiaColors.noirBrass),
              if (detail != null) ...[
                const SizedBox(height: 16),
                Text(
                  detail!,
                  textAlign: TextAlign.center,
                  style: mafiaNoirBody(
                    15,
                    color: dark ? MafiaColors.noirDust : MafiaColors.noirUmber,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
