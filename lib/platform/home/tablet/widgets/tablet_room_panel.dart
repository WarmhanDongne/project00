import 'package:flutter/material.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';
import 'package:project00/platform/home/room/services/room_common.dart';
import 'package:project00/platform/home/room/providers/tablet_room_provider.dart';
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
              // if (provider.errorMessage != null)
              //   Padding(
              //     padding: const EdgeInsets.symmetric(vertical: 8),
              //     child: null,
              //   )
              // else
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
                              child: _MemberList(
                                members: provider.members,
                                maxMembers: RoomLimits.defaultMaxMembers,
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

class _MemberList extends StatelessWidget {
  const _MemberList({required this.members, required this.maxMembers});

  final List<RoomMember> members;
  final int maxMembers;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '[ 현 인원 ${members.length}/$maxMembers명 ]',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: members.isEmpty
              ? const Center(child: Text('구성원을 불러오는 중입니다.'))
              : ListView.builder(
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
                        child: hasProfileImage
                            ? null
                            : const Icon(Icons.person, size: 18),
                      ),
                      title: Text(
                        member.nickname,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: member.isHost
                          ? const Icon(
                              Icons.star,
                              color: Colors.orange,
                              size: 20,
                            )
                          : null,
                    );
                  },
                ),
        ),
      ],
    );
  }
}
