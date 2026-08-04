import 'package:flutter/material.dart';
import 'package:project00/platform/home/room/models/room_player.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';

class MemberListView extends StatelessWidget {
  const MemberListView({
    super.key,
    required this.provider,
    required this.members,
  });

  final RoomProvider provider;
  final List<RoomPlayer> members;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: members.length,
      itemBuilder: (context, index) {
        final member = members[index];
        final hasProfileImage = member.profileImageUrl.isNotEmpty;

        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            radius: 16,
            backgroundImage: hasProfileImage
                ? NetworkImage(member.profileImageUrl)
                : null,
            child: hasProfileImage ? null : const Icon(Icons.person, size: 18),
          ),
          title: Text(
            member.nickname,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (member.isHost)
                const Icon(Icons.star, color: Colors.orange, size: 20),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: '강퇴',
                onPressed: () async {
                  await provider.removePlayer(member.uid);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
