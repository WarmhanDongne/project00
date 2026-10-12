import 'package:flutter/material.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:game_kit/localization/game_locale.dart';
import 'package:project00/platform/home/room/models/room_player.dart';

//=======================휴대폰 참가자 목록==============================
class PhoneRoomParticipantList extends StatelessWidget {
  const PhoneRoomParticipantList({
    super.key,
    required this.players,
    this.compact = false,
    this.myUid,
  });

  final List<RoomPlayer> players;
  final bool compact;

  /// 이 휴대폰 사용자의 UID입니다. 해당 줄에 '나' 표시를 붙입니다.
  final String? myUid;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '참여자'.localized,
              style: MosiFonts.sans(
                size: 18,
                weight: FontWeight.w700,
                color: MosiColors.navy,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              GameLocale.select(
                ko: '${players.length}명',
                en: '${players.length} players',
                zhHans: '${players.length} 人',
                zhHant: '${players.length} 人',
              ),
              style: MosiFonts.grotesk(
                size: 14,
                weight: FontWeight.w700,
                color: MosiColors.violet,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (players.isEmpty)
          MosiDashedBorder(
            color: MosiColors.navyFaint,
            radius: 10,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: Text(
                '아직 참가자가 없습니다.'.localized,
                style: MosiFonts.sans(size: 13, color: MosiColors.muted),
              ),
            ),
          )
        else
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 10 : 14,
              vertical: compact ? 6 : 10,
            ),
            decoration: BoxDecoration(
              color: MosiColors.paper,
              border: Border.all(color: MosiColors.ink, width: 2),
              borderRadius: BorderRadius.circular(14),
            ),
            // 새 참가자는 작게 나타나 안착하고, 나간 자리는 접혀 남은 사람들이
            // 미끄러지듯 메웁니다(로비 연출 1번).
            child: MosiAnimatedItems<RoomPlayer>(
              items: players,
              keyOf: (player) => player.uid,
              spacing: 8,
              itemBuilder: (context, player) => SizedBox(
                height: compact ? 36 : 46,
                child: Row(
                  children: [
                    MosiFace(
                      characterId: player.characterId,
                      size: compact ? 30 : 38,
                      ring: true,
                    ),
                    SizedBox(width: compact ? 10 : 12),
                    if (player.uid == myUid) ...[
                      const _MeBadge(),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        player.nickname,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MosiFonts.sans(
                          size: compact ? 14 : 16,
                          weight: FontWeight.w700,
                          color: MosiColors.navy,
                        ),
                      ),
                    ),
                    if (!player.isConnected)
                      MosiPill(
                        label: '연결 끊김'.localized,
                        color: MosiColors.red,
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 목록에서 내 줄을 알려 주는 작은 표시입니다.
class _MeBadge extends StatelessWidget {
  const _MeBadge();

  @override
  Widget build(BuildContext context) => MosiPill(
    key: const Key('participant-me-badge'),
    label: '나'.localized,
    color: MosiColors.ink,
    background: MosiColors.lime,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
  );
}
