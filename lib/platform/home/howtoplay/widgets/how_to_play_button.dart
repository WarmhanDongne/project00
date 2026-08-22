import 'dart:async';

import 'package:flutter/material.dart';
import 'package:project00/platform/home/howtoplay/screens/how_to_play_route.dart';
import 'package:project00/platform/theme/platform_theme.dart';

//=======================플레이 방식 안내 열기 버튼==============================
// 홈(휴대폰·태블릿)의 헤더에 두는 아이콘입니다. 누르면 이 아이콘 자리에서
// 안내 화면이 원형으로 펼쳐집니다.

class HowToPlayButton extends StatelessWidget {
  const HowToPlayButton({super.key, this.compact = true});

  /// true면 아이콘만, false면 아이콘과 문구를 함께 보여 줍니다.
  final bool compact;

  void _open(BuildContext context) {
    // 눌린 아이콘의 화면상 중심에서 연출이 시작되도록 좌표를 넘깁니다.
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null || !box.hasSize
        ? null
        : box.localToGlobal(box.size.center(Offset.zero));
    unawaited(openHowToPlay(context, origin: origin));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    return Material(
      color: colors.primarySoft,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => _open(context),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 9 : 14,
            vertical: 9,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.play_circle_outline,
                size: compact ? 22 : 20,
                color: colors.primary,
              ),
              if (!compact) ...[
                const SizedBox(width: 6),
                Text(
                  '플레이 방법',
                  style: TextStyle(
                    color: colors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
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
