import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:project00/platform/hub/widgets/mobile_game_card.dart';

import '../dto/game_info.dart';

class OwnGameList extends StatelessWidget {
  const OwnGameList({super.key, required this._games});

  final Future<List<Map<String, dynamic>>> _games;

  @override
  Widget build(BuildContext context) {
    return Expanded(
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
    );
  }
}
