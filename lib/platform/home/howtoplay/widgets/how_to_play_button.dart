import 'package:project00/platform/localization/platform_localizations.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:project00/platform/home/howtoplay/screens/how_to_play_route.dart';

//=======================플레이 방식 안내 열기 버튼==============================
// 홈(휴대폰·태블릿)의 헤더에 두는 아이콘입니다. 누르면 이 아이콘 자리에서
// 안내 화면이 원형으로 펼쳐집니다.

class HowToPlayButton extends StatelessWidget {
  const HowToPlayButton({
    super.key,
    this.compact = true,
    this.foreground = MosiColors.navy,
  });

  /// true면 아이콘만, false면 아이콘과 문구를 함께 보여 줍니다.
  final bool compact;

  /// 테두리와 아이콘 색입니다. 머리 바탕에 맞춰 바꿉니다.
  final Color foreground;

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
    return Semantics(
      button: true,
      label: context.l10n.howToPlay,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => _open(context),
        child: Container(
          height: 40,
          padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: foreground, width: 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.play_circle_outline, size: 20, color: foreground),
              if (!compact) ...[
                const SizedBox(width: 6),
                Text(
                  context.l10n.howToPlay,
                  style: MosiFonts.sans(
                    locale: Localizations.maybeLocaleOf(context),
                    size: 13,
                    weight: FontWeight.w700,
                    color: foreground,
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
