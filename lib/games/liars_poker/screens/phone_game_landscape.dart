import 'package:flutter/material.dart';
import 'package:project00/games/liars_poker/widgets/phone/hand_card_stack_landscape.dart';
import 'package:project00/games/liars_poker/widgets/phone/top_bar_landscape.dart';

class PhoneGameLandscape extends StatefulWidget {
  const PhoneGameLandscape({super.key});

  @override
  State<PhoneGameLandscape> createState() => _PhoneGameLandscapeState();
}

class _PhoneGameLandscapeState extends State<PhoneGameLandscape> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. 배경 이미지
          Positioned.fill(
            child: Image.asset(
              'assets/games/liars_poker/images/background/phone_background.png',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
          ),

          // 2. 상단 UI (로고, 아이콘)
          // SafeArea를 고려하여 top과 좌우 패딩을 줍니다.
          Positioned(
            top: 20,
            left: 30,
            right: 30,
            child: SafeArea(
              child: TopBarLandscape(
                onTipPressed: () {
                  // 팁 버튼 액션
                },
                onSettingPressed: () {
                  // 설정 버튼 액션
                },
              ),
            ),
          ),

          // 3. 카드 덱 묶음 (좌측 중앙~하단 배치)
          // 가로로 펼쳐지도록 width를 넓게 잡아줍니다.
          Positioned(
            bottom: 30,
            left: 40,
            width: 450, // 카드 5장이 겹쳐서 펼쳐질 충분한 너비
            height: 250,
            child: HandCardStackLandscape(
              onCardSelected: (index) {
                debugPrint('선택된 카드 인덱스 : $index');
              },
            ),
          ),

          // 4. (추후 추가할 영역) 우측 Liar 버튼
          // Positioned(
          //   right: 40,
          //   bottom: 40,
          //   child: const LiarAccusation(),
          // ),
        ],
      ),
    );
  }
}
