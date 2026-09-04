import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:project00/platform/home/room/models/room_character.dart';
import 'package:project00/platform/home/room/models/room_player.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';
import 'package:project00/platform/home/room/services/room_common.dart';
import 'package:project00/platform/theme/platform_theme.dart';
import 'package:project00/platform/widgets/platform_components.dart';
import 'package:qr_flutter/qr_flutter.dart';

//=======================태블릿 방 패널==============================
const _playerMotionDuration = Duration(milliseconds: 260);

class TabletRoomPanel extends StatefulWidget {
  const TabletRoomPanel({super.key, required this.provider});

  final RoomProvider provider;

  @override
  State<TabletRoomPanel> createState() => _TabletRoomPanelState();
}

class _TabletRoomPanelState extends State<TabletRoomPanel> {
  Timer? _lastPlayerExitTimer;
  late bool _hadPlayers;
  late bool _showActiveRoom;

  RoomProvider get provider => widget.provider;

  @override
  void initState() {
    super.initState();
    _hadPlayers = provider.players.isNotEmpty;
    _showActiveRoom = _hadPlayers;
    provider.addListener(_handleRoomChange);
  }

  @override
  void didUpdateWidget(covariant TabletRoomPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.provider, provider)) return;
    oldWidget.provider.removeListener(_handleRoomChange);
    _lastPlayerExitTimer?.cancel();
    _hadPlayers = provider.players.isNotEmpty;
    _showActiveRoom = _hadPlayers;
    provider.addListener(_handleRoomChange);
  }

  void _handleRoomChange() {
    final hasRoom = provider.roomCode != null;
    final hasPlayers = provider.players.isNotEmpty;
    if (!hasRoom) {
      _lastPlayerExitTimer?.cancel();
      _hadPlayers = false;
      _showActiveRoom = false;
      if (mounted) setState(() {});
      return;
    }
    if (hasPlayers) {
      _lastPlayerExitTimer?.cancel();
      _hadPlayers = true;
      _showActiveRoom = true;
      if (mounted) setState(() {});
      return;
    }
    if (_hadPlayers) {
      // 마지막 사람도 오른쪽으로 빠져나간 뒤 초대 화면으로
      // 돌아가야 합니다. 즉시 교체하면 퇴장 애니메이션이 사라집니다.
      _hadPlayers = false;
      _showActiveRoom = true;
      _lastPlayerExitTimer?.cancel();
      _lastPlayerExitTimer = Timer(_playerMotionDuration, () {
        if (!mounted ||
            provider.roomCode == null ||
            provider.players.isNotEmpty) {
          return;
        }
        setState(() => _showActiveRoom = false);
      });
      if (mounted) setState(() {});
      return;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _lastPlayerExitTimer?.cancel();
    provider.removeListener(_handleRoomChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final code = provider.roomCode;
    if (code == null) return _EmptyRoom(provider: provider);
    if (!_showActiveRoom) {
      return _InvitationRoom(provider: provider, roomCode: code);
    }
    return _ActiveRoom(
      provider: provider,
      roomCode: code,
      players: List<RoomPlayer>.unmodifiable(provider.players),
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
            painter: _DashedBorderPainter(color: colors.border, radius: radius),
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
  const _DashedBorderPainter({required this.color, required this.radius});

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
          const Spacer(flex: 2),
          Flexible(flex: 8, child: RoomQrCard(roomCode: roomCode, size: 240)),
          const Spacer(flex: 1),
          Text(
            '참여 코드',
            style: TextStyle(color: colors.textMuted, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Flexible(
            flex: 2,
            child: _CopyableRoomCode(roomCode: roomCode, fontSize: 32),
          ),
          const Spacer(flex: 1),
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
          if (provider.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                provider.errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
          PlatformButton(
            label: provider.isLoading ? '초기화 중...' : '초기화',
            style: PlatformButtonStyle.secondary,
            onPressed: provider.isLoading ? null : provider.closeRoom,
          ),
        ],
      ),
    );
  }
}

class _ActiveRoom extends StatelessWidget {
  const _ActiveRoom({
    required this.provider,
    required this.roomCode,
    required this.players,
  });

  final RoomProvider provider;
  final String roomCode;
  final List<RoomPlayer> players;

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
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
                onPressed: provider.isLoading
                    ? null
                    : () {
                        if (!provider.isRemovingAnyPlayer) {
                          unawaited(provider.closeRoom());
                        }
                      },
              ),
            ),
          ),
        ),
        Expanded(
          child: _AnimatedPlayerList(
            provider: provider,
            players: players,
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
              Tooltip(
                message: 'QR 코드 확대',
                child: Semantics(
                  button: true,
                  label: 'QR 코드 확대',
                  child: InkWell(
                    key: const Key('active-room-qr-expand'),
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _showExpandedQr(context, roomCode),
                    child: RoomQrCard(roomCode: roomCode, size: 92),
                  ),
                ),
              ),
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

class _AnimatedPlayerList extends StatefulWidget {
  const _AnimatedPlayerList({required this.provider, required this.players});

  final RoomProvider provider;
  final List<RoomPlayer> players;

  @override
  State<_AnimatedPlayerList> createState() => _AnimatedPlayerListState();
}

class _AnimatedPlayerListState extends State<_AnimatedPlayerList> {
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  late List<RoomPlayer> _players;

  @override
  void initState() {
    super.initState();
    _players = List<RoomPlayer>.of(widget.players);
  }

  @override
  void didUpdateWidget(covariant _AnimatedPlayerList oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPlayers(widget.players);
  }

  void _syncPlayers(List<RoomPlayer> nextPlayers) {
    final nextUids = nextPlayers.map((player) => player.uid).toSet();

    // 퇴장은 인덱스가 바뀌지 않도록 뒤에서부터 뺀니다.
    for (var index = _players.length - 1; index >= 0; index -= 1) {
      final player = _players[index];
      if (nextUids.contains(player.uid)) continue;
      _players.removeAt(index);
      _listKey.currentState?.removeItem(
        index,
        (context, animation) => _PlayerExitTransition(
          playerUid: player.uid,
          animation: animation,
          child: _buildPlayerTile(player),
        ),
        duration: _playerMotionDuration,
      );
    }

    final currentUids = _players.map((player) => player.uid).toSet();
    for (var index = 0; index < nextPlayers.length; index += 1) {
      final player = nextPlayers[index];
      if (currentUids.contains(player.uid)) continue;
      final insertionIndex = math.min(index, _players.length);
      _players.insert(insertionIndex, player);
      currentUids.add(player.uid);
      _listKey.currentState?.insertItem(
        insertionIndex,
        duration: _playerMotionDuration,
      );
    }

    // 연결 상태·NEW 시간·삭제 로딩 같은 기존 항목의 최신 값도
    // 반영합니다. 인원수는 위 insert/remove와 이미 맞습니다.
    _players = List<RoomPlayer>.of(nextPlayers);
  }

  Widget _buildPlayerTile(RoomPlayer player) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: _PlayerTile(
        key: ValueKey('room-player-${player.uid}'),
        player: player,
        isRemoving: widget.provider.isRemovingPlayer(player.uid),
        onRemove: () => unawaited(widget.provider.removePlayer(player.uid)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedList(
      key: _listKey,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      initialItemCount: _players.length,
      itemBuilder: (context, index, animation) {
        final player = _players[index];
        return SizeTransition(
          sizeFactor: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ),
          axisAlignment: -1,
          child: _PlayerEntranceTransition(
            key: ValueKey('room-player-entrance-${player.uid}'),
            playerUid: player.uid,
            child: _buildPlayerTile(player),
          ),
        );
      },
    );
  }
}

class _PlayerEntranceTransition extends StatelessWidget {
  const _PlayerEntranceTransition({
    super.key,
    required this.playerUid,
    required this.child,
  });

  final String playerUid;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: _playerMotionDuration,
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          key: ValueKey('room-player-motion-$playerUid'),
          offset: Offset(28 * (1 - value), 0),
          child: child,
        ),
      ),
    );
  }
}

class _PlayerExitTransition extends StatelessWidget {
  const _PlayerExitTransition({
    required this.playerUid,
    required this.animation,
    required this.child,
  });

  final String playerUid;
  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return SizeTransition(
      sizeFactor: curved,
      axisAlignment: -1,
      child: AnimatedBuilder(
        animation: curved,
        child: child,
        builder: (context, child) => Opacity(
          opacity: curved.value,
          child: Transform.translate(
            key: ValueKey('room-player-motion-$playerUid'),
            offset: Offset(28 * (1 - curved.value), 0),
            child: child,
          ),
        ),
      ),
    );
  }
}

Future<void> _showExpandedQr(BuildContext context, String roomCode) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _ExpandedRoomQrDialog(roomCode: roomCode),
  );
}

class _ExpandedRoomQrDialog extends StatelessWidget {
  const _ExpandedRoomQrDialog({required this.roomCode});

  final String roomCode;

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    final shortestSide = MediaQuery.sizeOf(context).shortestSide;
    final qrSize = (shortestSide * 0.52).clamp(240.0, 360.0);
    return Dialog(
      key: const Key('expanded-room-qr-dialog'),
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 420,
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x55000000),
                blurRadius: 30,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton.filledTonal(
                    tooltip: 'QR 확대 닫기',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ),
                const SizedBox(height: 8),
                RoomQrCard(
                  key: const Key('expanded-room-qr'),
                  roomCode: roomCode,
                  size: qrSize,
                ),
                const SizedBox(height: 18),
                Text(
                  '참여 코드',
                  style: TextStyle(color: colors.textMuted, fontSize: 14),
                ),
                const SizedBox(height: 4),
                _CopyableRoomCode(
                  roomCode: roomCode,
                  fontSize: 64,
                  alignment: Alignment.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'QR을 스캔하거나 참여 코드를 눌러 복사하세요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.textMuted, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerTile extends StatefulWidget {
  const _PlayerTile({
    super.key,
    required this.player,
    required this.isRemoving,
    required this.onRemove,
  });

  final RoomPlayer player;
  final bool isRemoving;
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
          SizedBox(
            width: 50,
            height: 50,
            child: Image.asset(
              roomCharacterAssetPath(player.characterId),
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.nickname,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
                if (!player.isConnected)
                  Text(
                    '연결 끊김',
                    key: ValueKey('disconnected-player-${player.uid}'),
                    style: TextStyle(
                      color: colors.danger,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
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
              onPressed: widget.isRemoving ? null : widget.onRemove,
              icon: widget.isRemoving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.close, size: 25, color: colors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

/// 참여 코드 QR을 정사각형 카드로 그립니다.
///
/// [size]는 최대 한 변이고, 부모가 더 좁으면 그만큼 줄어듭니다.
///
/// 이 위젯은 **부모가 크기를 제한해 주지 않아도** 스스로 정사각형을 만듭니다.
/// 예전에는 `AspectRatio`를 썼는데, 활성 방 화면에서 이 카드가 Column 안의
/// Row 직속 자식이라 가로·세로가 모두 무한이었고 그때마다
/// `RenderAspectRatio has unbounded constraints`로 화면이 통째로 죽었습니다.
/// 방을 만든 직후에는 초대 화면(Flexible 안이라 높이가 유한)이라 멀쩡하다가,
/// 누군가 입장해 활성 방 화면으로 바뀌는 순간 터졌습니다.
class RoomQrCard extends StatelessWidget {
  const RoomQrCard({super.key, required this.roomCode, required this.size});

  final String roomCode;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    return LayoutBuilder(
      builder: (context, constraints) {
        // 부모가 준 여유와 요청 크기 중 작은 쪽으로 한 변을 정합니다.
        // 무한 제약은 여유가 없다는 뜻이 아니므로 요청 크기를 그대로 씁니다.
        final available = math.min(constraints.maxWidth, constraints.maxHeight);
        final side = available.isFinite ? math.min(size, available) : size;
        return SizedBox(
          width: side,
          height: side,
          child: Container(
            padding: EdgeInsets.all(side * 0.08),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: colors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: QrImageView(data: roomCode, padding: EdgeInsets.zero),
          ),
        );
      },
    );
  }
}

class _CopyableRoomCode extends StatelessWidget {
  const _CopyableRoomCode({
    required this.roomCode,
    required this.fontSize,
    this.alignment = Alignment.centerLeft,
  });

  final String roomCode;
  final double fontSize;
  final Alignment alignment;

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
        alignment: alignment,
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
