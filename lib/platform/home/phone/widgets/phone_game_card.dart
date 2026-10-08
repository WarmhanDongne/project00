import 'package:flutter/material.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:game_kit/mosi_ui/mosi_game_art.dart';
import 'package:project00/platform/home/gamelist/models/game_info.dart';
import 'package:project00/platform/widgets/platform_components.dart';

/// 휴대폰 홈의 게임 카드입니다: 상자 표지 + 이름 + 인원·시간 + 소개.
class PhoneGameCard extends StatelessWidget {
  final GameInfo gameInfo;
  const PhoneGameCard({super.key, required this.gameInfo, this.inset = true});

  final bool inset;

  @override
  Widget build(BuildContext context) {
    final known = MosiGameArt.isKnown(gameInfo.id);
    final art = MosiGameArt.of(gameInfo.id, fallbackName: gameInfo.name);
    return Padding(
      padding: EdgeInsets.fromLTRB(inset ? 20 : 0, 0, inset ? 26 : 6, 16),
      child: MosiBox(
        padding: const EdgeInsets.all(12),
        shadowOffset: 6,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MosiGameCover(
              gameId: gameInfo.id,
              width: 84,
              shadow: 0,
              fallbackName: gameInfo.name,
              fallbackImageUrl: gameInfo.imageUrl,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    known ? art.koreanName : gameInfo.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MosiFonts.sans(
                      size: 18,
                      weight: FontWeight.w700,
                      color: MosiColors.navy,
                    ),
                  ),
                  if (known)
                    Text(
                      art.englishName,
                      style: MosiFonts.grotesk(
                        size: 10,
                        color: MosiColors.violet,
                        letterSpacing: 2,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: [
                      if (gameInfo.playTime > 0)
                        PlatformTag(label: '${gameInfo.playTime}분'),
                      if (gameInfo.minPlayers > 0)
                        PlatformTag(
                          label:
                              '${gameInfo.minPlayers}–${gameInfo.maxPlayers}명',
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    gameInfo.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: MosiFonts.sans(
                      size: 12,
                      color: MosiColors.muted,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
