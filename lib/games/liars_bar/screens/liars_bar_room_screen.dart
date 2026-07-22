import 'package:flutter/material.dart';
import 'package:project00/platform/router/route_names.dart';
import 'package:project00/shared/game_kit/widgets/room_code_display.dart';

class LiarsBarRoomScreen extends StatelessWidget {
  const LiarsBarRoomScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('게임 대기실')),
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('방 코드'),
          const RoomCodeDisplay(code: 'ABCD'),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () =>
                Navigator.pushNamed(context, RouteNames.liarsBarGame),
            child: const Text('시작'),
          ),
        ],
      ),
    ),
  );
}
