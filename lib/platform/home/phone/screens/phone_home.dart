import 'package:flutter/material.dart';
import 'package:project00/games/liars_poker/widgets/rolebook_tablet.dart';
import 'package:project00/games/mafia/screens/phone_game.dart';
import 'package:project00/platform/home/gamelist/models/game_info.dart';
import 'package:project00/platform/home/phone/screens/phone_room_join.dart';
import 'package:project00/platform/home/gamelist/service/game_list_service.dart';
import 'package:project00/platform/home/phone/widgets/phone_header.dart';
import 'package:project00/platform/home/phone/widgets/phone_own_game_list.dart';
import 'package:project00/games/liars_poker/screens/phone_game.dart';

class PhoneHome extends StatefulWidget {
  const PhoneHome({super.key});

  @override
  State<PhoneHome> createState() => _PhoneHomeState();
}

class _PhoneHomeState extends State<PhoneHome> {
  late final Future<List<GameInfo>>
  _games; // PhoneGamePortraitCard에 들어갈 데이터 보관할 객체
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
            PhoneHeader(
              buttonText: "그룹 참여",
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => PhoneRoomJoin()),
                ); // PhoneRoomJoin으로 이동
              },
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),

              child: Column(children: [SizedBox(height: 10), gameListText()]),
            ),
            OwnGameList(games: _games),
            Button(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MafiaPhoneGame()),
              ),
              text: "마피아 게임<-",
              color: Colors.black,
            ),
          ],
        ),
      ),
    );
  }

  Column gameListText() {
    return Column(
      // 보유 중인 게임
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        SizedBox(height: 20),
        Row(
          children: [
            Text(
              "보유 중인 게임",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => PhoneGame()),
                );
              },
              child: Text('폰게임으로 가는 길~'),
            ),
          ],
        ),
        SizedBox(height: 10),
      ],
    );
  }
}
