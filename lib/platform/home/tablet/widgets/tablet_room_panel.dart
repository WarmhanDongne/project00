import 'package:project00/platform/localization/platform_localizations.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';
import 'package:project00/platform/home/room/services/room_common.dart';
import 'package:qr_flutter/qr_flutter.dart';

//=======================태블릿 방 카드==============================
// 선반과 게임 상세 오른쪽에 같은 카드가 놓입니다: 위에 QR·방 코드, 가운데
// 플레이어 명단, 아래 시작 버튼.
const _playerMotionDuration = Duration(milliseconds: 260);

/// 새 참가자가 오른쪽 끝에서 미끄러져 들어오는 시간입니다. 자리가 먼저 벌어지고
/// 카드가 그 자리로 부드럽게 감속하며 들어옵니다.
const _playerEntranceDuration = Duration(milliseconds: 560);

/// 자리 벌어짐은 들어오기보다 짧게 끝내 카드가 빈자리로 미끄러져 들어가게 합니다.
const _playerSlotOpenDuration = Duration(milliseconds: 300);

class TabletRoomPanel extends StatefulWidget {
  const TabletRoomPanel({
    super.key,
    required this.provider,
    this.deep = MosiColors.navy,
    this.startBackground = MosiColors.lime,
    this.startForeground = MosiColors.navy,
    this.maxSlots,
    this.onStart,
    this.startLoading = false,
    this.qrSize = 132,
  });

  final RoomProvider provider;

  /// 카드 그림자 색입니다(선반 테마의 deep).
  final Color deep;
  final Color startBackground;
  final Color startForeground;

  /// 빈 자리를 몇 칸까지 그릴지 정합니다. null이면 빈 자리를 그리지 않습니다.
  final int? maxSlots;

  /// 시작 버튼을 눌렀을 때입니다. null이면 시작 버튼을 숨깁니다.
  final VoidCallback? onStart;
  final bool startLoading;
  final double qrSize;

  @override
  State<TabletRoomPanel> createState() => _TabletRoomPanelState();
}

class _TabletRoomPanelState extends State<TabletRoomPanel> {
  Timer? _lastPlayerExitTimer;
  late bool _hadPlayers;
  late bool _showActiveRoom;
  late final Set<String> _staticUids;

  RoomProvider get provider => widget.provider;

  @override
  void initState() {
    super.initState();
    _staticUids = provider.players.map((player) => player.uid).toSet();
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
    final Widget body;
    if (code == null) {
      body = _EmptyRoom(provider: provider);
    } else {
      final players = _showActiveRoom
          ? List<RoomPlayer>.unmodifiable(provider.players)
          : const <RoomPlayer>[];
      final activeCount = provider.players
          .where((player) => player.isActive && player.isPlayer)
          .length;
      body = _RoomBody(
        provider: provider,
        roomCode: code,
        players: players,
        showActiveRoom: _showActiveRoom,
        maxSlots: widget.maxSlots,
        qrSize: widget.qrSize,
        staticUids: _staticUids,
        start: widget.onStart == null
            ? null
            // 시작할 수 있게 되는 순간 한 번만 가볍게 들립니다(로비 연출 4번).
            : MosiReadyLift(
                ready: activeCount > 0,
                child: MosiButton(
                  key: const Key('room-start-button'),
                  label: activeCount == 0
                      ? context.l10n.waitingPlayers
                      : context.l10n.startWithPlayers(activeCount),
                  onPressed: activeCount == 0 ? null : widget.onStart,
                  loading: widget.startLoading,
                  background: widget.startBackground,
                  foreground: widget.startForeground,
                  borderColor: MosiColors.ink,
                  shadowColor: widget.deep,
                  shadowOffset: 5,
                  height: 56,
                  fontSize: 18,
                  expand: true,
                ),
              ),
      );
    }
    return MosiBox(
      padding: const EdgeInsets.all(20),
      shadowColor: widget.deep,
      child: DefaultTextStyle(
        style: MosiFonts.sans(
          locale: Localizations.maybeLocaleOf(context),
          color: MosiColors.navy,
        ),
        child: body,
      ),
    );
  }
}

//=======================방이 없을 때==============================
class _EmptyRoom extends StatelessWidget {
  const _EmptyRoom({required this.provider});

  final RoomProvider provider;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            MosiDashedBorder(
              radius: 8,
              child: SizedBox(
                width: 132,
                height: 132,
                child: Center(
                  child: Icon(
                    Icons.qr_code_2_rounded,
                    size: 56,
                    color: MosiColors.navy.withValues(alpha: 0.35),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'JOIN ROOM',
                    style: MosiFonts.grotesk(
                      locale: Localizations.maybeLocaleOf(context),
                      size: 12,
                      color: MosiColors.navy,
                      letterSpacing: 2.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.l10n.members,
                    style: MosiFonts.sans(
                      locale: Localizations.maybeLocaleOf(context),
                      size: 17,
                      weight: FontWeight.w700,
                      color: MosiColors.navy,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const MosiDashedDivider(),
        const Spacer(),
        Text(
          context.l10n.noPlayers,
          textAlign: TextAlign.center,
          style: MosiFonts.sans(
            locale: Localizations.maybeLocaleOf(context),
            size: 18,
            weight: FontWeight.w700,
            color: MosiColors.navy,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.roomInviteHint,
          textAlign: TextAlign.center,
          style: MosiFonts.sans(
            locale: Localizations.maybeLocaleOf(context),
            size: 14,
            color: MosiColors.muted,
            height: 1.45,
          ),
        ),
        const Spacer(),
        if (provider.errorMessage != null) ...[
          Text(
            provider.errorMessage!,
            key: const Key('room-create-error'),
            textAlign: TextAlign.center,
            style: MosiFonts.sans(
              locale: Localizations.maybeLocaleOf(context),
              size: 13,
              weight: FontWeight.w600,
              color: MosiColors.red,
            ),
          ),
          const SizedBox(height: 12),
        ],
        MosiButton(
          label: provider.isLoading
              ? context.l10n.creating
              : context.l10n.invite,
          onPressed: provider.isLoading ? null : provider.createRoom,
          height: 56,
          fontSize: 18,
          shadowOffset: 5,
          expand: true,
        ),
      ],
    );
  }
}

//=======================방이 열려 있을 때==============================
class _RoomBody extends StatelessWidget {
  const _RoomBody({
    required this.provider,
    required this.roomCode,
    required this.players,
    required this.showActiveRoom,
    required this.maxSlots,
    required this.qrSize,
    required this.start,
    required this.staticUids,
  });

  final Set<String> staticUids;
  final RoomProvider provider;
  final String roomCode;
  final List<RoomPlayer> players;
  final bool showActiveRoom;
  final int? maxSlots;
  final double qrSize;
  final Widget? start;

  @override
  Widget build(BuildContext context) {
    final capacity = maxSlots ?? RoomLimits.defaultMaxPlayers;
    final emptySlots = maxSlots == null
        ? 0
        : math.max(0, maxSlots! - players.length);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Tooltip(
              message: 'QR 코드 확대',
              child: Semantics(
                button: true,
                label: 'QR 코드 확대',
                child: GestureDetector(
                  key: showActiveRoom
                      ? const Key('active-room-qr-expand')
                      : const Key('invite-room-qr-expand'),
                  onTap: () => _showExpandedQr(context, roomCode),
                  // 방이 생기면 코드 글자 뒤에 QR이 나타나고, 누르면 바로 이
                  // QR이 커져 확대 창이 됩니다(로비 연출 6번).
                  child: Builder(
                    // 확대 창이 이 QR 자리에서 커져 나옵니다.
                    builder: (qrContext) => GestureDetector(
                      onTap: () => _showExpandedQr(
                        qrContext,
                        roomCode,
                        origin: mosiOriginOf(qrContext),
                      ),
                      child: _QrEntrance(
                        roomCode: roomCode,
                        child: RoomQrCard(roomCode: roomCode, size: qrSize),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'JOIN ROOM',
                    style: MosiFonts.grotesk(
                      locale: Localizations.maybeLocaleOf(context),
                      size: 12,
                      color: MosiColors.navy,
                      letterSpacing: 2.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '휴대폰 카메라로 찍으면 바로 들어와요',
                    style: MosiFonts.sans(
                      locale: Localizations.maybeLocaleOf(context),
                      size: 14,
                      weight: FontWeight.w600,
                      color: MosiColors.navy,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '방 코드',
                    style: MosiFonts.sans(
                      locale: Localizations.maybeLocaleOf(context),
                      size: 12,
                      weight: FontWeight.w600,
                      color: MosiColors.navy,
                    ),
                  ),
                  const SizedBox(height: 2),
                  _CopyableRoomCode(
                    roomCode: roomCode,
                    fontSize: 28,
                    staggered: true,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const MosiDashedDivider(),
        const SizedBox(height: 14),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 8,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '플레이어',
                  style: MosiFonts.sans(
                    locale: Localizations.maybeLocaleOf(context),
                    size: 17,
                    weight: FontWeight.w700,
                    color: MosiColors.navy,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${players.length} / $capacity',
                  style: MosiFonts.grotesk(
                    locale: Localizations.maybeLocaleOf(context),
                    size: 15,
                    color: MosiColors.navy,
                  ),
                ),
              ],
            ),
            MosiButton(
              label: provider.isLoading
                  ? context.l10n.resetting
                  : context.l10n.reset,
              variant: MosiButtonVariant.outline,
              foreground: MosiColors.navy,
              height: 34,
              fontSize: 13,
              radius: 999,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              onPressed: provider.isLoading
                  ? null
                  : () {
                      if (!provider.isRemovingAnyPlayer) {
                        unawaited(provider.closeRoom());
                      }
                    },
            ),
          ],
        ),
        if (provider.errorMessage != null && players.isEmpty) ...[
          const SizedBox(height: 8),
          Text(
            provider.errorMessage!,
            style: MosiFonts.sans(
              locale: Localizations.maybeLocaleOf(context),
              size: 13,
              weight: FontWeight.w600,
              color: MosiColors.red,
            ),
          ),
        ],
        const SizedBox(height: 10),
        Expanded(
          child: !showActiveRoom && emptySlots == 0
              ? Center(
                  key: const Key('room-waiting-for-players'),
                  child: Text(
                    '친구들이 QR을 찍으면\n여기에 이름이 떠요',
                    textAlign: TextAlign.center,
                    style: MosiFonts.sans(
                      locale: Localizations.maybeLocaleOf(context),
                      size: 14,
                      weight: FontWeight.w600,
                      color: MosiColors.muted,
                      height: 1.45,
                    ),
                  ),
                )
              : _AnimatedPlayerList(
                  provider: provider,
                  players: players,
                  emptySlots: emptySlots,
                  staticUids: staticUids,
                ),
        ),
        if (start != null) ...[const SizedBox(height: 12), start!],
      ],
    );
  }
}

class _AnimatedPlayerList extends StatefulWidget {
  const _AnimatedPlayerList({
    required this.provider,
    required this.players,
    required this.emptySlots,
    required this.staticUids,
  });

  final RoomProvider provider;
  final List<RoomPlayer> players;
  final int emptySlots;

  /// 카드가 처음 그려질 때 이미 있던 참가자입니다. 이들은 미끄러져 들어오지
  /// 않고 제자리에 바로 보입니다(화면 전환으로 다시 그려질 때 포함).
  final Set<String> staticUids;

  @override
  State<_AnimatedPlayerList> createState() => _AnimatedPlayerListState();
}

class _AnimatedPlayerListState extends State<_AnimatedPlayerList> {
  final GlobalKey<SliverAnimatedListState> _listKey =
      GlobalKey<SliverAnimatedListState>();
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

    // 퇴장은 인덱스가 바뀌지 않도록 뒤에서부터 뺍니다.
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
        duration: _playerSlotOpenDuration,
      );
    }

    // 연결 상태·NEW 시간·삭제 로딩 같은 기존 항목의 최신 값도
    // 반영합니다. 인원수는 위 insert/remove와 이미 맞습니다.
    _players = List<RoomPlayer>.of(nextPlayers);
  }

  Widget _buildPlayerTile(RoomPlayer player) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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
    return CustomScrollView(
      slivers: [
        SliverAnimatedList(
          key: _listKey,
          initialItemCount: _players.length,
          itemBuilder: (context, index, animation) {
            final player = _players[index];
            return SizeTransition(
              sizeFactor: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
              alignment: Alignment.topCenter,
              child: _PlayerEntranceTransition(
                key: ValueKey('room-player-entrance-${player.uid}'),
                playerUid: player.uid,
                animate: !widget.staticUids.contains(player.uid),
                child: _buildPlayerTile(player),
              ),
            );
          },
        ),
        SliverList.builder(
          itemCount: widget.emptySlots,
          itemBuilder: (context, index) => const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: _EmptySeatRow(),
          ),
        ),
      ],
    );
  }
}

class _EmptySeatRow extends StatelessWidget {
  const _EmptySeatRow();

  @override
  Widget build(BuildContext context) {
    return MosiDashedBorder(
      color: MosiColors.navyFaint,
      child: Container(
        height: 46,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Text(
          '빈 자리',
          style: MosiFonts.sans(
            locale: Localizations.maybeLocaleOf(context),
            size: 14,
            weight: FontWeight.w600,
            color: MosiColors.navyDim,
          ),
        ),
      ),
    );
  }
}

/// 새 참가자 카드가 목록 오른쪽 끝 너머에서 제자리로 미끄러져 들어옵니다.
///
/// 이동 거리는 카드 폭 전체라 화면 밖에서 들어오는 것처럼 보이고, 끝에서
/// 천천히 멈춥니다. 목록이 가장자리를 자르므로 패널 밖으로 삐져나오지 않습니다.
class _PlayerEntranceTransition extends StatelessWidget {
  const _PlayerEntranceTransition({
    super.key,
    required this.playerUid,
    required this.child,
    this.animate = true,
  });

  final String playerUid;
  final Widget child;
  final bool animate;

  /// 빠르게 출발해 길게 감속합니다.
  static const Curve _slideCurve = Curves.easeOutQuint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final distance = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 320.0;
        return TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: animate ? 0 : 1, end: 1),
          duration: _playerEntranceDuration,
          child: child,
          builder: (context, value, child) {
            final slide = _slideCurve.transform(value);
            // 들어오는 앞부분에서 빨리 또렷해지게 합니다.
            final opacity = Curves.easeOut.transform(
              (value / 0.45).clamp(0.0, 1.0),
            );
            return Opacity(
              opacity: opacity,
              child: Transform.translate(
                key: ValueKey('room-player-motion-$playerUid'),
                offset: Offset(distance * (1 - slide), 0),
                child: child,
              ),
            );
          },
        );
      },
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
      alignment: Alignment.topCenter,
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

/// 방 코드 글자가 다 나온 뒤 QR이 살짝 커지며 나타납니다. 같은 방에서
/// 다시 그려질 때는 움직이지 않습니다.
class _QrEntrance extends StatelessWidget {
  const _QrEntrance({required this.roomCode, required this.child});

  final String roomCode;
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    key: ValueKey('qr-entrance-$roomCode'),
    tween: Tween(begin: 0, end: 1),
    duration: MosiMotion.of(context, const Duration(milliseconds: 760)),
    builder: (context, t, child) {
      // 앞의 0.44초는 코드 글자 차례, 뒤의 0.32초에 QR이 나타납니다.
      final q = Curves.easeOutCubic.transform(((t - 0.58) / 0.42).clamp(0, 1));
      return Opacity(
        opacity: q,
        child: Transform.scale(scale: 0.85 + 0.15 * q, child: child),
      );
    },
    child: child,
  );
}

Future<void> _showExpandedQr(
  BuildContext context,
  String roomCode, {
  Rect? origin,
}) {
  return showMosiDialog<void>(
    context: context,
    origin: origin,
    builder: (_) => _ExpandedRoomQrDialog(roomCode: roomCode),
  );
}

class _ExpandedRoomQrDialog extends StatelessWidget {
  const _ExpandedRoomQrDialog({required this.roomCode});

  final String roomCode;

  @override
  Widget build(BuildContext context) {
    final shortestSide = MediaQuery.sizeOf(context).shortestSide;
    final qrSize = (shortestSide * 0.52).clamp(240.0, 360.0);
    return ConstrainedBox(
      key: const Key('expanded-room-qr-dialog'),
      constraints: BoxConstraints(
        maxWidth: 460,
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      child: MosiDialogFrame(
        width: null,
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
        semanticLabel: '방 QR',
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    'JOIN ROOM',
                    style: MosiFonts.grotesk(
                      locale: Localizations.maybeLocaleOf(context),
                      size: 13,
                      color: MosiColors.navy,
                      letterSpacing: 2.5,
                    ),
                  ),
                  const Spacer(),
                  MosiIconButton(
                    icon: Icons.close_rounded,
                    tooltip: 'QR 확대 닫기',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              RoomQrCard(
                key: const Key('expanded-room-qr'),
                roomCode: roomCode,
                size: qrSize,
              ),
              const SizedBox(height: 18),
              Text(
                '방 코드',
                style: MosiFonts.sans(
                  locale: Localizations.maybeLocaleOf(context),
                  size: 14,
                  weight: FontWeight.w600,
                  color: MosiColors.navy,
                ),
              ),
              const SizedBox(height: 4),
              _CopyableRoomCode(
                roomCode: roomCode,
                fontSize: 64,
                alignment: Alignment.center,
              ),
              const SizedBox(height: 8),
              Text(
                'QR을 스캔하거나 방 코드를 눌러 복사하세요.',
                textAlign: TextAlign.center,
                style: MosiFonts.sans(
                  locale: Localizations.maybeLocaleOf(context),
                  size: 13,
                  color: MosiColors.muted,
                ),
              ),
            ],
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
    final player = widget.player;
    return SizedBox(
      height: 46,
      child: Row(
        children: [
          MosiFace(characterId: player.characterId, size: 38, ring: true),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    player.nickname,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MosiFonts.sans(
                      locale: Localizations.maybeLocaleOf(context),
                      size: 16,
                      weight: FontWeight.w700,
                      color: MosiColors.navy,
                    ),
                  ),
                ),
                if (_isNew) ...[
                  const SizedBox(width: 8),
                  Text(
                    'NEW',
                    style: MosiFonts.grotesk(
                      locale: Localizations.maybeLocaleOf(context),
                      size: 11,
                      color: MosiColors.red,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 6),
          // 좁은 카드에서는 상태 알약을 줄여 내보내기 단추가 밀려나지 않게 합니다.
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: player.isConnected
                  ? MosiPill(
                      label: context.l10n.ready,
                      background: MosiColors.lime,
                      borderColor: MosiColors.ink,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                    )
                  : MosiPill(
                      key: ValueKey('disconnected-player-${player.uid}'),
                      label: context.l10n.connectionLost,
                      color: MosiColors.red,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 36,
            height: 36,
            child: widget.isRemoving
                ? const Padding(
                    padding: EdgeInsets.all(9),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    tooltip: '내보내기',
                    padding: EdgeInsets.zero,
                    onPressed: widget.onRemove,
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: MosiColors.muted,
                    ),
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
class RoomQrCard extends StatelessWidget {
  const RoomQrCard({super.key, required this.roomCode, required this.size});

  final String roomCode;
  final double size;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 부모가 준 여유와 요청 크기 중 작은 쪽으로 한 변을 정합니다.
        // 무한 제약은 여유가 없다는 뜻이 아니므로 요청 크기를 그대로 씁니다.
        final available = math.min(constraints.maxWidth, constraints.maxHeight);
        final side = available.isFinite ? math.min(size, available) : size;
        final badge = side * 0.2;
        return SizedBox(
          width: side,
          height: side,
          child: Container(
            padding: EdgeInsets.all(side * 0.07),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: MosiColors.ink, width: 3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                QrImageView(
                  data: roomCode,
                  padding: EdgeInsets.zero,
                  errorCorrectionLevel: QrErrorCorrectLevel.H,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: MosiColors.navy,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: MosiColors.navy,
                  ),
                ),
                // 오류 정정 H 단계라 가운데를 가려도 읽힙니다.
                Container(
                  width: badge,
                  height: badge,
                  decoration: BoxDecoration(
                    color: MosiColors.lime,
                    borderRadius: BorderRadius.circular(badge * 0.2),
                    border: Border.all(color: MosiColors.ink, width: 2.5),
                  ),
                ),
              ],
            ),
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
    this.staggered = false,
  });

  final String roomCode;
  final double fontSize;
  final Alignment alignment;

  /// 새 방 코드가 생기면 글자가 한 자씩 차례로 또렷해집니다.
  final bool staggered;

  @override
  Widget build(BuildContext context) {
    final style = MosiFonts.grotesk(
      locale: Localizations.maybeLocaleOf(context),
      size: fontSize,
      color: MosiColors.navy,
      letterSpacing: fontSize * 0.18,
      height: 1,
    );
    return Semantics(
      button: true,
      label: '방 코드 $roomCode 복사',
      child: GestureDetector(
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
          child: staggered
              ? MosiStaggeredText(text: roomCode, style: style)
              : Text(roomCode, style: style),
        ),
      ),
    );
  }
}
