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
  bool _isPreviewOpen = false;
  int _selectionGeneration = 0;
  Future<void>? _pendingClear;

  @override
  void initState() {
    super.initState();
    widget.gameProvider.fetchGames();
  }

  List<GameInfo> _filteredGames(List<GameInfo> games, String genreFilter) {
    final query = widget.searchQuery.trim().toLowerCase();
    return games
        .where((game) {
          final matchesSearch =
              query.isEmpty ||
              game.name.toLowerCase().contains(query) ||
              game.description.toLowerCase().contains(query) ||
              game.tabletDescription.toLowerCase().contains(query);
          final matchesGenre =
              genreFilter == '전체' ||
              game.genres.any(
                (genre) =>
                    genre.toLowerCase() == genreFilter.toLowerCase() ||
                    _localizedGenre(genre) == genreFilter,
              );
          return matchesSearch && matchesGenre;
        })
        .toList(growable: false);
  }

  /// 보유한 게임에 실제로 있는 장르만 남깁니다.
  ///
  /// 고를 수 없는 칸을 늘어놓으면 눌러도 결과가 비어 있어, 게임이 없는 것인지
  /// 장르가 없는 것인지 알 수 없습니다. 순서는 [_genres]를 따릅니다.
  List<String> _availableGenres(List<GameInfo> games) {
    // 게임 문서의 장르는 영문 코드일 수도, 이미 한글일 수도 있어 둘 다 맞춥니다.
    final owned = games
        .expand((game) => game.genres)
        .map(_localizedGenre)
        .toSet();
    return [_genres.first, ..._genres.skip(1).where(owned.contains)];
  }

  Future<void> _openPreview(GameInfo game) async {
    if (_isPreviewOpen) return;
    final hasRoom = widget.roomProvider.roomCode != null;
    final generation = ++_selectionGeneration;
    // 미리보기에 필요한 내용은 이미 목록에 들어와 있어 더 받아올 것이 없습니다.
    // 방에 선택을 알리는 서버 호출만 남는데, 그것을 기다리느라 화면을 멈추지
    // 않고 미리보기를 먼저 띄운 뒤 뒤에서 진행합니다.
    final pendingClear = _pendingClear;
    final selection = hasRoom
        ? Future(() async {
            // 앞서 닫은 미리보기의 선택 해제가 아직 날아가는 중이면 그 뒤에
            // 보냅니다. 방 명령은 한 번에 하나만 처리되어 겹쳐 보내면 뒤엣것이
            // 그대로 버려집니다.
            await pendingClear;
            return widget.roomProvider.selectGame(game.id);
          })
        : Future.value(true);

    setState(() => _isPreviewOpen = true);
    // true는 사용자가 닫았다는 뜻입니다. 시작하기로 넘어가면 null이 옵니다.
    final dismissed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => GamePreviewDialog(
        game: game,
        roomProvider: widget.roomProvider,
        selectionActive: hasRoom,
        selection: selection,
      ),
    );
    if (mounted) setState(() => _isPreviewOpen = false);
    if (!hasRoom || dismissed != true) return;
    // 닫기는 이미 끝났고, 방의 선택 해제만 여기서 이어서 보냅니다.
    _pendingClear = _clearSelection(generation, selection);
    await _pendingClear;
  }

  /// 미리보기를 닫은 뒤 방에 남은 게임 선택을 해제합니다.
  Future<void> _clearSelection(int generation, Future<bool> selection) async {
    // 선택이 서버에 닿기 전에 해제를 보내면 뒤늦은 선택이 방에 남습니다.
    // 선택 자체가 실패했다면 지울 것도 없습니다.
    if (!await selection) return;
    // 닫은 직후 다른 게임을 골랐다면 그 선택이 최신입니다. 해제하지 않습니다.
    if (_selectionGeneration != generation) return;
    final cleared = await widget.roomProvider.clearSelectedGame();
    if (cleared || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            widget.roomProvider.errorMessage ?? '게임 선택을 해제하지 못했습니다.',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    return AnimatedBuilder(
      animation: Listenable.merge([widget.gameProvider, widget.roomProvider]),
      builder: (context, _) {
        final hasRoom = widget.roomProvider.roomCode != null;
        final groupStatus = widget.roomProvider.groupGamesLoadStatus;
        final isLoading = hasRoom
            ? groupStatus == RoomDataLoadStatus.idle ||
                  groupStatus == RoomDataLoadStatus.loading
            : widget.gameProvider.isLoading;
        final errorMessage = hasRoom
            ? widget.roomProvider.groupGamesError
            : widget.gameProvider.errorMessage;
        final sourceGames = hasRoom
            ? widget.roomProvider.groupGames
            : widget.gameProvider.games;

        if (isLoading) {
          return Center(
            child: CircularProgressIndicator(color: colors.primary),
          );
        }
        if (errorMessage != null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(errorMessage),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: hasRoom
                      ? widget.roomProvider.retryGroupGames
                      : widget.gameProvider.fetchGames,
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          );
        }
        final genres = _availableGenres(sourceGames);
        // 고른 장르의 게임이 모두 빠지면(그룹 구성이 바뀌는 경우) 전체로
        // 되돌려, 빈 목록만 남는 상태에 갇히지 않게 합니다.
        final activeGenre = genres.contains(selectedGenre)
            ? selectedGenre
            : _genres.first;
        final games = _filteredGames(sourceGames, activeGenre);
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hasRoom ? '그룹이 보유 중인 게임' : '보유 중인 게임',
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final genre in genres) ...[
                      ChoiceChip(
                        label: Text(genre),
                        selected: activeGenre == genre,
                        showCheckmark: false,
                        onSelected: (_) =>
                            setState(() => selectedGenre = genre),
                        labelStyle: TextStyle(
                          color: activeGenre == genre
                              ? colors.primary
                              : colors.textMuted,
                          fontSize: 14,
                          fontWeight: activeGenre == genre
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
                          final availableWidth = constraints.maxWidth;
                          const spacing = 10.0;
                          const minimumCardWidth = 200.0;
                          // 간격까지 포함해 계산해야 실제 카드 너비가 200px 아래로
                          // 줄어들지 않습니다. 고정 종횡비 대신 이미지와 상세 영역의
                          // 높이를 따로 확보해 iPad 글자 크기에서도 넘침을 막습니다.
                          final columns =
                              ((availableWidth + spacing) /
                                      (minimumCardWidth + spacing))
                                  .floor()
                                  .clamp(1, 5);
                          final cardWidth =
                              (availableWidth - spacing * (columns - 1)) /
                              columns;
                          final textScale =
                              (MediaQuery.textScalerOf(context).scale(14) / 14)
                                  .clamp(1.0, 2.0);
                          // 1.3배처럼 태그가 한 줄 더 감기는 경계 배율에서도
                          // 실제 iPad의 RenderFlex 경고가 나지 않도록 여유를 둡니다.
                          final cardHeight = cardWidth + 150 * textScale;
                          return GridView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: games.length,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  crossAxisSpacing: spacing,
                                  mainAxisSpacing: spacing,
                                  mainAxisExtent: cardHeight,
                                ),
                            itemBuilder: (context, index) {
                              final game = games[index];
                              return GameCard(
                                game: game,
                                onTap: () => _openPreview(game),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        fit: StackFit.expand,
        children: [
          PlatformPanel(
            padding: const EdgeInsets.all(7),
            radius: 10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: SizedBox.expand(
                      child: _GameImage(url: game.imageUrl),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  game.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (game.playTime > 0)
                      PlatformTag(label: '${game.playTime}분'),
                    if (game.minPlayers > 0)
                      PlatformTag(
                        label: '${game.minPlayers}~${game.maxPlayers}인',
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (game.genres.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
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
              ],
            ),
          ),
        ],
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
