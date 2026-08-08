import 'package:flutter/material.dart';
import 'package:project00/games/liars_poker/widgets/phone/hand_card_stack_landscape.dart';
import 'package:project00/games/liars_poker/widgets/phone/top_bar_landscape.dart';
import 'package:project00/games/liars_poker/widgets/phone/liar_accusation.dart'; // 기존 위젯 그대로 import

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
          Positioned(
            top: 20,
            left: 30,
            right: 30,
            child: SafeArea(
              child: TopBarLandscape(
                onTipPressed: () {
                  debugPrint('팁 버튼 눌림');
                },
                onSettingPressed: () {
                  debugPrint('설정 버튼 눌림');
                },
              ),
            ),
          ),

          // 3. 카드 덱 묶음 (좌측 배치)
          Positioned(
            bottom: 30,
            left: 40,
            width: 450,
            height: 250,
            child: HandCardStackLandscape(
              onCardSelected: (index) {
                debugPrint('선택된 카드 인덱스 : $index');
              },
            ),
          ),

          // 4. 기존 Liar 버튼 재사용 (우측 하단 배치)
          Positioned(
            right: 40,
            bottom: 60, // 카드 덱과 비슷한 높이에 위치하도록 조정
            child: LiarAccusation(
              width: 220, // 가로 모드용 고정 너비 주입 (ScreenUtil 무시됨)
              height: 145, // 비율에 맞춘 높이 주입
              onAccuse: () {
                debugPrint('LIAR! 버튼 눌림');
              },
            ),
          ),
        ],
      ),
    );
  }
}
