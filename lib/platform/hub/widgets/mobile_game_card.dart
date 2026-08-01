import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:project00/platform/hub/dto/game_info.dart';

class MobileGameCard extends StatelessWidget {
  // 게임 포스터와 설명을 한 쌍으로 묶어 위젯으로 만듦.

  final GameInfo gameInfo;
  const MobileGameCard({super.key, required this.gameInfo});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            SizedBox(width: 16.w),
            ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: Image.network(
                "https://picsum.photos/200/300",
                width: 115,
                height: 150,
                fit: BoxFit.cover, // 지정한 비율에 이미자가 맞도록 설정
              ),
            ),
            SizedBox(width: 20),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,

                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    gameInfo.title, // 텍스트 대신 DTO로 받은 데이터를 디스플레이
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight(400)),
                    textScaler: TextScaler.noScaling,
                  ),
                  Text(
                    '${gameInfo.playTime}m',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight(400)),
                  ),
                  Text(
                    '${gameInfo.minPlayers} ~ ${gameInfo.maxPlayers}인',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight(400)),
                  ),
                  Text(
                    gameInfo.genres.join(', '),
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight(400)),
                  ),
                  Text(
                    gameInfo.shortDescription,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight(400)),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 10),
      ],
    );
  }
}
