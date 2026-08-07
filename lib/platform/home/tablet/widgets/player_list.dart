import 'package:flutter/material.dart';
import 'package:project00/platform/home/room/models/room_player.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';

class PlayerListView extends StatelessWidget {
  const PlayerListView({
    super.key,
    required this.provider,
    required this.players,
  });

  final RoomProvider provider;
  final List<RoomPlayer> players;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: players.length,
      itemBuilder: (context, index) {
        final player = players[index];
        final hasProfileImage = player.profileImageUrl.isNotEmpty;

        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            radius: 16,
            backgroundImage: hasProfileImage
                ? NetworkImage(player.profileImageUrl)
                : null,
            child: hasProfileImage ? null : const Icon(Icons.person, size: 18),
          ),
          title: Text(
            player.nickname,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: '강퇴',
                onPressed: () async {
                  await provider.removePlayer(player.uid);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
