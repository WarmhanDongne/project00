import 'dart:async';

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
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
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
    const double radius = 38.0;
    
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          const _PanelHeader(title: '구성원 목록'),
          const Spacer(),
          CustomPaint(
            painter: _DashedBorderPainter(
              color: colors.border,
              radius: radius,
            ),
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: colors.surfaceMuted,
                borderRadius: BorderRadius.circular(radius),
              ),
              alignment: Alignment.center,
              child: Text(
                'empty art',
                style: TextStyle(
                  color: colors.textMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '아직 아무도 없습니다',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          Text(
            '초대 코드를 띄우면 친구들이\n휴대폰으로 참여할 수 있습니다.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textMuted,
              fontSize: 14,
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

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({
    required this.color,
    required this.radius,
  });

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final RRect rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    final dashedPath = _createDashedPath(path);
    canvas.drawPath(dashedPath, paint);
  }

  Path _createDashedPath(Path source) {
    const dashLength = 8.0;
    const dashSpace = 6.0;
    final pathMetrics = source.computeMetrics();
    final dest = Path();
    for (final metric in pathMetrics) {
      double distance = 0.0;
      while (distance < metric.length) {
        dest.addPath(
          metric.extractPath(distance, distance + dashLength),
          Offset.zero,
        );
        distance += dashLength + dashSpace;
      }
    }
    return dest;
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
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
          _QrCard(roomCode: roomCode, size: 240),
          const SizedBox(height: 14),
          Text(
            '참여 코드',
            style: TextStyle(color: colors.textMuted, fontSize: 14),
          ),
          const SizedBox(height: 4),
          _CopyableRoomCode(roomCode: roomCode, fontSize: 32),
          const SizedBox(height: 12),
          Text(
            '모바일 앱에서 이 코드를 입력하면\n바로 참여합니다.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textMuted,
              fontSize: 13,
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
              width: 84,
              child: PlatformButton(
                label: '초기화',
                height: 40,
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
              onRemove: () => provider.removePlayer(players[index].uid),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Text(
            '최대 ${RoomLimits.defaultMaxPlayers}명 · 아래로 스크롤',
            style: TextStyle(color: colors.textMuted, fontSize: 13),
          ),
        ),
        Divider(height: 1, color: colors.border),
        Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              _QrCard(roomCode: roomCode, size: 92),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '참여 코드',
                      style: TextStyle(color: colors.textMuted, fontSize: 14),
                    ),
                    _CopyableRoomCode(roomCode: roomCode, fontSize: 34),
                    Text(
                      '늦게 온 친구도 바로 참여',
                      style: TextStyle(color: colors.textMuted, fontSize: 12),
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

class _PlayerTile extends StatefulWidget {
  const _PlayerTile({required this.player, required this.onRemove});

  final RoomPlayer player;
  final VoidCallback onRemove;

  @override
  State<_PlayerTile> createState() => _PlayerTileState();
}

class _PlayerTileState extends State<_PlayerTile> {
  Timer? _newBadgeTimer;
  bool _isNew = false;

  @override
  void initState() {
    super.initState();
    _scheduleNewBadge();
  }

  @override
  void didUpdateWidget(covariant _PlayerTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.player.joinedAt != widget.player.joinedAt) {
      _scheduleNewBadge();
    }
  }

  void _scheduleNewBadge() {
    _newBadgeTimer?.cancel();
    final remaining = widget.player.newBadgeRemainingAt(DateTime.now());
    _isNew = remaining > Duration.zero;
    if (!_isNew) return;
    _newBadgeTimer = Timer(remaining, () {
      if (mounted) setState(() => _isNew = false);
    });
  }

  @override
  void dispose() {
    _newBadgeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    final player = widget.player;
    final accent = _parseAccent(player.accentColor);
    return Container(
      height: 78,
      padding: const EdgeInsets.only(left: 12, right: 8),
      decoration: BoxDecoration(
        color: _isNew ? colors.dangerSoft : colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isNew ? colors.danger : colors.border,
          width: _isNew ? 1.6 : 1,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: accent.withValues(alpha: 0.13),
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
                      fontWeight: FontWeight.w900,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              player.nickname,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
            ),
          ),
          if (_isNew)
            Text(
              'NEW',
              style: TextStyle(
                color: colors.danger,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          const SizedBox(width: 8),
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
            ),
            child: IconButton(
              tooltip: '내보내기',
              onPressed: widget.onRemove,
              icon: Icon(Icons.close, size: 25, color: colors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

Color _parseAccent(String value) {
  final parsed = int.tryParse(value.replaceFirst('#', ''), radix: 16);
  return parsed == null ? const Color(0xFF6557D2) : Color(0xFF000000 | parsed);
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
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          roomCode,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}
