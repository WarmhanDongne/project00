import 'package:flutter/material.dart';
import 'package:project00/platform/home/gamelist/models/game_info.dart';
import 'package:project00/platform/home/gamelist/provider/game_list_provider.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';
import 'package:project00/platform/home/tablet/widgets/tablet_game_preview_modal.dart';

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
    required this.gameProvider,
    required this.roomProvider,
  });

  final GameProvider gameProvider;
  final RoomProvider roomProvider;

  @override
  State<GameList> createState() => _GameListState();
}

class _GameListState extends State<GameList> {
  @override
  void initState() {
    super.initState();
    widget.gameProvider.fetchGames();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.gameProvider,
      builder: (context, _) {
        if (widget.gameProvider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (widget.gameProvider.errorMessage != null) {
          return Center(
            child: Text(
              widget.gameProvider.errorMessage!,
              textAlign: TextAlign.center,
            ),
          );
        }

        final games = widget.gameProvider.games;

        if (games.isEmpty) {
          return const Center(
            child: Text('구매된 게임이 없습니다.'),
          );
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
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
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
  const GameCard({
    super.key,
    required this.game,
    required this.onTap,
  });

  final GameInfo game;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
                  child: game.imageUrl.isEmpty
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
                          game.imageUrl,
                          fit: BoxFit.cover,
                          loadingBuilder:
                              (context, child, progress) {
                            if (progress == null) return child;
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          },
                          errorBuilder:
                              (context, error, stackTrace) {
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
                color: game.isOwned
                    ? Colors.blue.shade100
                    : Colors.grey.shade400,
                child: Column(
                  children: [
                    Text(
                      game.name.isEmpty
                          ? '게임 이름'
                          : game.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (game.minPlayers > 0 ||
                        game.maxPlayers > 0) ...[
                      const SizedBox(height: 3),
                      Text(
                        '${game.minPlayers}~${game.maxPlayers}명 · ${game.playTime}분',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                    if (game.genresText.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        game.genresText,
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