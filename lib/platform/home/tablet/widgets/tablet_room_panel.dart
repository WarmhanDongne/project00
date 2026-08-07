import 'package:flutter/material.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';
import 'package:project00/platform/home/room/services/room_common.dart';
import 'package:project00/platform/home/tablet/widgets/tablet_button.dart';
import 'package:qr_flutter/qr_flutter.dart';

class TabletRoomPanel extends StatelessWidget {
  const TabletRoomPanel({super.key, required this.provider});

  // final TabletRoomProvider provider;
  final RoomProvider provider;

  void createRoom() {
    provider.createRoom();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: provider,
      builder: (context, _) {
        return SizedBox(
          width: 230,
          child: Column(
            children: [
              const SizedBox(height: 16),
              SizedBox(
                height: 50,
                child: Row(
                  children: [
                    const Text('구성원 목록', style: TextStyle(fontSize: 16)),
                    const Spacer(),
                    AppButton(
                      text: provider.roomCode == null ? '생성하기' : '초기화',
                      width: 130,
                      backgroundColor: Colors.blue,
                      onPressed: () => createRoom(),
                    ),
                  ],
                ),
              ),
              if (provider.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    provider.errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                )
              else
                const SizedBox(height: 16),
              Expanded(
                child: Container(
                  width: double.infinity,
                  color: Colors.grey.shade300,
                  padding: const EdgeInsets.all(12),
                  child: provider.roomCode != null
                      ? Column(
                          children: [
                            Expanded(
                              child: _PlayerList(
                                players: provider.players,
                                maxplayers: RoomLimits.defaultMaxPlayers,
                                provider: provider,
                              ),
                            ),
                            const SizedBox(height: 12),
                            QR(roomCode: provider.roomCode!),
                          ],
                        )
                      : Center(
                          child: Text(
                            provider.isLoading
                                ? '방을 생성하고 있습니다.'
                                : '초대하기를 눌러 방을 만들어주세요.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                ),
              ),
              if (provider.isLoading) const LinearProgressIndicator(),
            ],
          ),
        );
      },
    );
  }
}

class QR extends StatelessWidget {
  const QR({super.key, required this.roomCode});

  final String roomCode;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 120,
          height: 120,
          padding: const EdgeInsets.all(10),
          color: Colors.white,
          child: QrImageView(
            data: roomCode,
            padding: EdgeInsets.zero,
            backgroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          color: Colors.grey.shade500,
          child: Text(
            '코드 : $roomCode',
            style: const TextStyle(fontSize: 15, color: Colors.black),
          ),
        ),
      ],
    );
  }
}

class _PlayerList extends StatelessWidget {
  const _PlayerList({
    required this.players,
    required this.maxplayers,
    required this.provider,
  });

  final RoomProvider provider;
  final List<RoomPlayer> players;
  final int maxplayers;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '[ 현 인원 ${players.length}/$maxplayers명 ]',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: players.isEmpty
              ? const Center(child: Text('구성원을 불러오는 중입니다.'))
              : ListView.builder(
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
                        child: hasProfileImage
                            ? null
                            : const Icon(Icons.person, size: 18),
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
                ),
        ),
      ],
    );
  }
}
