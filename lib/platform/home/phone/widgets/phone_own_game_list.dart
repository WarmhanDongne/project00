import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:game_kit/localization/game_locale.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:game_kit/mosi_ui/mosi_game_art.dart';
import 'package:project00/platform/home/gamelist/models/game_info.dart';
import 'package:project00/platform/localization/platform_localizations.dart';

class PhoneOwnGameList extends StatefulWidget {
  const PhoneOwnGameList({super.key, required this.games});

  final Future<List<GameInfo>> games;

  @override
  State<PhoneOwnGameList> createState() => _PhoneOwnGameListState();
}

class _PhoneOwnGameListState extends State<PhoneOwnGameList> {
  int _index = 0;
  double _drag = 0;

  @override
  Widget build(BuildContext context) => Expanded(
    child: FutureBuilder<List<GameInfo>>(
      future: widget.games,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: MosiColors.lime),
          );
        }
        final games = snapshot.data ?? const <GameInfo>[];
        if (snapshot.hasError || games.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                snapshot.hasError
                    ? GameLocale.select(
                        ko: '게임 목록을 불러오지 못했습니다.',
                        en: 'Could not load the game list.',
                        zhHans: '无法加载游戏列表。',
                        zhHant: '無法載入遊戲列表。',
                      )
                    : GameLocale.select(
                        ko: '등록된 게임이 없습니다.',
                        en: 'No games are registered.',
                        zhHans: '没有已登记的游戏。',
                        zhHant: '沒有已登記的遊戲。',
                      ),
                textAlign: TextAlign.center,
                style: MosiFonts.sans(color: MosiColors.white),
              ),
            ),
          );
        }
        final index = _index.clamp(0, games.length - 1);
        final game = games[index];
        final locale = Localizations.localeOf(context);
        final displayName = game.localizedName(locale);
        final englishName = game.englishName;
        void select(int next) {
          if (next >= 0 && next < games.length) setState(() => _index = next);
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final coverWidth = math
                .min(constraints.maxWidth * .43, constraints.maxHeight * .40)
                .clamp(90.0, 220.0);
            return SingleChildScrollView(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.l10n.ownedGames,
                            style: MosiFonts.sans(
                              size: 16,
                              weight: FontWeight.w700,
                              color: MosiColors.white,
                            ),
                          ),
                        ),
                        Text(
                          '${index + 1} / ${games.length}',
                          style: MosiFonts.grotesk(
                            size: 12,
                            color: MosiColors.white,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    key: const Key('phone-book-shelf'),
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragStart: (_) => _drag = 0,
                    onHorizontalDragUpdate: (event) => _drag += event.delta.dx,
                    onHorizontalDragEnd: (event) {
                      final movement = _drag.abs() > 30
                          ? _drag
                          : (event.primaryVelocity ?? 0) / 6;
                      if (movement.abs() > 30) {
                        select(index + (movement < 0 ? 1 : -1));
                      }
                    },
                    child: SizedBox(
                      height: coverWidth * 4 / 3 + 16,
                      width: double.infinity,
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          for (var offset = -2; offset <= 2; offset++)
                            if (offset != 0 &&
                                index + offset >= 0 &&
                                index + offset < games.length)
                              Positioned(
                                bottom: 0,
                                left:
                                    constraints.maxWidth / 2 +
                                    (offset > 0
                                        ? coverWidth / 2 +
                                              12 +
                                              (offset - 1) * 34
                                        : -coverWidth / 2 -
                                              36 +
                                              (offset + 1) * 34),
                                child: SizedBox(
                                  width: 26,
                                  height:
                                      coverWidth *
                                      (offset.abs() == 1 ? 1.2 : .68),
                                  child: FittedBox(
                                    fit: BoxFit.fill,
                                    child: MosiGameSpine(
                                      gameId: games[index + offset].id,
                                      fallbackName: games[index + offset].name,
                                      displayName: games[index + offset]
                                          .localizedName(locale),
                                      englishName:
                                          games[index + offset].englishName,
                                      onTap: () => select(index + offset),
                                    ),
                                  ),
                                ),
                              ),
                          AnimatedSwitcher(
                            duration: MediaQuery.disableAnimationsOf(context)
                                ? Duration.zero
                                : const Duration(milliseconds: 240),
                            child: MosiGameCover(
                              key: ValueKey(game.id),
                              gameId: game.id,
                              width: coverWidth,
                              fallbackName: game.name,
                              fallbackImageUrl: game.imageUrl,
                              displayName: displayName,
                              englishName: englishName,
                              shadow: 5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 8,
                    width: double.infinity,
                    child: ColoredBox(color: MosiColors.navy),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Text(
                      displayName,
                      textAlign: TextAlign.center,
                      style: MosiFonts.sans(
                        size: 25,
                        weight: FontWeight.w700,
                        color: MosiColors.white,
                      ),
                    ),
                  ),
                  if (englishName.toUpperCase() != displayName.toUpperCase())
                    Text(
                      englishName,
                      textAlign: TextAlign.center,
                      style: MosiFonts.grotesk(
                        size: 10,
                        weight: FontWeight.w700,
                        color: MosiColors.white,
                        letterSpacing: 3,
                      ),
                    ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: [
                      if (game.minPlayers > 0)
                        _BookTag(
                          GameLocale.select(
                            ko: '${game.minPlayers}–${game.maxPlayers}명',
                            en: '${game.minPlayers}–${game.maxPlayers} players',
                            zhHans: '${game.minPlayers}–${game.maxPlayers} 人',
                            zhHant: '${game.minPlayers}–${game.maxPlayers} 人',
                          ),
                        ),
                      if (game.playTime > 0)
                        _BookTag(
                          GameLocale.select(
                            ko: '${game.playTime}분',
                            en: '${game.playTime} min',
                            zhHans: '${game.playTime} 分钟',
                            zhHant: '${game.playTime} 分鐘',
                          ),
                        ),
                    ],
                  ),
                  Wrap(
                    alignment: WrapAlignment.center,
                    children: [
                      for (var i = 0; i < games.length; i++)
                        Semantics(
                          label: GameLocale.select(
                            ko: '${games[i].localizedName(locale)} 선택',
                            en: 'Select ${games[i].localizedName(locale)}',
                            zhHans: '选择 ${games[i].localizedName(locale)}',
                            zhHant: '選擇 ${games[i].localizedName(locale)}',
                          ),
                          selected: i == index,
                          button: true,
                          child: GestureDetector(
                            onTap: () => select(i),
                            behavior: HitTestBehavior.opaque,
                            child: SizedBox(
                              width: 32,
                              height: 44,
                              child: Center(
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  width: i == index ? 22 : 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: MosiColors.white.withValues(
                                      alpha: i == index ? 1 : .4,
                                    ),
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    ),
  );
}

class _BookTag extends StatelessWidget {
  const _BookTag(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      border: Border.all(color: MosiColors.white, width: 1.5),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      label,
      style: MosiFonts.sans(
        size: 12,
        weight: FontWeight.w700,
        color: MosiColors.white,
      ),
    ),
  );
}
