import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:project00/platform/hub/providers/room_provider.dart';
import 'package:project00/platform/hub/services/game_service.dart';
import 'package:project00/platform/hub/services/room_service.dart';
import 'package:project00/platform/hub/widgets/button.dart';
import 'package:project00/platform/hub/widgets/game_preview_modal.dart';
import 'package:qr_flutter/qr_flutter.dart';

class HomeTablet extends StatefulWidget {
  const HomeTablet({super.key});

  @override
  State<HomeTablet> createState() => _HomeTabletState();
}

class _HomeTabletState extends State<HomeTablet> {
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
                AppButton(
                  text: '상점',
                  width: 160,
                  backgroundColor: Colors.blue,
                  onPressed: null,
                ),
                SizedBox(width: 300),
                Expanded(child: GameSearchBar()),
                SizedBox(width: 300),
                Profile(),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: GameList(
                      roomProvider: _roomProvider,
                      crossAxisCount: 5,
                    ),
                  ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(color: Colors.grey.shade300),
      child: const Text(
        '장르 필터 : 재미 / 추리 / 액션 / 심리 / 전략 / 수학 / 공간 / 협동',
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class GameList extends StatefulWidget {
  const GameList({
    super.key,
    required this.roomProvider,
    this.crossAxisCount = 5,
  });

  final RoomProvider roomProvider;
  final int crossAxisCount;

  @override
  State<GameList> createState() => _GameListState();
}

class _GameListState extends State<GameList> {
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
          return Center(
            child: Text(
              '게임 목록을 불러오지 못했습니다.\n${snapshot.error}',
              textAlign: TextAlign.center,
            ),
          );
        }

        final games = snapshot.data ?? [];

        if (games.isEmpty) {
          return const Center(child: Text('등록된 게임이 없습니다.'));
        }

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
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: widget.crossAxisCount,
                  crossAxisSpacing: 26,
                  mainAxisSpacing: 50,
                  childAspectRatio: 164 / 200,
                ),
                itemBuilder: (context, index) {
                  final game = games[index];

                  return GameCard(
                    game: game,
                    onTap: () {
                      showDialog<void>(
                        context: context,
                        barrierDismissible: true,
                        builder: (_) {
                          return GamePreviewDialog(
                            game: game,
                            roomProvider: widget.roomProvider,
                          );
                        },
                      );
                    },
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

class GameCard extends StatelessWidget {
  const GameCard({super.key, required this.game, required this.onTap});

  final Map<String, dynamic> game;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = game['name']?.toString() ?? '게임 이름';
    final posterUrl = game['posterUrl']?.toString() ?? '';
    final playType = game['playType']?.toString() ?? '';
    final recommendedPlayers = game['recommendedPlayers']?.toString() ?? '';
    final isOwned = game['isOwned'] == true;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            border: Border.all(color: Colors.grey.shade400),
          ),
          child: Column(
            children: [
              Expanded(
                child: SizedBox(
                  width: double.infinity,
                  child: posterUrl.isEmpty
                      ? Container(
                          color: Colors.grey.shade200,
                          alignment: Alignment.center,
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.image_outlined, size: 38),
                              SizedBox(height: 6),
                              Text('포스터'),
                            ],
                          ),
                        )
                      : Image.network(
                          posterUrl,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) {
                              return child;
                            }

                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Icon(
                                Icons.broken_image_outlined,
                                size: 38,
                              ),
                            );
                          },
                        ),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                color: isOwned ? Colors.blue.shade100 : Colors.grey.shade400,
                child: Column(
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (playType.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        playType,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                    if (recommendedPlayers.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        '권장 $recommendedPlayers',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GameSearchBar extends StatelessWidget {
  const GameSearchBar({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
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
          contentPadding: EdgeInsets.zero,
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

    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;

    return CircleAvatar(
      radius: 24,
      backgroundColor: Colors.grey,
      backgroundImage: hasPhoto ? NetworkImage(photoUrl) : null,
      child: hasPhoto ? null : const Icon(Icons.person, color: Colors.white),
    );
  }
}

class MemberTap extends StatelessWidget {
  const MemberTap({super.key, required this.provider});

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
                    AppButton(
                      text: '초기화',
                      width: 130,
                      backgroundColor: Colors.blue,
                      onPressed: null,
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
                  width: double.infinity,
                  color: Colors.grey.shade300,
                  padding: const EdgeInsets.all(12),
                  child: provider.isInRoom && provider.roomCode != null
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
