import 'package:flutter/material.dart';
import 'package:project00/platform/home/room/models/room_character.dart';
import 'package:project00/platform/home/room/models/room_player.dart';
import 'package:project00/platform/theme/platform_theme.dart';

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
    final colors = context.platformColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '참여자',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(width: 8),
            Text(
              '${players.length}명',
              style: TextStyle(
                color: colors.primary,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (players.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surfaceMuted,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '아직 참가자가 없습니다.',
              style: TextStyle(color: colors.textMuted, fontSize: 13),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: players.length,
            separatorBuilder: (_, _) => const SizedBox(height: 7),
            itemBuilder: (context, index) {
              final player = players[index];
              return Container(
                height: compact ? 46 : 52,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: compact ? 30 : 34,
                      height: compact ? 30 : 34,
                      child: Image.asset(
                        roomCharacterAssetPath(player.characterId),
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        player.nickname,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
