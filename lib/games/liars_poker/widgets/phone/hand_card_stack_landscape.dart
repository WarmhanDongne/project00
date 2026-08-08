import 'package:flutter/material.dart';
import 'package:project00/games/liars_poker/animations/phone_card_receive_animation.dart';
import 'package:project00/gen/assets.gen.dart';

class HandCardStackLandscape extends StatefulWidget {
  final List<AssetGenImage>? cards;
  final ValueChanged<int>? onCardSelected;

  const HandCardStackLandscape({super.key, this.cards, this.onCardSelected});

  @override
  State<HandCardStackLandscape> createState() => _HandCardStackLandscapeState();
}

class _HandCardStackLandscapeState extends State<HandCardStackLandscape> {
  int? _selectedIndex;
  late final List<AssetGenImage> _renderCards;
  // 초기 딜링 애니메이션 여부: true (진행), false (완료)
  bool _isDealing = true;

  // 가로 모드에 맞게 사이즈 및 간격 조정
  static const double _cardWidth = 140.0; // 세로 모드(169.0)보다 약간 축소
  static const double _spreadStepX = 115.0; // 카드가 일렬로 겹치도록 X축 간격 지정
  static const double _spreadStepY = 0.0; // 대각선이 아닌 일자 배치를 위해 0으로 설정
  static const double _selectedElevation = 20.0;

  @override
  void initState() {
    super.initState();
    // Null-safety 더미 데이터 처리
    _renderCards =
        widget.cards ??
        [
          Assets.games.liarsPoker.images.cards.whiteK,
          Assets.games.liarsPoker.images.cards.whiteQ,
          Assets.games.liarsPoker.images.cards.whiteQ,
          Assets.games.liarsPoker.images.cards.whiteA,
          Assets.games.liarsPoker.images.cards.whiteJoker,
        ];
  }

  @override
  Widget build(BuildContext context) {
    if (_isDealing) {
      return PhoneCardReceiveAnimation(
        frontCardAssets: _renderCards,
        cardWidth: _cardWidth,
        spreadStepX: _spreadStepX,
        spreadStepY: _spreadStepY, // 애니메이션 측에도 Y축 0 전달
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
        // 제약 조건에 따른 사이즈 계산 (가로 뷰포트 기준)
        final size = Size(
          constraints.hasBoundedWidth ? constraints.maxWidth : 600,
          constraints.hasBoundedHeight ? constraints.maxHeight : 400,
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
            children: List.generate(cardCount, (reverseIndex) {
              // 렌더링 순서만 역순으로 뒤집고, 진짜 데이터 인덱스(index)는 그대로 유지
              final index = cardCount - 1 - reverseIndex;

              final centeredIndex = index - (cardCount - 1) / 2;
              final isSelected = _selectedIndex == index;

              // 펼침 타겟 포지션 계산
              final baseLeft =
                  centerX + (centeredIndex * _spreadStepX) - (_cardWidth / 2);
              final baseTop =
                  centerY + (centeredIndex * _spreadStepY) - (cardHeight / 2);

              return AnimatedPositioned(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOutCubic,
                left: baseLeft,
                // 선택(Tap) 시 위로 튀어나오는 효과 적용
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
  final AssetGenImage asset;
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
        child: asset.image(
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}
