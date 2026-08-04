import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:project00/platform/home/gamelist/models/game_info.dart';

class PhoneGameCard extends StatelessWidget {
  // 게임 포스터와 설명을 한 쌍으로 묶어 위젯으로 만듦.

  final GameInfo gameInfo;
  const PhoneGameCard({super.key, required this.gameInfo});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            SizedBox(width: 16.w),
            ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: gameInfo.imageUrl.isEmpty
                  ? Container(
                      width: 115,
                      height: 150,
                      color: Colors.grey.shade300,
                      alignment: Alignment.center,
                      child: const Icon(Icons.image_outlined),
                    )
                  : Image.network(
                      gameInfo.imageUrl,
                      width: 115,
                      height: 150,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 115,
                          height: 150,
                          color: Colors.grey.shade300,
                          alignment: Alignment.center,
                          child: const Icon(Icons.broken_image_outlined),
                        );
                      },
                    ),
            ),
            SizedBox(width: 20),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,

                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    gameInfo.name, // 텍스트 대신 DTO로 받은 데이터를 디스플레이
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
                    gameInfo.description,
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
