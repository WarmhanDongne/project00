import 'package:flutter/material.dart';
import 'package:project00/platform/dto/dto_game_info.dart';
import 'package:project00/platform/hub/phone/screens/phone_group_join.dart';
import 'package:project00/platform/hub/services/game_service.dart';
import 'package:project00/platform/hub/phone/widgets/phone_group_top_bar.dart';
import 'package:project00/platform/hub/phone/widgets/phone_own_game_list.dart';

class PhoneHome extends StatefulWidget {
  const PhoneHome({super.key});

  @override
  State<PhoneHome> createState() => _PhoneHomeState();
}

class _PhoneHomeState extends State<PhoneHome> {
  late final Future<List<GameInfo>> _games; // PhoneGameCard에 들어갈 데이터 보관할 객체
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
        body: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),

              child: Column(
                children: [
                  SizedBox(height: 10),

                  GroupTopBar(
                    buttonText: "그룹 참여",
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PhoneGroupJoin(),
                        ),
                      ); // PhoneGroupJoin으로 이동
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
                ],
              ),
            ),
            OwnGameList(games: _games),
          ],
        ),
      ),
    );
  }
}
