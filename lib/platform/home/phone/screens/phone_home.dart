import 'package:flutter/material.dart';
import 'package:project00/platform/home/gamelist/models/game_info.dart';
import 'package:project00/platform/home/phone/screens/phone_room_join.dart';
import 'package:project00/platform/home/gamelist/service/game_list_service.dart';
import 'package:project00/platform/home/phone/widgets/phone_header.dart';
import 'package:project00/platform/home/phone/widgets/phone_own_game_list.dart';
import 'package:project00/platform/theme/platform_theme.dart';

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
    // 앱 첫 화면의 방향은 iOS scene이 resumed 된 뒤 main.dart에서 적용합니다.
    // 게임 종료 후 세로 복원은 휴대폰 게임 화면과 대기 화면이 담당합니다.
    _games = _gameService.fetchGames();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    return Scaffold(
      backgroundColor: colors.canvas,
      body: SafeArea(
        child: Column(
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
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Row(
                children: [
                  const Text(
                    '보유 중인 게임',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '모바일에서는 방에 참여해 플레이합니다.',
                    style: TextStyle(color: colors.textMuted, fontSize: 10),
                  ),
                ],
              ),
            ),
            PhoneOwnGameList(games: _games),
          ],
        ),
      ),
    );
  }
}
