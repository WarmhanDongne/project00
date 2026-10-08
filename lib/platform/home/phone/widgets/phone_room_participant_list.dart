import 'package:flutter/material.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:project00/platform/home/room/models/room_player.dart';

//=======================휴대폰 참가자 목록==============================
class PhoneRoomParticipantList extends StatelessWidget {
  const PhoneRoomParticipantList({
    super.key,
    required this.players,
    this.compact = false,
  });

  final List<RoomPlayer> players;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '참여자',
              style: MosiFonts.sans(
                size: 16,
                weight: FontWeight.w700,
                color: MosiColors.navy,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${players.length}명',
              style: MosiFonts.grotesk(size: 14, color: MosiColors.violet),
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
                '아직 참가자가 없습니다.',
                style: MosiFonts.sans(size: 13, color: MosiColors.muted),
              ),
            ),
          )
        else
          MosiBox(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 10 : 14,
              vertical: compact ? 6 : 10,
            ),
            shadowOffset: 5,
            child: Column(
              children: [
                for (final (index, player) in players.indexed) ...[
                  if (index > 0) const SizedBox(height: 8),
                  SizedBox(
                    height: compact ? 36 : 46,
                    child: Row(
                      children: [
                        MosiFace(
                          characterId: player.characterId,
                          size: compact ? 30 : 38,
                          ring: true,
                        ),
                        SizedBox(width: compact ? 10 : 12),
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
                          const MosiPill(
                            label: '연결 끊김',
                            color: MosiColors.red,
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
