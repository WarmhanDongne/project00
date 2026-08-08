import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:project00/games/liars_poker/widgets/phone/liar_accusation.dart';
import 'package:project00/games/liars_poker/widgets/phone/top_bar.dart';
import 'package:project00/gen/assets.gen.dart';
// import 'package:project00/games/liars_poker/models/player_layout_model.dart';

class PhoneGame extends StatefulWidget {
  const PhoneGame({
    super.key,
    //required this.playerLayout
  });

  //final PlayerLayoutModel playerLayout;

  @override
  State<PhoneGame> createState() => _PhoneGameState();
}

class _PhoneGameState extends State<PhoneGame> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/games/liars_poker/images/background/phone_background.png',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
          ),
          Positioned(
            top: 50.h,
            left: 20.w,
            right: 20.w,
            child: TopBar(
              // .svg() 대신 .image()를 사용하며, 화질 저하를 막기 위해 filterQuality를 추가합니다.
              leadingWidget: Assets.games.liarsPoker.images.phone.kingTable
                  .image(height: 24.h, filterQuality: FilterQuality.high),
            ),
          ),
          Positioned(
            top: 640.h,
            left: 20.w,
            right: 0.w,
            child: LiarAccusation(),
          ),

          // hand_card(손패) 렌더링 부분
          // const Positioned(
          //   bottom: 40,
          //   left: 0,
          //   right: 0,
          //   child: Center(child: HandCardStack()),
          // ),
        ],
      ),
    );
  }
}
