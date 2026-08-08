import 'package:flutter/material.dart';
import 'package:project00/games/liars_poker/animations/phone_card_receive_animation.dart';

class HandCardStackPortrait extends StatefulWidget {
  final List<String>? cards;
  final ValueChanged<int>? onCardSelected;

  const HandCardStackPortrait({super.key, this.cards, this.onCardSelected});

  @override
  State<HandCardStackPortrait> createState() => _HandCardStackPortrait();
}

class _HandCardStackPortrait extends State<HandCardStackPortrait> {
  int? _selectedIndex;
  late final List<String> _renderCards;

  // 상태 변수: true일 경우 딜링 애니메이션 렌더링, false일 경우 인터랙티브 스택 렌더링
  bool _isDealing = true;

  // 렌더링 상수 정의 (PhoneCardReceiveAnimation과 동일한 파라미터 공유)
  static const double _cardWidth = 169.0;
  static const double _spreadStepX = 35.0;
  static const double _spreadStepY = 35.0;
  static const double _selectedElevation = 20.0;

  @override
  void initState() {
    super.initState();
    // Null-safety 처리 및 더미 에셋 바인딩
    _renderCards =
        widget.cards ??
        [
          'assets/games/liars_poker/images/cards/white K.png',
          'assets/games/liars_poker/images/cards/white Q.png',
          'assets/games/liars_poker/images/cards/white A.png',
          'assets/games/liars_poker/images/cards/white A.png',
          'assets/games/liars_poker/images/cards/white Joker.png',
        ];
  }

  @override
  Widget build(BuildContext context) {
    if (_isDealing) {
      return PhoneCardReceiveAnimation(
        frontCardAssets: _renderCards,
        cardWidth: _cardWidth,
        spreadStepX: _spreadStepX,
        spreadStepY: _spreadStepY,
        onCompleted: () {
          if (mounted) {
            setState(() {
              _isDealing = false;
            });
          }
        },
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // 부모 제약 조건에 따른 뷰포트 영역 계산
        final size = Size(
          constraints.hasBoundedWidth ? constraints.maxWidth : 400,
          constraints.hasBoundedHeight ? constraints.maxHeight : 600,
        );

        final centerX = size.width / 2;
        final centerY = size.height / 2;
        const cardAspectRatio = 512 / 350;
        final cardHeight = _cardWidth * cardAspectRatio;
        final cardCount = _renderCards.length;

        return SizedBox.fromSize(
          size: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: List.generate(cardCount, (index) {
              final centeredIndex = index - (cardCount - 1) / 2;
              final isSelected = _selectedIndex == index;

              // 좌표 동기화: 애니메이션 컴포넌트의 Spread Target Position 공식과 동일한 연산
              final baseLeft =
                  centerX + (centeredIndex * _spreadStepX) - (_cardWidth / 2);
              final baseTop =
                  centerY + (centeredIndex * _spreadStepY) - (cardHeight / 2);

              return AnimatedPositioned(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOutCubic,
                left: baseLeft,
                // 선택(Tap) 시 Y축 평행 이동을 통한 Elevate 효과 적용
                top: isSelected ? baseTop - _selectedElevation : baseTop,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    setState(() {
                      _selectedIndex = isSelected ? null : index;
                    });
                    if (widget.onCardSelected != null &&
                        _selectedIndex != null) {
                      widget.onCardSelected!(_selectedIndex!);
                    }
                  },
                  child: _StaticCardFace(
                    asset: _renderCards[index],
                    cardWidth: _cardWidth,
                    cardHeight: cardHeight,
                    isSelected: isSelected,
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

class _StaticCardFace extends StatelessWidget {
  final String asset;
  final double cardWidth;
  final double cardHeight;
  final bool isSelected;

  const _StaticCardFace({
    required this.asset,
    required this.cardWidth,
    required this.cardHeight,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: cardWidth,
      height: cardHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.0),
        border: isSelected
            ? Border.all(color: Colors.redAccent, width: 2.0)
            : null,
        boxShadow: [
          BoxShadow(
            color: const Color(0x66000000),
            blurRadius: isSelected ? 14.0 : 7.0,
            offset: isSelected ? const Offset(0, 8.0) : const Offset(0, 5.0),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.0),
        child: Image.asset(
          asset,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}
