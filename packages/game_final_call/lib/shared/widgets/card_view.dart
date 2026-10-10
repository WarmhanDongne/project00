// [card_view.dart] 는 파이널콜에서 사용하는 게임 화면에서 재사용하는 UI를 구성하는 파일이다.
//
// - [Package] : 파이널콜
// - [Widget] : 게임 화면에서 재사용하는 UI를 구성함
//
// 즉, 여러 화면에서 같은 표시와 동작을 중복 없이 사용하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:game_final_call/game_theme.dart';
import 'package:game_final_call/shared/widgets/party_pop.dart';
import 'package:game_final_call/shared/models/game_models.dart';

// ============================================================

/// Final Call 앞면 카드 원본(700 × 1026)의 높이/너비 비율입니다.
const double finalCallCardHeightRatio = 1026 / 700;

/// Party Pop 시안의 카드입니다. 색으로 꽉 채운 면 위에 큰 숫자를 둡니다.
///
/// 크기 비율은 기존 카드 그림과 같아 배치 계산은 그대로 씁니다.
class FinalCallCardView extends StatelessWidget {
  const FinalCallCardView({
    super.key,
    this.card,
    this.faceDown = false,
    this.width = 92,
    this.selected = false,
  });

  final FinalCallCard? card;
  final bool faceDown;
  final double width;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final height = width * finalCallCardHeightRatio;
    final face = faceDown || card == null
        ? FinalCallCardBack(width: width)
        : FinalCallCardFace(card: card!, width: width);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: width,
      height: height,
      transform: Matrix4.translationValues(0, selected ? -12 : 0, 0),
      child: face,
    );
  }
}

/// 시안 104px 카드를 기준으로 테두리·모서리·그림자를 비례해서 줄입니다.
double _cardUnit(double width) => width / 104;

BoxDecoration _cardDecoration(Color color, double width, {double? depth}) {
  final unit = _cardUnit(width);
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(16 * unit),
    border: Border.all(
      color: FinalCallColors.ink,
      width: math.max(1.5, 4 * unit),
    ),
    boxShadow: [
      BoxShadow(
        color: FinalCallColors.ink,
        offset: Offset(0, depth ?? math.max(2, 6 * unit)),
      ),
    ],
  );
}

/// 카드 앞면(색 + 숫자)입니다.
class FinalCallCardFace extends StatelessWidget {
  const FinalCallCardFace({super.key, required this.card, required this.width});

  final FinalCallCard card;
  final double width;

  @override
  Widget build(BuildContext context) {
    final unit = _cardUnit(width);
    final yellow = card.color == 'yellow';
    return Semantics(
      label: '${finalCallCardColorLabel(card.color)} ${card.value}',
      excludeSemantics: true,
      child: Container(
        width: width,
        height: width * finalCallCardHeightRatio,
        alignment: Alignment.center,
        decoration: _cardDecoration(finalCallCardColor(card.color), width),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '${card.value}',
            style: finalCallPopText(
              (card.value >= 10 ? 62 : 76) * unit,
              color: yellow ? FinalCallColors.ink : Colors.white,
              height: 1,
              shadows: yellow ? null : finalCallPopOutline(3 * unit),
            ),
          ),
        ),
      ),
    );
  }
}

/// 카드 뒷면(보라 + 노란 물음표 동전)입니다.
class FinalCallCardBack extends StatelessWidget {
  const FinalCallCardBack({super.key, required this.width, this.radius});

  final double width;

  /// 공용 분배 연출처럼 바깥 상자의 모서리에 맞춰야 할 때 씁니다.
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final unit = _cardUnit(width);
    final coin = 44 * unit;
    final decoration = _cardDecoration(FinalCallColors.violet, width);
    return Container(
      width: width,
      height: width * finalCallCardHeightRatio,
      alignment: Alignment.center,
      decoration: radius == null
          ? decoration
          : decoration.copyWith(borderRadius: BorderRadius.circular(radius!)),
      child: Container(
        width: coin,
        height: coin,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: FinalCallColors.yellow,
          shape: BoxShape.circle,
          border: Border.all(
            color: FinalCallColors.ink,
            width: math.max(1.2, 3 * unit),
          ),
        ),
        child: Text('?', style: finalCallPopText(coin * 0.55, height: 1)),
      ),
    );
  }
}
