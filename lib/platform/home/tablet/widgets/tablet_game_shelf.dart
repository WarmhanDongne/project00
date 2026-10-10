import 'package:project00/platform/localization/platform_localizations.dart';
import 'package:flutter/material.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:game_kit/mosi_ui/mosi_game_art.dart';
import 'package:project00/platform/home/gamelist/models/game_info.dart';
import 'package:project00/platform/home/gamelist/provider/game_list_provider.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';
import 'tablet_book_carousel.dart';

//=======================게임 선반==============================
// 가운데 고른 책의 앞면, 양옆으로 다른 책의 옆면이 꽂힌 책장입니다.
// 선택된 책을 누르거나 '자세히 보기'를 누르면 [onOpenDetail]로 상세 화면을 엽니다.

class TabletGameShelf extends StatefulWidget {
  const TabletGameShelf({
    super.key,
    required this.gameProvider,
    required this.roomProvider,
    required this.selectedGameId,
    required this.onSelect,
    required this.onOpenDetail,
    required this.theme,
    required this.onlyPlayable,
    required this.onOnlyPlayableChanged,
    this.preparing = false,
    this.selectedCoverKey,
  });

  /// 고른 게임을 준비 중인지입니다(책 위 준비 표시).
  final bool preparing;

  /// 고른 책 자리를 재는 키입니다(책이 열리는 화면 전환).
  final GlobalKey? selectedCoverKey;

  final GameProvider gameProvider;
  final RoomProvider roomProvider;
  final String? selectedGameId;
  final ValueChanged<GameInfo> onSelect;
  final ValueChanged<GameInfo> onOpenDetail;
  final MosiShelfTheme theme;
  final bool onlyPlayable;
  final ValueChanged<bool> onOnlyPlayableChanged;

  @override
  State<TabletGameShelf> createState() => _TabletGameShelfState();
}

class _TabletGameShelfState extends State<TabletGameShelf> {
  List<GameInfo> _lastVisibleGames = const [];

  @override
  void initState() {
    super.initState();
    if (widget.gameProvider.games.isEmpty && !widget.gameProvider.isLoading) {
      widget.gameProvider.fetchGames();
    }
  }

  int get _playerCount => widget.roomProvider.players
      .where((player) => player.isActive && player.isPlayer)
      .length;

  @override
  Widget build(BuildContext context) {
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

        // 방 생성·구성원 변경으로 그룹 게임을 다시 받는 동안에도 이전
        // 선반을 유지합니다. 통째로 비우면 화면이 깜빡이는 것처럼 보입니다.
        if (!isLoading && errorMessage == null) {
          _lastVisibleGames = sourceGames;
        }
        final visibleGames =
            isLoading && sourceGames.isEmpty && _lastVisibleGames.isNotEmpty
            ? _lastVisibleGames
            : sourceGames;

        final fg = widget.theme.fg;
        if (isLoading && visibleGames.isEmpty) {
          return Center(child: CircularProgressIndicator(color: fg));
        }
        if (errorMessage != null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  errorMessage,
                  style: MosiFonts.sans(
                    locale: Localizations.maybeLocaleOf(context),
                    size: 15,
                    color: fg,
                  ),
                ),
                const SizedBox(height: 12),
                MosiButton(
                  label: context.l10n.retry,
                  onPressed: hasRoom
                      ? widget.roomProvider.retryGroupGames
                      : widget.gameProvider.fetchGames,
                  background: widget.theme.btnBg,
                  foreground: widget.theme.btnFg,
                  shadowColor: widget.theme.deep,
                ),
              ],
            ),
          );
        }

        final playerCount = _playerCount;
        final canFilter = hasRoom && playerCount > 0;
        final games = widget.onlyPlayable && canFilter
            ? visibleGames
                  .where((game) => _isPlayable(game, playerCount))
                  .toList(growable: false)
            : visibleGames;

        return Column(
          children: [
            Center(
              child: _PlayableToggle(
                value: widget.onlyPlayable && canFilter,
                playerCount: playerCount,
                theme: widget.theme,
                onChanged: canFilter ? widget.onOnlyPlayableChanged : null,
              ),
            ),
            const SizedBox(height: 18),
            if (games.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    widget.onlyPlayable && canFilter
                        ? '지금 $playerCount명이 할 수 있는 게임이 없어요'
                        : '선반에 게임이 없어요',
                    style: MosiFonts.sans(
                      locale: Localizations.maybeLocaleOf(context),
                      size: 16,
                      weight: FontWeight.w600,
                      color: fg,
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: _ShelfBody(
                  games: games,
                  selected: _resolveSelected(games),
                  roomProvider: widget.roomProvider,
                  playerCount: playerCount,
                  theme: widget.theme,
                  onSelect: widget.onSelect,
                  onOpenDetail: widget.onOpenDetail,
                  preparing: widget.preparing,
                  selectedCoverKey: widget.selectedCoverKey,
                ),
              ),
          ],
        );
      },
    );
  }

  GameInfo _resolveSelected(List<GameInfo> games) {
    for (final game in games) {
      if (game.id == widget.selectedGameId) return game;
    }
    final fallback = games.first;
    // 고른 게임이 걸러졌다면 첫 게임으로 맞춰 배경 테마도 함께 바꿉니다.
    if (widget.selectedGameId != fallback.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onSelect(fallback);
      });
    }
    return fallback;
  }

  bool _isPlayable(GameInfo game, int count) =>
      isGamePlayableWith(game, count, widget.roomProvider);
}

/// 지금 인원으로 이 게임을 시작할 수 있는지 판단합니다.
bool isGamePlayableWith(GameInfo game, int count, RoomProvider roomProvider) {
  final supported = roomProvider.gameCatalog
      .find(game.id)
      ?.supportedPlayerCounts;
  if (supported != null) return supported.contains(count);
  final min = game.minPlayers > 0 ? game.minPlayers : 2;
  final max = game.maxPlayers > 0 ? game.maxPlayers : 99;
  return count >= min && count <= max;
}

/// 시안의 인원 표기('2–6명', '4명 · 6명')입니다.
String gamePlayerRangeLabel(GameInfo game, RoomProvider roomProvider) {
  final supported = roomProvider.gameCatalog
      .find(game.id)
      ?.supportedPlayerCounts;
  if (supported != null) return supported.map((n) => '$n명').join(' · ');
  if (game.minPlayers > 0 && game.maxPlayers > 0) {
    return '${game.minPlayers}–${game.maxPlayers}명';
  }
  if (game.minPlayers > 0) return '${game.minPlayers}명부터';
  if (game.maxPlayers > 0) return '최대 ${game.maxPlayers}명';
  return '';
}

/// 시작할 수 없을 때 보여 줄 안내입니다. 시작할 수 있으면 null입니다.
String? gameCannotStartMessage(
  GameInfo game,
  int count,
  RoomProvider roomProvider,
) {
  if (isGamePlayableWith(game, count, roomProvider)) return null;
  final supported = roomProvider.gameCatalog
      .find(game.id)
      ?.supportedPlayerCounts;
  if (supported != null) {
    return '${supported.join('명이나 ')}명이 모이면 시작할 수 있어요 · 지금 $count명';
  }
  final min = game.minPlayers > 0 ? game.minPlayers : 2;
  if (count < min) return '$min명부터 시작할 수 있어요 · 지금 $count명';
  return '최대 ${game.maxPlayers}명까지 함께할 수 있어요 · 지금 $count명';
}

class _PlayableToggle extends StatelessWidget {
  const _PlayableToggle({
    required this.value,
    required this.playerCount,
    required this.theme,
    required this.onChanged,
  });

  final bool value;
  final int playerCount;
  final MosiShelfTheme theme;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final fg = theme.fg;
    return Semantics(
      toggled: value,
      button: true,
      label: onChanged == null
          ? '참가자가 입장하면 인원별로 볼 수 있어요'
          : '지금 $playerCount명이 할 수 있는 게임만 보기',
      enabled: onChanged != null,
      excludeSemantics: true,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: GestureDetector(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.fromLTRB(8, 0, 18, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: fg, width: 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 44,
                height: 26,
                padding: const EdgeInsets.all(3),
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: value ? MosiColors.lime : Colors.transparent,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: fg, width: 2),
                ),
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: value ? MosiColors.navy : fg,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text.rich(
                  TextSpan(
                    children: [
                      if (onChanged == null)
                        const TextSpan(text: '참가자가 입장하면 인원별로 보기')
                      else ...[
                        const TextSpan(text: '지금 '),
                        TextSpan(
                          text: '$playerCount명',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const TextSpan(text: '이 할 수 있는 게임만'),
                      ],
                    ],
                  ),
                  style: MosiFonts.sans(
                    locale: Localizations.maybeLocaleOf(context),
                    size: 15,
                    weight: FontWeight.w600,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShelfBody extends StatelessWidget {
  const _ShelfBody({
    required this.games,
    required this.selected,
    required this.roomProvider,
    required this.playerCount,
    required this.theme,
    required this.onSelect,
    required this.onOpenDetail,
    this.preparing = false,
    this.selectedCoverKey,
  });

  final bool preparing;
  final GlobalKey? selectedCoverKey;
  final List<GameInfo> games;
  final GameInfo selected;
  final RoomProvider roomProvider;
  final int playerCount;
  final MosiShelfTheme theme;
  final ValueChanged<GameInfo> onSelect;
  final ValueChanged<GameInfo> onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final art = MosiGameArt.of(selected.id, fallbackName: selected.name);
    final hasRoom = roomProvider.roomCode != null;
    final cannotStart = hasRoom
        ? gameCannotStartMessage(selected, playerCount, roomProvider)
        : null;
    final range = gamePlayerRangeLabel(selected, roomProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        // 좁은 태블릿에서는 선반 높이를 줄여 아래 소개가 잘리지 않게 합니다.
        final compact = constraints.maxHeight < 560;
        final coverWidth = compact ? 200.0 : 240.0;
        return Column(
          children: [
            TabletBookCarousel(
              games: games,
              selected: selected,
              coverWidth: coverWidth,
              deep: theme.deep,
              emptyColor: theme.fgDim,
              onSelect: onSelect,
              onOpenDetail: onOpenDetail,
              preparing: preparing,
              selectedCoverKey: selectedCoverKey,
            ),
            // 선반 판자: 왼쪽 화면 끝까지 이어집니다.
            SizedBox(
              height: 14,
              child: OverflowBox(
                alignment: Alignment.centerLeft,
                minWidth: constraints.maxWidth + 48,
                maxWidth: constraints.maxWidth + 48,
                child: Transform.translate(
                  offset: const Offset(-48, 0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.deep,
                      border: const Border(
                        top: BorderSide(color: MosiColors.ink, width: 3),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        art.koreanName == selected.id
                            ? selected.name
                            : art.koreanName,
                        style: MosiFonts.sans(
                          locale: Localizations.maybeLocaleOf(context),
                          size: compact ? 26 : 32,
                          weight: FontWeight.w700,
                          color: theme.fg,
                          letterSpacing: -1,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        art.englishName,
                        style: MosiFonts.grotesk(
                          locale: Localizations.maybeLocaleOf(context),
                          size: 12,
                          color: art.id == 'liars_poker'
                              ? theme.accA
                              : theme.accB,
                          letterSpacing: 3,
                        ),
                      ),
                      if (selected.description.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          selected.description,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: MosiFonts.sans(
                            locale: Localizations.maybeLocaleOf(context),
                            size: 14,
                            color: theme.fg,
                          ),
                        ),
                      ],
                      if (cannotStart != null) ...[
                        const SizedBox(height: 8),
                        MosiPill(
                          label: cannotStart,
                          background: MosiColors.sun,
                          borderColor: MosiColors.ink,
                          fontSize: 13,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        runSpacing: 10,
                        children: [
                          if (range.isNotEmpty) ...[
                            MosiPill(label: range, color: theme.fg),
                            const SizedBox(width: 8),
                          ],
                          if (selected.playTime > 0) ...[
                            MosiPill(
                              label: '${selected.playTime}분',
                              color: theme.fg,
                            ),
                            const SizedBox(width: 8),
                          ],
                          const SizedBox(width: 6),
                          MosiButton(
                            label: context.l10n.details,
                            onPressed: () => onOpenDetail(selected),
                            background: theme.btnBg,
                            foreground: theme.btnFg,
                            shadowColor: theme.deep,
                            height: 48,
                            fontSize: 15,
                            radius: 6,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
