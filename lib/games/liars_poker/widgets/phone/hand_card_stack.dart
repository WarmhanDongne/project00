import 'package:flutter/material.dart';

class HandCardStack extends StatefulWidget {
  // 상단에서 데이터를 주입받을 수 있도록 Nullable 리스트로 선언
  final List<String>? cards;
  final ValueChanged<int>? onCardSelected;

  const HandCardStack({
    super.key,
    this.cards, // required 제거
    this.onCardSelected,
  });

  @override
  State<HandCardStack> createState() => _HandCardStackState();
}

class _HandCardStackState extends State<HandCardStack> {
  int? _selectedIndex;
  late final List<String> _renderCards; // 실제 렌더링 파이프라인에 들어갈 배열

  @override
  void initState() {
    super.initState();
    // 위젯 마운트 시 데이터 바인딩: 부모가 준 데이터가 있으면 사용, 없으면 내부 더미 데이터 할당
    _renderCards = widget.cards ?? ['K', 'Q', 'A', 'A', 'Joker'];
  }

  @override
  Widget build(BuildContext context) {
    const double cardSpacing = 35.0;
    const double cardWidth = 110.0;
    const double cardHeight = 160.0;
    const double selectedElevationY = 20.0;

    // 전체 렌더링 컨테이너 너비 계산
    final double stackWidth =
        cardWidth + (_renderCards.length - 1) * cardSpacing;

    return SizedBox(
      width: stackWidth,
      height: cardHeight + selectedElevationY,
      child: Stack(
        clipBehavior: Clip.none,
        children: List.generate(_renderCards.length, (index) {
          final bool isSelected = _selectedIndex == index;

          return Positioned(
            left: index * cardSpacing,
            top: isSelected ? 0 : selectedElevationY,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedIndex = isSelected ? null : index;
                });

                if (widget.onCardSelected != null && _selectedIndex != null) {
                  widget.onCardSelected!(_selectedIndex!);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(
                  milliseconds: 150,
                ), // 하드웨어 프레임 드랍 방지를 위해 짧게 설정
                width: cardWidth,
                height: cardHeight,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(
                    color: isSelected ? Colors.red : Colors.grey.shade400,
                    width: isSelected ? 2.0 : 1.0,
                  ),
                ),
                alignment: Alignment.topLeft,
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  _renderCards[index], // 할당된 메모리 데이터 참조
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
