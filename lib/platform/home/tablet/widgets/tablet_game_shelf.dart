import 'dart:async';
import 'dart:math' as math;

import 'package:project00/platform/localization/platform_localizations.dart';
import 'package:flutter/material.dart';
import 'package:game_kit/localization/game_locale.dart';
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
                        ? GameLocale.select(
                            ko: '지금 $playerCount명이 할 수 있는 게임이 없어요',
                            en: 'No games support $playerCount players right now',
                            zhHans: '目前没有适合 $playerCount 人的游戏',
                            zhHant: '目前沒有適合 $playerCount 人的遊戲',
                          )
                        : GameLocale.select(
                            ko: '선반에 게임이 없어요',
                            en: 'There are no games on the shelf',
                            zhHans: '书架上没有游戏',
                            zhHant: '書架上沒有遊戲',
                          ),
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
  final supported = game.id == 'yut'
      ? null
      : roomProvider.gameCatalog.find(game.id)?.supportedPlayerCounts;
  if (supported != null) return supported.contains(count);
  final min = game.id == 'yut'
      ? 2
      : game.minPlayers > 0
      ? game.minPlayers
      : 2;
  final max = game.id == 'yut'
      ? 4
      : game.maxPlayers > 0
      ? game.maxPlayers
      : 99;
  return count >= min && count <= max;
}

/// 시안의 인원 표기('2–6명', '4명 · 6명')입니다.
String gamePlayerRangeLabel(GameInfo game, RoomProvider roomProvider) {
  final supported = game.id == 'yut'
      ? null
      : roomProvider.gameCatalog.find(game.id)?.supportedPlayerCounts;
  if (supported != null) {
    return supported
        .map(
          (n) => GameLocale.select(
            ko: '$n명',
            en: '$n players',
            zhHans: '$n 人',
            zhHant: '$n 人',
          ),
        )
        .join(' · ');
  }
  final minPlayers = game.id == 'yut' ? 2 : game.minPlayers;
  final maxPlayers = game.id == 'yut' ? 4 : game.maxPlayers;
  if (minPlayers > 0 && maxPlayers > 0) {
    return GameLocale.select(
      ko: '$minPlayers–$maxPlayers명',
      en: '$minPlayers–$maxPlayers players',
      zhHans: '$minPlayers–$maxPlayers 人',
      zhHant: '$minPlayers–$maxPlayers 人',
    );
  }
  if (game.minPlayers > 0) {
    return GameLocale.select(
      ko: '${game.minPlayers}명부터',
      en: '${game.minPlayers}+ players',
      zhHans: '${game.minPlayers} 人起',
      zhHant: '${game.minPlayers} 人起',
    );
  }
  if (game.maxPlayers > 0) {
    return GameLocale.select(
      ko: '최대 ${game.maxPlayers}명',
      en: 'Up to ${game.maxPlayers}',
      zhHans: '最多 ${game.maxPlayers} 人',
      zhHant: '最多 ${game.maxPlayers} 人',
    );
  }
  return '';
}

/// 시작할 수 없을 때 보여 줄 안내입니다. 시작할 수 있으면 null입니다.
String? gameCannotStartMessage(
  GameInfo game,
  int count,
  RoomProvider roomProvider,
) {
  if (isGamePlayableWith(game, count, roomProvider)) return null;
  final supported = game.id == 'yut'
      ? null
      : roomProvider.gameCatalog.find(game.id)?.supportedPlayerCounts;
  if (supported != null) {
    return GameLocale.select(
      ko: '${supported.join('명이나 ')}명이 모이면 시작할 수 있어요 · 지금 $count명',
      en: 'Starts with ${supported.join(' or ')} players · $count now',
      zhHans: '需要 ${supported.join(' 或 ')} 人开始 · 当前 $count 人',
      zhHant: '需要 ${supported.join(' 或 ')} 人開始 · 目前 $count 人',
    );
  }
  final min = game.id == 'yut'
      ? 2
      : game.minPlayers > 0
      ? game.minPlayers
      : 2;
  if (count < min) {
    return GameLocale.select(
      ko: '$min명부터 시작할 수 있어요 · 지금 $count명',
      en: 'Needs at least $min players · $count now',
      zhHans: '至少需要 $min 人 · 当前 $count 人',
      zhHant: '至少需要 $min 人 · 目前 $count 人',
    );
  }
  return GameLocale.select(
    ko: '최대 ${game.id == 'yut' ? 4 : game.maxPlayers}명까지 함께할 수 있어요 · 지금 $count명',
    en: 'Supports up to ${game.id == 'yut' ? 4 : game.maxPlayers} players · $count now',
    zhHans: '最多支持 ${game.id == 'yut' ? 4 : game.maxPlayers} 人 · 当前 $count 人',
    zhHant: '最多支援 ${game.id == 'yut' ? 4 : game.maxPlayers} 人 · 目前 $count 人',
  );
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
          ? GameLocale.select(
              ko: '참가자가 입장하면 인원별로 볼 수 있어요',
              en: 'Player filters appear after someone joins',
              zhHans: '有玩家加入后可按人数筛选',
              zhHant: '有玩家加入後可按人數篩選',
            )
          : GameLocale.select(
              ko: '지금 $playerCount명이 할 수 있는 게임만 보기',
              en: 'Show games for $playerCount players',
              zhHans: '仅显示适合 $playerCount 人的游戏',
              zhHant: '僅顯示適合 $playerCount 人的遊戲',
            ),
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
                key: const Key('playable-filter-track'),
                duration: const Duration(milliseconds: 180),
                width: 44,
                height: 26,
                padding: const EdgeInsets.all(3),
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: value ? theme.btnBg : Colors.transparent,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: fg, width: 2),
                ),
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: value ? theme.btnFg : fg,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: onChanged == null
                            ? GameLocale.select(
                                ko: '참가자가 입장하면 인원별로 보기',
                                en: 'Filter by players after someone joins',
                                zhHans: '有玩家加入后按人数筛选',
                                zhHant: '有玩家加入後按人數篩選',
                              )
                            : GameLocale.select(
                                ko: '지금 $playerCount명이 할 수 있는 게임만',
                                en: 'Games for $playerCount players',
                                zhHans: '适合 $playerCount 人的游戏',
                                zhHant: '適合 $playerCount 人的遊戲',
                              ),
                        style: onChanged == null
                            ? null
                            : const TextStyle(fontWeight: FontWeight.w700),
                      ),
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
    final displayName = selected.localizedName(Localizations.localeOf(context));
    final englishName = selected.englishName;
    final hasRoom = roomProvider.roomCode != null;
    final cannotStart = hasRoom
        ? gameCannotStartMessage(selected, playerCount, roomProvider)
        : null;
    final range = gamePlayerRangeLabel(selected, roomProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 640;
        final coverWidth = compact ? 200.0 : 240.0;
        final titleSize = compact ? 32.0 : 40.0;
        final englishSize = compact ? 14.0 : 16.0;
        final descriptionSize = compact ? 16.0 : 18.0;
        final pillSize = compact ? 14.0 : 15.0;
        final buttonHeight = compact ? 52.0 : 56.0;
        final buttonSize = compact ? 17.0 : 18.0;
        // 아래 소개를 먼저 크게 확보하고 선반 그림이 남은 높이에 맞춰 줄어들게
        // 합니다. 글자가 큰 기기에서는 책보다 읽을 문구를 우선합니다. 마지막
        // 안전장치인 MosiFitHeight는 아주 작은 창이나 긴 번역에서만 작동합니다.
        final textScale = MediaQuery.textScalerOf(context).scale(100) / 100;
        final infoHeight =
            (compact ? 240.0 : 270.0) * textScale.clamp(1.0, 1.3).toDouble();
        final shelfHeight = math.max(
          (coverWidth * 4 / 3 + 24) * .42,
          constraints.maxHeight - infoHeight - 20,
        );
        return Column(
          children: [
            // 책 표지·책등 글자는 그림의 일부라 기기 글자 크기를 따르지 않습니다.
            MediaQuery.withNoTextScaling(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: shelfHeight),
                child: TabletBookCarousel(
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
              ),
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
            // 아래 소개는 스크롤하지 않습니다. 문구가 길거나(파이널콜처럼 시작
            // 인원 안내가 붙을 때) 기기 글자가 커도 자리에 맞춰 조금 줄여 이름·
            // 설명·버튼이 한 번에 다 보이게 합니다.
            Expanded(
              child: MosiFitHeight(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          displayName,
                          key: const Key('shelf-info-title'),
                          maxLines: 1,
                          style: MosiFonts.sans(
                            locale: Localizations.maybeLocaleOf(context),
                            size: titleSize,
                            weight: FontWeight.w700,
                            color: theme.fg,
                            letterSpacing: -1,
                            height: 1.08,
                          ),
                        ),
                      ),
                    ),
                    if (englishName.toUpperCase() !=
                        displayName.toUpperCase()) ...[
                      const SizedBox(height: 7),
                      SizedBox(
                        width: double.infinity,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            englishName,
                            key: const Key('shelf-info-english-name'),
                            maxLines: 1,
                            style: MosiFonts.grotesk(
                              locale: Localizations.maybeLocaleOf(context),
                              size: englishSize,
                              color: art.id == 'liars_poker'
                                  ? theme.accA
                                  : theme.accB,
                              letterSpacing: compact ? 2.4 : 3,
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (selected
                        .localizedDescription(Localizations.localeOf(context))
                        .isNotEmpty) ...[
                      const SizedBox(height: 8),
                      // 줄 수를 막지 않고 칸에 맞춰 함께 줄여 끝까지 보여 줍니다.
                      Text(
                        selected.localizedDescription(
                          Localizations.localeOf(context),
                        ),
                        key: const Key('shelf-info-description'),
                        textAlign: TextAlign.center,
                        style: MosiFonts.sans(
                          locale: Localizations.maybeLocaleOf(context),
                          size: descriptionSize,
                          color: theme.fg,
                          height: 1.3,
                        ),
                      ),
                    ],
                    GameStartHint(message: cannotStart),
                    const SizedBox(height: 14),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 10,
                      runSpacing: 12,
                      children: [
                        if (range.isNotEmpty) ...[
                          MosiPill(
                            label: range,
                            color: theme.fg,
                            fontSize: pillSize,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 13,
                              vertical: 7,
                            ),
                          ),
                        ],
                        if (selected.playTime > 0) ...[
                          MosiPill(
                            label: GameLocale.select(
                              ko: '${selected.playTime}분',
                              en: '${selected.playTime} min',
                              zhHans: '${selected.playTime} 分钟',
                              zhHant: '${selected.playTime} 分鐘',
                            ),
                            color: theme.fg,
                            fontSize: pillSize,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 13,
                              vertical: 7,
                            ),
                          ),
                        ],
                        MosiButton(
                          label: context.l10n.viewDescription,
                          onPressed: () => onOpenDetail(selected),
                          background: theme.btnBg,
                          foreground: theme.btnFg,
                          shadowColor: theme.deep,
                          height: buttonHeight,
                          fontSize: buttonSize,
                          radius: 6,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// '2명부터 시작할 수 있어요' 같은 시작 안내입니다.
///
/// 갑자기 나타나 아래 요소를 확 밀지 않도록, 먼저 자리가 부드럽게 열리며 아래
/// 요소를 밀어낸 뒤 알약이 조금 늦게 아래에서 떠오르며 나타납니다. 사라질 때는
/// 같은 움직임이 거꾸로 일어납니다(알약이 먼저 흐려지고 자리가 닫힘).
class GameStartHint extends StatefulWidget {
  const GameStartHint({super.key, required this.message});

  final String? message;

  @override
  State<GameStartHint> createState() => _GameStartHintState();
}

class _GameStartHintState extends State<GameStartHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  /// 사라지는 동안에도 마지막 문구를 그려야 해서 따로 기억합니다.
  String? _shown;

  @override
  void initState() {
    super.initState();
    _shown = widget.message;
    if (_shown != null) _controller.value = 1;
  }

  @override
  void didUpdateWidget(covariant GameStartHint oldWidget) {
    super.didUpdateWidget(oldWidget);
    final message = widget.message;
    if (message != null) _shown = message;
    final still = MediaQuery.disableAnimationsOf(context);
    if (message == null) {
      still ? _controller.value = 0 : unawaited(_controller.reverse());
    } else {
      still ? _controller.value = 1 : unawaited(_controller.forward());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) {
      final shown = _shown;
      if (shown == null || _controller.value == 0) {
        return const SizedBox.shrink();
      }
      // 자리는 앞 60%에서 열리고, 알약은 35% 뒤부터 떠오릅니다.
      final room = const Interval(
        0,
        .6,
        curve: Curves.easeOutCubic,
      ).transform(_controller.value);
      final pill = const Interval(
        .35,
        1,
        curve: Curves.easeOutCubic,
      ).transform(_controller.value);
      return ClipRect(
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: room,
          child: Opacity(
            opacity: pill,
            child: Transform.translate(
              offset: Offset(0, 12 * (1 - pill)),
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                // 지원 인원 문구가 긴 언어·큰 글자 설정에서도 한 줄을 유지하되,
                // 가용 폭을 넘는 경우에만 알약 전체를 비율로 줄입니다.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: MosiPill(
                    label: shown,
                    background: MosiColors.sun,
                    borderColor: MosiColors.ink,
                    fontSize: 15,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
