import 'package:flutter/material.dart';
import 'package:project00/platform/hub/screens/mobile_group_join.dart';
import 'package:project00/platform/hub/services/game_service.dart';
import 'package:project00/platform/hub/widgets/mobile_group_top_bar.dart';

class HomeMobile extends StatefulWidget {
  const HomeMobile({super.key});

  @override
  State<HomeMobile> createState() => _HomeMobileState();
}

class _HomeMobileState extends State<HomeMobile> {
  late final Future<List<Map<String, dynamic>>>
  _games; // MobileGameCard에 들어갈 데이터 보관할 객체
  final GameService _gameService = GameService(); // 데이터 fetch할 객체

  @override
  void initState() {
    super.initState();
    _games = _gameService.fetchGames();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),

          child: Column(
            children: [
              SizedBox(height: 10),

              GroupTopBar(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => MobileGroupJoin()),
                  ); // MobileGroupJoin으로 이동
                },
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
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _games,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          '게임 목록을 불러오지 못했습니다.\n${snapshot.error}',
                          textAlign: TextAlign.center,
                        ),
                      );
                    }
                    final games = snapshot.data ?? [];

                    if (games.isEmpty) {
                      return const Center(child: Text("등록된 게임이 없습니다."));
                    }
                    return ListView.builder(
                      itemCount: games.length,
                      itemBuilder: (context, index) {
                        final gameData = games[index];
                        final gameInfo = GameInfo.fromJson(gameData);

                        return MobileGameCard(gameInfo: gameInfo);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
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
    return Column(
      children: [
        Row(
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

// DTO 클래스 선언
class GameInfo {
  final String title;
  final int playTime;
  final int minPlayers;
  final int maxPlayers;
  final List<String> genres;
  final String shortDescription;

  GameInfo({
    required this.title,
    required this.playTime,
    required this.minPlayers,
    required this.maxPlayers,
    required this.genres,
    required this.shortDescription,
  });

  factory GameInfo.fromJson(Map<String, dynamic> json) {
    return GameInfo(
      title: json['name'] as String? ?? '이름 없음',
      playTime: (json['playTimeMin'] as num?)?.toInt() ?? 0,
      minPlayers: (json['minPlayers'] as int?)?.toInt() ?? 0,
      maxPlayers: json['maxPlayers'] as int? ?? 0,
      genres: json['genres'] != null ? List<String>.from(json['genres']) : [],
      shortDescription: json['shortDescription'] as String? ?? '설명 없음',
    );
  }
}
