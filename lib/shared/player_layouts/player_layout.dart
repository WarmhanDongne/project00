import 'package:flutter/material.dart';
import 'package:project00/platform/hub/services/room_models.dart';

import 'package:project00/shared/player_layouts/layout_2p.dart';
import 'package:project00/shared/player_layouts/layout_3p.dart';
import 'package:project00/shared/player_layouts/layout_4p.dart';
import 'package:project00/shared/player_layouts/layout_5p.dart';
import 'package:project00/shared/player_layouts/layout_6p.dart';

class PlayerSlots extends StatelessWidget {
  const PlayerSlots({super.key, required this.players});

  final List<RoomMember> players;
  @override
  Widget build(BuildContext context) {
    switch (players.length) {
      case 1:
        return const ThreePlayerLayout();
      case 2:
        return const TwoPlayerLayout();

      case 3:
        return const ThreePlayerLayout();

      case 4:
        return const FourPlayerLayout();

      case 5:
        return const FivePlayerLayout();

      case 6:
        return const SixPlayerLayout();

      default:
        return const Center(child: Text('지원하지 않는 인원수입니다.'));
    }
  }
}
