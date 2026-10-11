// [table_info.dart] 휴대폰에서 이번 라운드의 기준 카드와
// 남은 시간(또는 지금 차례인 사람)을 한 줄로 보여 주는 파일이다.

// ========================[ import ]==========================
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:game_liars_poker/game_assets.dart';
import 'package:game_liars_poker/game_theme.dart';
import 'package:game_liars_poker/gen/assets.gen.dart';
import 'package:game_liars_poker/shared/providers/game_controller.dart';
import 'package:game_liars_poker/shared/widgets/noir_ui.dart';

// ============================================================

/// 기준 카드 앞면 그림입니다.
GameImage liarsPokerTableCardAsset(String cardValue) {
  final cards = Assets.games.liarsPoker.images.cards;
  return switch (cardValue.toUpperCase()) {
    'A' => cards.whiteA.game,
    'Q' => cards.whiteQ.game,
    _ => cards.whiteK.game,
  };
}

/// 금색으로 빛나는 기준 카드와 `ACE'S TABLE` 이름입니다.
class PhoneTableCard extends StatelessWidget {
  const PhoneTableCard({
    super.key,
    required this.cardValue,
    this.cardWidth = 76,
  });

  final String cardValue;
  final double cardWidth;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '테이블 카드 ${cardValue.toUpperCase()}',
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.rotate(
          angle: -4 * math.pi / 180,
          child: Container(
            width: cardWidth,
            height: cardWidth * 1.46,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: LiarsPokerColors.ivory,
              borderRadius: BorderRadius.circular(cardWidth * .09),
              boxShadow: [
                const BoxShadow(color: LiarsPokerColors.gold, spreadRadius: 3),
                BoxShadow(
                  color: LiarsPokerColors.gold.withValues(alpha: .35),
                  blurRadius: 26,
                  spreadRadius: 3,
                ),
                const BoxShadow(
                  color: Color(0x80000000),
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: liarsPokerTableCardAsset(cardValue).image(fit: BoxFit.cover),
          ),
        ),
        SizedBox(height: cardWidth * .13),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            liarsPokerTableTitle(cardValue),
            maxLines: 1,
            style: LiarsPokerFonts.western(
              size: cardWidth * .26,
              color: LiarsPokerColors.goldLight,
              shadows: const [
                Shadow(
                  color: LiarsPokerColors.goldShadow,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

/// 내 차례가 아닐 때 타이머 자리에 지금 고르는 사람을 보여 줍니다.
class PhoneTurnBadge extends StatelessWidget {
  const PhoneTurnBadge({super.key, required this.player, this.size = 128});

  final PhoneGamePlayer? player;
  final double size;

  @override
  Widget build(BuildContext context) {
    final current = player;
    if (current == null) return SizedBox.square(dimension: size);
    return Semantics(
      label: '${current.nickname} 차례',
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            NoirAvatar(
              characterId: current.characterId,
              size: size * .82,
              ringColor: LiarsPokerColors.gold,
              ringWidth: size * .045,
              glowColor: LiarsPokerColors.gold.withValues(alpha: .3),
            ),
            Positioned(
              bottom: 0,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: size * .09,
                  vertical: size * .02,
                ),
                decoration: BoxDecoration(
                  color: LiarsPokerColors.gold,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: LiarsPokerColors.night, width: 2),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${current.nickname} 차례',
                    maxLines: 1,
                    style: LiarsPokerFonts.text(
                      size: size * .1,
                      weight: FontWeight.w700,
                      color: LiarsPokerColors.night,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
