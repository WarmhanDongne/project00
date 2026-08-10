import 'package:flutter/material.dart';
import 'package:project00/platform/home/gamelist/models/game_info.dart';
import 'package:project00/platform/home/phone/widgets/phone_game_card.dart';

class PhoneOwnGameList extends StatelessWidget {
  const PhoneOwnGameList({super.key, required this.games});

  final Future<List<GameInfo>> games;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: FutureBuilder<List<GameInfo>>(
        future: games,
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
              return PhoneGameCard(gameInfo: games[index]);
            },
          );
        },
      ),
    );
  }
}
