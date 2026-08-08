import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:project00/games/liars_poker/widgets/phone/top_control_bar.dart';
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
            child: TopControlBar(
              leadingWidget: Assets.games.liarsPoker.images.phone.kingTable.svg(
                height: 24.h,
              ),
            ),
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
