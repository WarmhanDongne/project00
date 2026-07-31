import 'package:flutter/material.dart';
import 'package:project00/platform/hub/screens/mobile_group_join.dart';
import 'package:project00/platform/hub/services/game_service.dart';
import 'package:project00/platform/hub/widgets/mobile_group_top_bar.dart';
import 'package:project00/platform/hub/widgets/mobile_own_game_list.dart';

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
                buttonText: "그룹 참여",
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
              OwnGameList(games: _games),
            ],
          ),
        ),
      ),
    );
  }
}
