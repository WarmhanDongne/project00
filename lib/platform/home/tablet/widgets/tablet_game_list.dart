import 'package:flutter/material.dart';
import 'package:project00/platform/home/gamelist/models/game_info.dart';
import 'package:project00/platform/home/gamelist/provider/game_list_provider.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';
import 'package:project00/platform/home/tablet/widgets/tablet_game_preview_modal.dart';
import 'package:project00/platform/theme/platform_theme.dart';
import 'package:project00/platform/widgets/platform_components.dart';

const _genres = <String>['전체', '재미', '추리', '액션', '심리', '전략', '수학', '공간', '협동'];

//=======================보유 게임 목록==============================
class GameList extends StatefulWidget {
  const GameList({
    super.key,
    required this.gameProvider,
    required this.roomProvider,
    this.searchQuery = '',
  });

  final GameProvider gameProvider;
  final RoomProvider roomProvider;
  final String searchQuery;

  @override
  State<GameList> createState() => _GameListState();
}

class _GameListState extends State<GameList> {
  String selectedGenre = '전체';

  @override
  void initState() {
    super.initState();
    widget.gameProvider.fetchGames();
  }

  List<GameInfo> _filteredGames(List<GameInfo> games) {
    final query = widget.searchQuery.trim().toLowerCase();
    return games
        .where((game) {
          final matchesSearch =
              query.isEmpty ||
              game.name.toLowerCase().contains(query) ||
              game.description.toLowerCase().contains(query);
          final matchesGenre =
              selectedGenre == '전체' ||
              game.genres.any(
                (genre) =>
                    genre.toLowerCase() == selectedGenre.toLowerCase() ||
                    _localizedGenre(genre) == selectedGenre,
              );
          return matchesSearch && matchesGenre;
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    return AnimatedBuilder(
      animation: widget.gameProvider,
      builder: (context, _) {
        if (widget.gameProvider.isLoading) {
          return Center(
            child: CircularProgressIndicator(color: colors.primary),
          );
        }
        if (widget.gameProvider.errorMessage != null) {
          return Center(child: Text(widget.gameProvider.errorMessage!));
        }
        final games = _filteredGames(widget.gameProvider.games);
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    '보유 중인 게임',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(width: 20),
                  Text(
                    '${widget.gameProvider.games.length}',
                    style: TextStyle(color: colors.textMuted, fontSize: 15),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final genre in _genres) ...[
                      ChoiceChip(
                        label: Text(genre),
                        selected: selectedGenre == genre,
                        showCheckmark: false,
                        onSelected: (_) =>
                            setState(() => selectedGenre = genre),
                        labelStyle: TextStyle(
                          color: selectedGenre == genre
                              ? colors.primary
                              : colors.textMuted,
                          fontSize: 14,
                          fontWeight: selectedGenre == genre
                              ? FontWeight.w800
                              : FontWeight.w500,
                        ),
                        backgroundColor: colors.surfaceMuted,
                        selectedColor: colors.primarySoft,
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(width: 7),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: games.isEmpty
                    ? Center(
                        child: Text(
                          '조건에 맞는 게임이 없습니다.',
                          style: TextStyle(color: colors.textMuted),
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          const columns = 4;
                          const spacing = 10.0;
                          final tileWidth =
                              (constraints.maxWidth - spacing * (columns - 1)) /
                              columns;
                          final targetHeight =
                              ((constraints.maxHeight - spacing) / 1.52).clamp(
                                205.0,
                                double.infinity,
                              );
                          return GridView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: games.length,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  crossAxisSpacing: spacing,
                                  mainAxisSpacing: spacing,
                                  childAspectRatio: tileWidth / targetHeight,
                                ),
                            itemBuilder: (context, index) {
                              final game = games[index];
                              return GameCard(
                                game: game,
                                onTap: () => showDialog<void>(
                                  context: context,
                                  builder: (_) => GamePreviewDialog(
                                    game: game,
                                    roomProvider: widget.roomProvider,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

//=======================게임 카드==============================
class GameCard extends StatelessWidget {
  const GameCard({super.key, required this.game, required this.onTap});

  final GameInfo game;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: PlatformPanel(
        padding: const EdgeInsets.all(7),
        radius: 10,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: SizedBox.expand(child: _GameImage(url: game.imageUrl)),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              game.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 5),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                if (game.playTime > 0) PlatformTag(label: '${game.playTime}분'),
                if (game.minPlayers > 0)
                  PlatformTag(label: '${game.minPlayers}~${game.maxPlayers}인'),
              ],
            ),
            const SizedBox(height: 5),
            if (game.genres.isNotEmpty)
              Wrap(
                spacing: 4,
                children: game.genres
                    .take(2)
                    .map(
                      (genre) => PlatformTag(
                        label: _localizedGenre(genre),
                        highlighted: true,
                      ),
                    )
                    .toList(growable: false),
              ),
            const SizedBox(height: 5),
            Text(
              game.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameImage extends StatelessWidget {
  const _GameImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    if (url.isEmpty) {
      return ColoredBox(
        color: colors.surfaceMuted,
        child: Center(
          child: Text(
            'poster',
            style: TextStyle(color: colors.textMuted, fontSize: 9),
          ),
        ),
      );
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : ColoredBox(color: colors.surfaceMuted),
      errorBuilder: (_, _, _) => ColoredBox(
        color: colors.surfaceMuted,
        child: Icon(Icons.broken_image_outlined, color: colors.textMuted),
      ),
    );
  }
}

String _localizedGenre(String genre) => switch (genre.toLowerCase()) {
  'fun' => '재미',
  'mystery' || 'deduction' => '추리',
  'action' => '액션',
  'psychology' || 'bluff' => '심리',
  'strategy' => '전략',
  'math' => '수학',
  'spatial' => '공간',
  'co-op' || 'cooperative' => '협동',
  'card' => '카드',
  _ => genre,
};
