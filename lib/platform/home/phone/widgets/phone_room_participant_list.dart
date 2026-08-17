import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
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
              final accent = _parseAccent(player.accentColor);
              final isMe = player.uid == currentUid;
              return Container(
                height: compact ? 46 : 52,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: isMe ? colors.primarySoft : colors.surface,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: isMe ? colors.primary : colors.border,
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: compact ? 14 : 16,
                      backgroundColor: accent.withValues(alpha: 0.12),
                      backgroundImage: player.profileImageUrl.isEmpty
                          ? null
                          : NetworkImage(player.profileImageUrl),
                      child: player.profileImageUrl.isEmpty
                          ? Text(
                              player.nickname.isEmpty
                                  ? '?'
                                  : player.nickname.substring(0, 1),
                              style: TextStyle(
                                color: accent,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            )
                          : null,
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
                    if (isMe)
                      Text(
                        '나',
                        style: TextStyle(
                          color: colors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
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

Color _parseAccent(String value) {
  final hex = value.replaceFirst('#', '');
  final parsed = int.tryParse(hex, radix: 16);
  return parsed == null ? const Color(0xFF6557D2) : Color(0xFF000000 | parsed);
}
