import 'package:flutter/material.dart';
import 'package:project00/platform/home/gamelist/models/game_info.dart';
import 'package:project00/platform/theme/platform_theme.dart';
import 'package:project00/platform/widgets/platform_components.dart';

class PhoneGameCard extends StatelessWidget {
  // 게임 포스터와 설명을 한 쌍으로 묶어 위젯으로 만듦.

  final GameInfo gameInfo;
  const PhoneGameCard({super.key, required this.gameInfo, this.inset = true});

  final bool inset;

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    return Padding(
      padding: EdgeInsets.fromLTRB(inset ? 16 : 0, 0, inset ? 16 : 0, 12),
      child: PlatformPanel(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: gameInfo.imageUrl.isEmpty
                  ? Container(
                      width: 90,
                      height: 118,
                      color: colors.surfaceMuted,
                      alignment: Alignment.center,
                      child: const Icon(Icons.image_outlined),
                    )
                  : Image.network(
                      gameInfo.imageUrl,
                      width: 90,
                      height: 118,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 90,
                          height: 118,
                          color: colors.surfaceMuted,
                          alignment: Alignment.center,
                          child: const Icon(Icons.broken_image_outlined),
                        );
                      },
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    gameInfo.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: [
                      PlatformTag(label: '${gameInfo.playTime}분'),
                      PlatformTag(
                        label: '${gameInfo.minPlayers}~${gameInfo.maxPlayers}인',
                      ),
                      for (final genre in gameInfo.genres.take(2))
                        PlatformTag(label: genre, highlighted: true),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    gameInfo.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: 11,
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
