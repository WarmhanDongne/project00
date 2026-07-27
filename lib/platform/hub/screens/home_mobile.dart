import 'package:flutter/material.dart';

class HomeMobile extends StatefulWidget {
  const HomeMobile({super.key});

  @override
  State<HomeMobile> createState() => _HomeMobileState();
}

class _HomeMobileState extends State<HomeMobile> {
  List<GameInfo> dumgames = [
    GameInfo(
      title: "a",
      playTime: 'b',
      userCount: 'c',
      gameGenre: 'd',
      shortExplain: 'e',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),

        child: Column(
          children: [
            SizedBox(height: 10),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  // 그룹 참여
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.black,
                    backgroundColor: Colors.grey[300],
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40.0,
                      vertical: 10.0,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5.0),
                    ),
                  ),
                  onPressed: () {
                    print("그룹에 참여하기"); // 나중에 클릭 시 그룹 참여하기 카메라 큐알 페이지로 넘기기
                  },
                  child: Text(
                    "그룹 참여",
                    style: TextStyle(
                      fontSize: 20.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                Ink(
                  width: 50,
                  height: 50,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    image: DecorationImage(
                      image: NetworkImage("https://picsum.photos/600/400"),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: InkWell(
                    customBorder: CircleBorder(),
                    onTap: () {
                      print('click');
                    },
                  ),
                ),
              ],
            ),
            Column(
              // 보유 중인 게임
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                SizedBox(height: 20),
                Text(
                  "보유 중인 게임",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 10),
              ],
            ),
            MobileGameCard(gameInfo: dumgames[0]),
            // SizedBox(height: 10),
            // MobileGameCard(),
            // SizedBox(height: 10),
            // MobileGameCard(),
            // SizedBox(height: 10),
            // MobileGameCard(),
          ],
        ),
      ),
    );
  }
}

class MobileGameCard extends StatelessWidget {
  // 게임 포스터와 설명을 한 쌍으로 묶어 위젯으로 만듦.

  final GameInfo gameInfo;
  const MobileGameCard({super.key, required this.gameInfo});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
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
        Column(
          mainAxisAlignment: MainAxisAlignment.start,
          //crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              gameInfo.title, // 텍스트 대신 DTO로 받은 데이터를 디스플레이
              style: TextStyle(fontSize: 25, fontWeight: FontWeight(400)),
              textScaler: TextScaler.noScaling,
            ),
            Text(
              gameInfo.playTime,
              style: TextStyle(fontSize: 25, fontWeight: FontWeight(400)),
            ),
            Text(
              gameInfo.userCount,
              style: TextStyle(fontSize: 25, fontWeight: FontWeight(400)),
            ),
            Text(
              gameInfo.shortExplain,
              style: TextStyle(fontSize: 25, fontWeight: FontWeight(400)),
            ),
          ],
        ),
      ],
    );
  }
}

// DTO 클래스 선언
class GameInfo {
  final String title;
  final String playTime;
  final String userCount;
  final String gameGenre;
  final String shortExplain;

  GameInfo({
    required this.title,
    required this.playTime,
    required this.userCount,
    required this.gameGenre,
    required this.shortExplain,
  });

  factory GameInfo.fromJson(Map<String, dynamic> json) {
    return GameInfo(
      title: json['name'] as String? ?? '이름 없음',
      playTime: json['playTime'] as String? ?? '미상',
      userCount: json['userCount'] as String? ?? '장르 없음',
      gameGenre: json['genre'] as String? ?? '장르 없음',
      shortExplain: json['shortExplain'] as String? ?? '설명 없음',
    );
  }
}
