import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';
import 'package:project00/platform/home/room/services/room_common.dart';
import 'package:project00/platform/theme/platform_theme.dart';
import 'package:project00/platform/widgets/platform_components.dart';
import 'package:qr_flutter/qr_flutter.dart';

//=======================태블릿 방 패널==============================
class TabletRoomPanel extends StatelessWidget {
  const TabletRoomPanel({super.key, required this.provider});

  final RoomProvider provider;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: provider,
      builder: (context, _) {
        final code = provider.roomCode;
        if (code == null) return _EmptyRoom(provider: provider);
        if (provider.players.isEmpty) {
          return _InvitationRoom(provider: provider, roomCode: code);
        }
        return _ActiveRoom(provider: provider, roomCode: code);
      },
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class _EmptyRoom extends StatelessWidget {
  const _EmptyRoom({required this.provider});

  final RoomProvider provider;

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          const _PanelHeader(title: '구성원 목록'),
          const Spacer(),
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              color: colors.surfaceMuted,
              shape: BoxShape.circle,
              border: Border.all(
                color: colors.border,
                style: BorderStyle.solid,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.group_add_outlined,
              color: colors.textMuted,
              size: 30,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '아직 아무도 없습니다',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            '초대 코드를 띄우면 친구들이\n휴대폰으로 참여할 수 있습니다.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textMuted,
              fontSize: 12,
              height: 1.45,
            ),
          ),
          const Spacer(),
          PlatformButton(
            label: provider.isLoading ? '생성 중...' : '초대하기',
            onPressed: provider.isLoading ? null : provider.createRoom,
          ),
        ],
      ),
    );
  }
}

class _InvitationRoom extends StatelessWidget {
  const _InvitationRoom({required this.provider, required this.roomCode});

  final RoomProvider provider;
  final String roomCode;

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          const _PanelHeader(title: '초대하기'),
          const Spacer(),
          _QrCard(roomCode: roomCode, size: 150),
          const SizedBox(height: 14),
          Text(
            '참여 코드',
            style: TextStyle(color: colors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 4),
          _CopyableRoomCode(roomCode: roomCode, fontSize: 29),
          const SizedBox(height: 12),
          Text(
            '모바일 앱에서 이 코드를 입력하면\n바로 참여합니다.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textMuted,
              fontSize: 11,
              height: 1.45,
            ),
          ),
          const Spacer(),
          PlatformButton(
            label: '초기화',
            style: PlatformButtonStyle.secondary,
            onPressed: provider.isLoading ? null : provider.createRoom,
          ),
        ],
      ),
    );
  }
}

class _ActiveRoom extends StatelessWidget {
  const _ActiveRoom({required this.provider, required this.roomCode});

  final RoomProvider provider;
  final String roomCode;

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    final players = provider.players;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
          child: _PanelHeader(
            title: '현 인원  ${players.length}명',
            trailing: SizedBox(
              width: 72,
              child: PlatformButton(
                label: '초기화',
                height: 36,
                style: PlatformButtonStyle.secondary,
                onPressed: provider.isLoading ? null : provider.createRoom,
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: players.length,
            separatorBuilder: (_, _) => const SizedBox(height: 7),
            itemBuilder: (context, index) => _PlayerTile(
              player: players[index],
              isHost: index == 0,
              isNew: index == players.length - 1 && players.length > 1,
              onRemove: () => provider.removePlayer(players[index].uid),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Text(
            '최대 ${RoomLimits.defaultMaxPlayers}명 · 아래로 스크롤',
            style: TextStyle(color: colors.textMuted, fontSize: 10),
          ),
        ),
        Divider(height: 1, color: colors.border),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _QrCard(roomCode: roomCode, size: 64),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '참여 코드',
                      style: TextStyle(color: colors.textMuted, fontSize: 10),
                    ),
                    _CopyableRoomCode(roomCode: roomCode, fontSize: 24),
                    Text(
                      '늦게 온 친구도 바로 참여',
                      style: TextStyle(color: colors.textMuted, fontSize: 9),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlayerTile extends StatelessWidget {
  const _PlayerTile({
    required this.player,
    required this.isHost,
    required this.isNew,
    required this.onRemove,
  });

  final RoomPlayer player;
  final bool isHost;
  final bool isNew;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    return Container(
      height: 50,
      padding: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: isNew ? colors.warning : colors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: colors.primarySoft,
            backgroundImage: player.profileImageUrl.isEmpty
                ? null
                : NetworkImage(player.profileImageUrl),
            child: player.profileImageUrl.isEmpty
                ? Text(
                    player.nickname.isEmpty
                        ? '?'
                        : player.nickname.substring(0, 1),
                    style: TextStyle(color: colors.primary),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isHost ? '방장  ${player.nickname}' : player.nickname,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
          if (isNew)
            Text(
              'NEW',
              style: TextStyle(
                color: colors.danger,
                fontSize: 8,
                fontWeight: FontWeight.w900,
              ),
            ),
          IconButton(
            tooltip: '내보내기',
            visualDensity: VisualDensity.compact,
            onPressed: onRemove,
            icon: Icon(Icons.close, size: 17, color: colors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _QrCard extends StatelessWidget {
  const _QrCard({required this.roomCode, required this.size});

  final String roomCode;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.08),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: QrImageView(data: roomCode, padding: EdgeInsets.zero),
    );
  }
}

class _CopyableRoomCode extends StatelessWidget {
  const _CopyableRoomCode({required this.roomCode, required this.fontSize});

  final String roomCode;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: roomCode));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('방 코드가 복사되었습니다.')));
      },
      child: Text(
        roomCode,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}
