import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:project00/games/liars_poker/widgets/phone/hand_card_stack_portrait.dart'; // HandCardStack import 추가
import 'package:project00/games/liars_poker/widgets/phone/liar_accusation.dart';
import 'package:project00/games/liars_poker/widgets/phone/top_bar_portrait.dart';
import 'package:project00/gen/assets.gen.dart';
// import 'package:project00/games/liars_poker/models/player_layout_model.dart';

class PhoneGamePortrait extends StatefulWidget {
  const PhoneGamePortrait({
    super.key,
    //required this.playerLayout
  });
  //final PlayerLayoutModel playerLayout;

  @override
  State<PhoneGamePortrait> createState() => _PhoneGamePortrait();
}

class _PhoneGamePortrait extends State<PhoneGamePortrait> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 배경 이미지
          Positioned.fill(
            child: Image.asset(
              'assets/games/liars_poker/images/background/background.png',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
          ),
          // 상단 바
          Positioned(
            top: 50.h,
            left: 20.w,
            right: 20.w,
            child: TopBarPortrait(
              leadingWidget: Assets.games.liarsPoker.images.phone.kingTable
                  .image(height: 24.h, filterQuality: FilterQuality.high),
            ),
          ),
          // Liar 고발 버튼
          Positioned(
            top: 640.h,
            left: 20.w,
            right: 0.w,
            child: const LiarAccusation(),
          ),
          // 내 카드 스택 (애니메이션 및 인터랙션 컨테이너 적용)
          Positioned(
            top: 212.h,
            left: 0,
            right: 0,
            height: 350
                .h, // LayoutBuilder가 뷰포트를 계산할 수 있도록 높이 제약 조건(Bounded Height) 제공
            child: HandCardStackPortrait(
              onCardSelected: (index) {
                // 비즈니스 로직 연동 (예: 서버로 선택한 카드 정보 전송)
                debugPrint('선택된 카드 인덱스: $index');
              },
            ),
          ),
        ],
      ),
    );
  }
}
