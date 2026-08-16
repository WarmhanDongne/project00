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
          //=======================연결 상태==============================
          // 서버와 연결이 살아 있으면 초록, 끊기면 빨강으로 표시해 어느
          // 플레이어 때문에 진행이 멈췄는지 바로 알 수 있게 합니다.
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ConnectionDot(isConnected: player.isConnected),
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 16,
                backgroundImage: hasProfileImage
                    ? NetworkImage(player.profileImageUrl)
                    : null,
                child: hasProfileImage
                    ? null
                    : const Icon(Icons.person, size: 18),
              ),
            ],
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

/// 플레이어의 서버 연결 상태를 나타내는 표시등입니다.
class _ConnectionDot extends StatelessWidget {
  const _ConnectionDot({required this.isConnected});

  final bool isConnected;

  @override
  Widget build(BuildContext context) {
    final color = isConnected
        ? const Color(0xFF34C759)
        : const Color(0xFFFF3B30);
    return Semantics(
      label: isConnected ? '연결됨' : '연결 끊김',
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 4),
          ],
        ),
      ),
    );
  }
}
