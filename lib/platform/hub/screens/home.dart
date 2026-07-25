import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:project00/platform/hub/providers/room_provider.dart';
import 'package:project00/platform/hub/services/game_service.dart';
import 'package:project00/platform/hub/services/room_service.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:project00/shared/player_layouts/player_layout.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final RoomProvider _roomProvider = RoomProvider();

  @override
  void initState() {
    super.initState();
    _roomProvider.initializePersonalRoom();
  }

  @override
  void dispose() {
    _roomProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            const Row(
              children: [
                ShopButton(),
                SizedBox(width: 300),
                Expanded(child: SearchBar()),
                SizedBox(width: 300),
                Profile(),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Gamelist(roomProvider: _roomProvider)),
                  const SizedBox(width: 24),
                  MemberTap(provider: _roomProvider),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FilterBar extends StatelessWidget {
  const FilterBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 678,
      height: 50,
      decoration: const BoxDecoration(color: Colors.grey),
    );
  }
}

class Gamelist extends StatefulWidget {
  const Gamelist({super.key, required this.roomProvider});

  final RoomProvider roomProvider;

  @override
  State<Gamelist> createState() => _GamelistState();
}

class _GamelistState extends State<Gamelist> {
  final GameService _gameService = GameService();
  late final Future<List<Map<String, dynamic>>> _games;

  @override
  void initState() {
    super.initState();
    _games = _gameService.fetchGames();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _games,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(snapshot.error.toString()));
        }

        final games = snapshot.data ?? [];

        return Column(
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: SizedBox(
                height: 50,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FilterBar(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                itemCount: games.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: 26,
                  mainAxisSpacing: 50,
                  childAspectRatio: 164 / 200,
                ),
                itemBuilder: (context, index) {
                  final game = games[index];

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,

                        MaterialPageRoute(
                          builder: (_) =>
                              PlayerSlots(players: widget.roomProvider.members),
                        ),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: game['isOwned'] == true
                            ? Colors.blue
                            : Colors.grey,
                      ),
                      child: Center(
                        child: Text(
                          game['name'] as String? ?? '',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class ShopButton extends StatelessWidget {
  const ShopButton({super.key});

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: () {},
      label: const Text('상점'),
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
        padding: const EdgeInsets.symmetric(horizontal: 70, vertical: 12),
      ),
    );
  }
}

class SearchBar extends StatelessWidget {
  const SearchBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      alignment: Alignment.center,
      child: TextField(
        decoration: InputDecoration(
          hintText: '게임 검색',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
      ),
    );
  }
}

class Profile extends StatelessWidget {
  const Profile({super.key});

  @override
  Widget build(BuildContext context) {
    final photoUrl = FirebaseAuth.instance.currentUser?.photoURL;
    return CircleAvatar(
      radius: 24,
      backgroundColor: Colors.grey,
      backgroundImage: photoUrl == null || photoUrl.isEmpty
          ? null
          : NetworkImage(photoUrl),
      child: photoUrl == null || photoUrl.isEmpty
          ? const Icon(Icons.person, color: Colors.white)
          : null,
    );
  }
}

class MemberTap extends StatelessWidget {
  const MemberTap({required this.provider, super.key});

  final RoomProvider provider;

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
                    FilledButton.icon(
                      onPressed: () {},
                      label: const Text('초기화'),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(0),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (provider.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    provider.errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                )
              else
                const SizedBox(height: 16),

              Expanded(
                child: Container(
                  color: Colors.grey.shade300,
                  padding: const EdgeInsets.all(12),
                  child: provider.isInRoom
                      ? Column(
                          children: [
                            Expanded(
                              child: _MemberList(
                                members: provider.members,
                                maxMembers:
                                    provider.room?.maxMembers ??
                                    RoomService.defaultMaxMembers,
                              ),
                            ),

                            const SizedBox(height: 12),

                            _InviteRoom(roomCode: provider.roomCode!),
                          ],
                        )
                      : const Center(child: CircularProgressIndicator()),
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

class _InviteRoom extends StatelessWidget {
  const _InviteRoom({required this.roomCode});

  final String roomCode;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
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
      ),
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
        Expanded(
          child: members.isEmpty
              ? const Center(child: Text('구성원을 불러오는 중입니다.'))
              : ListView.builder(
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final member = members[index];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundImage: member.profileImageUrl.isEmpty
                            ? null
                            : NetworkImage(member.profileImageUrl),
                        child: member.profileImageUrl.isEmpty
                            ? const Icon(Icons.person, size: 18)
                            : null,
                      ),
                      title: Text(member.nickname),
                      trailing: member.isHost
                          ? const Icon(Icons.star, color: Colors.orange)
                          : null,
                    );
                  },
                ),
        ),
      ],
    );
  }
}
