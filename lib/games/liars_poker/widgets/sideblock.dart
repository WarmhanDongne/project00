import 'package:flutter/material.dart';
import 'package:project00/games/liars_poker/widgets/rolebook.dart';
import 'package:project00/games/liars_poker/widgets/setting.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';

class SideBlock extends StatefulWidget {
  const SideBlock({super.key, required this.provider});

  final RoomProvider provider;
  @override
  State<SideBlock> createState() => _SideBlockState();
}

class _SideBlockState extends State<SideBlock> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () {
                showDialog(
                  context: context,
                  barrierDismissible: true,
                  builder: (context) {
                    return Align(
                      alignment: Alignment(0, 0.7), // 아래로 이동
                      child: Material(
                        color: Colors.transparent,
                        child: RoleBook(provider: widget.provider),
                      ),
                    );
                  },
                );
              },
              icon: Icon(Icons.book, color: Colors.white, size: 70),
            ),
            IconButton(
              onPressed: () {
                showDialog(
                  context: context,
                  barrierDismissible: true,
                  builder: (context) {
                    return Align(
                      alignment: Alignment(0, 0.7), // 아래로 이동
                      child: Material(
                        color: Colors.transparent,
                        child: Setting(provider: widget.provider),
                      ),
                    );
                  },
                );
              },
              icon: Icon(Icons.settings, color: Colors.white, size: 70),
            ),
          ],
        ),
      ],
    );
  }
}
