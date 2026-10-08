import 'dart:math' as math;

import 'package:flutter/material.dart';
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
                snapshot.hasError ? '게임 목록을 불러오지 못했습니다.' : '등록된 게임이 없습니다.',
                textAlign: TextAlign.center,
                style: MosiFonts.sans(color: MosiColors.white),
              ),
            ),
          );
        }
        final index = _index.clamp(0, games.length - 1);
        final game = games[index];
        final art = MosiGameArt.of(game.id, fallbackName: game.name);
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
                      MosiGameArt.isKnown(game.id) ? art.koreanName : game.name,
                      textAlign: TextAlign.center,
                      style: MosiFonts.sans(
                        size: 25,
                        weight: FontWeight.w700,
                        color: MosiColors.white,
                      ),
                    ),
                  ),
                  Text(
                    art.englishName,
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
                        _BookTag('${game.minPlayers}–${game.maxPlayers}명'),
                      if (game.playTime > 0) _BookTag('${game.playTime}분'),
                    ],
                  ),
                  Wrap(
                    alignment: WrapAlignment.center,
                    children: [
                      for (var i = 0; i < games.length; i++)
                        Semantics(
                          label: '${games[i].name} 선택',
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
