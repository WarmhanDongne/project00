import 'package:flutter/material.dart';
import 'package:game_kit/localization/game_locale.dart';
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
    final locale = Localizations.localeOf(context);
    final displayName = gameInfo.localizedName(locale);
    final description = gameInfo.localizedDescription(locale);
    final englishName = gameInfo.englishName;
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
              displayName: displayName,
              englishName: englishName,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MosiFonts.sans(
                      size: 18,
                      weight: FontWeight.w700,
                      color: MosiColors.navy,
                    ),
                  ),
                  if (englishName.toUpperCase() != displayName.toUpperCase())
                    Text(
                      englishName,
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
                        PlatformTag(
                          label: GameLocale.select(
                            ko: '${gameInfo.playTime}분',
                            en: '${gameInfo.playTime} min',
                            zhHans: '${gameInfo.playTime} 分钟',
                            zhHant: '${gameInfo.playTime} 分鐘',
                          ),
                        ),
                      if (gameInfo.minPlayers > 0)
                        PlatformTag(
                          label: GameLocale.select(
                            ko: '${gameInfo.minPlayers}–${gameInfo.maxPlayers}명',
                            en: '${gameInfo.minPlayers}–${gameInfo.maxPlayers} players',
                            zhHans:
                                '${gameInfo.minPlayers}–${gameInfo.maxPlayers} 人',
                            zhHant:
                                '${gameInfo.minPlayers}–${gameInfo.maxPlayers} 人',
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
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
