import 'dart:async';

import 'package:flutter/material.dart';
import 'package:project00/core/layout/app_orientation.dart';
import 'package:project00/core/layout/app_system_ui.dart';
import 'package:project00/core/network/critical_network_guard.dart';
import 'package:project00/games/template_game.dart';
import 'package:project00/games/game_registry.dart';
import 'package:project00/platform/home/gamelist/models/game_info.dart';
import 'package:project00/platform/home/room/models/room_player.dart';
import 'package:project00/platform/home/phone/widgets/phone_room_leave_button.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';
import 'package:project00/platform/home/phone/widgets/phone_profile.dart';
import 'package:project00/platform/home/phone/widgets/phone_room_participant_list.dart';
import 'package:project00/platform/home/phone/widgets/controller_reconnect_guard.dart';
import 'package:project00/platform/theme/platform_theme.dart';
import 'package:project00/platform/widgets/platform_components.dart';

class PhoneRoomWaiting extends StatefulWidget {
  const PhoneRoomWaiting({
    super.key,
    required this.provider,
    this.headerForTesting,
  });

  final RoomProvider provider;
  @visibleForTesting
  final Widget? headerForTesting;

  @override
  State<PhoneRoomWaiting> createState() => _PhoneRoomWaitingState();
}

class _PhoneRoomWaitingState extends State<PhoneRoomWaiting> {
  StreamSubscription<String?>? _gameStatusSubscription;
  String? _subscribedRoomCode;
  String? _latestGameStatus;
  bool _isOpeningGame = false;
  bool _isHandlingForcedExit = false;

  @override
  void initState() {
    super.initState();
    //=======================플랫폼 세로 화면 고정==============================
    unawaited(_lockPlatformPortrait());
    unawaited(AppSystemUi.showPlatformSystemBars());
    widget.provider.addListener(_onRoomProviderChanged);
    // 마운트 시점에 이미 추방/방 종료 상태면 핸들러가 ModalRoute.of를
    // 호출하므로, initState 완료 전에 실행하지 않고 첫 프레임 뒤로 미룹니다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onRoomProviderChanged();
    });
  }

  Future<void> _lockPlatformPortrait() => AppOrientation.lockPlatformPortrait();

  void _onRoomProviderChanged() {
    _syncGameStatusSubscription();

    final wasKicked = widget.provider.wasKicked;
    final wasRoomClosed = widget.provider.wasRoomClosed;

    if ((wasKicked || wasRoomClosed) && !_isHandlingForcedExit) {
      if (!mounted) return;
      _isHandlingForcedExit = true;
      final terminationReason = widget.provider.roomTerminationReason;
      widget.provider.acknowledgeRoomExit();

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              wasKicked
                  ? '방에서 추방되었습니다.'
                  : terminationReason == RoomTerminationReason.closed
                  ? '방장이 방을 종료했습니다.'
                  : '방을 찾을 수 없습니다',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      //================상태바 표시=================
      unawaited(AppSystemUi.showPlatformSystemBars());
      // 게임 라우트가 현재 화면이어도 대기 화면의 context는 같은 Navigator에
      // 남아 있습니다. 종료 신호를 버리지 않고 게임·대기 경로를 한 번에 닫습니다.
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  void _syncGameStatusSubscription() {
    final roomCode = widget.provider.roomCode;

    if (roomCode == null) {
      unawaited(_gameStatusSubscription?.cancel());
      _gameStatusSubscription = null;
      _subscribedRoomCode = null;
      _latestGameStatus = null;
      return;
    }

    if (_subscribedRoomCode == roomCode && _gameStatusSubscription != null) {
      _openGameIfReady(roomCode);
      return;
    }

    unawaited(_gameStatusSubscription?.cancel());
    _subscribedRoomCode = roomCode;
    _latestGameStatus = null;
    _gameStatusSubscription = widget.provider.watchGameStatus(roomCode).listen((
      status,
    ) {
      _latestGameStatus = status;
      _openGameIfReady(roomCode);
    }, onError: _showStatusError);
  }

  /// `selectedGame`과 `game/public/status`는 서로 다른 RTDB 경로이므로 도착
  /// 순서가 보장되지 않습니다. 두 값 중 어느 것이 먼저 와도 마지막 값을 보관했다가
  /// 모두 준비되는 순간 한 번만 게임 화면을 엽니다.
  void _openGameIfReady(String roomCode) {
    if (_latestGameStatus != 'playing' || _isOpeningGame || !mounted) return;
    final selectedGameId = widget.provider.selectedGameId;
    if (selectedGameId == null) return;
    final game = GameRegistry.find(selectedGameId);
    if (game == null) return;
    unawaited(_openGame(roomCode, game));
  }

  void _showStatusError(Object error) {
    if (!mounted) return;
    // 퇴장하면 내 참가자 노드가 사라져 game/public/status 읽기 권한도 함께
    // 사라집니다. 정상 퇴장으로 끝난 구독의 오류는 사용자 오류가 아닙니다.
    if (widget.provider.isLeaving || widget.provider.roomCode == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('게임 시작 상태를 확인하지 못했습니다: $error')));
  }

  Future<void> _openGame(String roomCode, TemplateGame game) async {
    if (_isOpeningGame || !mounted) return;
    _isOpeningGame = true;

    // 휴대폰 방향은 게임 등록 정보가 단일 기준입니다. 새 게임에서 화면마다
    // 임의로 방향을 정하지 말고 TemplateGame.phoneOrientation을 선언하세요.
    unawaited(AppSystemUi.enterGameFullscreen());
    unawaited(AppOrientation.applyPhoneGame(game.phoneOrientation));

    final leftRoom = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (gameContext) => ControllerReconnectGuard(
          provider: widget.provider,
          onExit: () => unawaited(
            _leaveGameFromReconnect(gameContext: gameContext, game: game),
          ),
          child: game.buildPhoneScreen(
            roomCode: roomCode,
            provider: widget.provider,
            onExitRoom: () => widget.provider.leaveGame(game.id),
          ),
        ),
      ),
    );

    _isOpeningGame = false;
    if (!mounted) return;
    if (leftRoom == true) {
      // 참여 코드·닉네임·방 대기 경로를 모두 닫아 휴대폰 홈으로 이동합니다.
      //================상태바 표시=================
      unawaited(AppSystemUi.showPlatformSystemBars());
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
    // 화면 전환을 회전 응답보다 먼저 끝내 퇴장 성공 후 이전 화면에 갇히지
    // 않게 합니다. 방향 복원은 플랫폼 채널 응답을 기다리지 않습니다.
    unawaited(AppSystemUi.showPlatformSystemBars());
    unawaited(_lockPlatformPortrait());
  }

  Future<void> _leaveGameFromReconnect({
    required BuildContext gameContext,
    required TemplateGame game,
  }) async {
    final left = await widget.provider.leaveGame(game.id);
    if (!gameContext.mounted || !left) return;
    Navigator.of(gameContext).pop(true);
  }

  @override
  void dispose() {
    widget.provider.removeListener(_onRoomProviderChanged);
    _gameStatusSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CriticalNetworkGuard(
      provider: widget.provider,
      onExit: () {
        unawaited(AppSystemUi.showPlatformSystemBars());
        Navigator.of(context).popUntil((route) => route.isFirst);
      },
      child: AnimatedBuilder(
        animation: widget.provider,
        builder: (context, _) {
          final selectedGameId = widget.provider.selectedGameId;
          final hasSelectedGame =
              selectedGameId != null && selectedGameId.isNotEmpty;
          final players = widget.provider.players
              .where((player) => player.isActive)
              .toList(growable: false);

          return Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                  widget.headerForTesting ??
                      _PhoneRoomHeader(
                        provider: widget.provider,
                        onPressed: () async {
                          final left = await widget.provider.leaveRoom();
                          if (!context.mounted || !left) return;
                          //================상태바 표시=================
                          unawaited(AppSystemUi.showPlatformSystemBars());
                          Navigator.of(
                            context,
                          ).popUntil((route) => route.isFirst);
                        },
                      ),
                  if (widget.provider.controllerPresenceState ==
                      ControllerPresenceState.reconnecting)
                    const _ControllerReconnectBanner(),
                  if (hasSelectedGame) ...[
                    Expanded(
                      child: _SelectedGameContent(provider: widget.provider),
                    ),
                    const _StartingSoonBar(),
                  ] else
                    Expanded(
                      child: _GroupWaitingContent(
                        provider: widget.provider,
                        players: players,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ControllerReconnectBanner extends StatelessWidget {
  const _ControllerReconnectBanner();

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    return Semantics(
      liveRegion: true,
      label: '태블릿 재접속 대기 중',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        color: colors.primary.withValues(alpha: 0.12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '태블릿 재접속 대기 중',
              style: TextStyle(
                color: colors.text,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhoneRoomHeader extends StatelessWidget {
  const _PhoneRoomHeader({required this.provider, required this.onPressed});

  final RoomProvider provider;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          PhoneRoomLeaveButton(provider: provider, onPressed: onPressed),
          const Spacer(),
          const PhoneProfile(),
        ],
      ),
    );
  }
}

class _GroupWaitingContent extends StatelessWidget {
  const _GroupWaitingContent({required this.provider, required this.players});

  final RoomProvider provider;
  final List<RoomPlayer> players;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        const _WaitingStatusBanner(message: '태블릿에서 게임을 선택하는 중입니다'),
        const SizedBox(height: 20),
        PhoneRoomParticipantList(players: players),
        const SizedBox(height: 24),
        const Text(
          '그룹이 보유 중인 게임',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        _GroupGamesContent(provider: provider),
        if (provider.errorMessage != null) ...[
          const SizedBox(height: 12),
          PlatformNotice(
            message: provider.errorMessage!,
            style: PlatformNoticeStyle.danger,
          ),
        ],
      ],
    );
  }
}

class _GroupGamesContent extends StatelessWidget {
  const _GroupGamesContent({required this.provider});

  final RoomProvider provider;

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    if (provider.groupGamesLoadStatus == RoomDataLoadStatus.idle ||
        provider.groupGamesLoadStatus == RoomDataLoadStatus.loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (provider.groupGamesLoadStatus == RoomDataLoadStatus.failure) {
      return PlatformPanel(
        child: Column(
          children: [
            Text(
              provider.groupGamesError ?? '게임 목록을 불러오지 못했습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textMuted),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: provider.retryGroupGames,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }
    if (provider.groupGames.isEmpty) {
      return PlatformPanel(
        child: Text(
          '그룹이 보유한 게임이 없습니다.',
          style: TextStyle(color: colors.textMuted),
        ),
      );
    }
    return Column(
      children: [
        for (final game in provider.groupGames)
          _WaitingGameCard(gameInfo: game),
      ],
    );
  }
}

class _WaitingGameCard extends StatelessWidget {
  const _WaitingGameCard({required this.gameInfo});

  final GameInfo gameInfo;

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    final metadata = [
      '${gameInfo.playTime}분',
      '${gameInfo.minPlayers}~${gameInfo.maxPlayers}인',
      ...gameInfo.genres,
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surfaceMuted,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            _GameCover(gameInfo: gameInfo, size: 96),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    gameInfo.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    metadata,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    gameInfo.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.textMuted, fontSize: 12),
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

class _SelectedGameContent extends StatelessWidget {
  const _SelectedGameContent({required this.provider});

  final RoomProvider provider;

  @override
  Widget build(BuildContext context) {
    final game = provider.selectedGame;
    if (game != null) return _SelectedGameDetails(gameInfo: game);

    if (provider.selectedGameLoadStatus == RoomDataLoadStatus.failure) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: PlatformPanel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  provider.selectedGameError ?? '게임 정보를 불러오지 못했습니다.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: provider.retrySelectedGame,
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return const Center(child: CircularProgressIndicator());
  }
}

class _SelectedGameDetails extends StatelessWidget {
  const _SelectedGameDetails({required this.gameInfo});

  final GameInfo gameInfo;

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    final rules = gameInfo.rules.trim().isEmpty
        ? '게임 규칙을 준비 중입니다.'
        : gameInfo.rules;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
      children: [
        Text(
          '그룹이 선택한 게임',
          style: TextStyle(color: colors.textMuted, fontSize: 14),
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final coverSize = (constraints.maxWidth * 0.48).clamp(142.0, 210.0);
            final details = _SelectedGameSummary(gameInfo: gameInfo);
            if (constraints.maxWidth < 330) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: _GameCover(gameInfo: gameInfo, size: coverSize),
                  ),
                  const SizedBox(height: 18),
                  details,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _GameCover(gameInfo: gameInfo, size: coverSize),
                const SizedBox(width: 16),
                Expanded(child: details),
              ],
            );
          },
        ),
        const SizedBox(height: 30),
        const Text(
          '게임 규칙',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        Text(rules, style: const TextStyle(fontSize: 14, height: 1.7)),
      ],
    );
  }
}

class _SelectedGameSummary extends StatelessWidget {
  const _SelectedGameSummary({required this.gameInfo});

  final GameInfo gameInfo;

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          gameInfo.name,
          style: const TextStyle(
            fontSize: 24,
            height: 1.15,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            PlatformTag(label: '${gameInfo.playTime}분'),
            PlatformTag(
              label: '${gameInfo.minPlayers}~${gameInfo.maxPlayers}인',
            ),
            for (final genre in gameInfo.genres)
              PlatformTag(label: genre, highlighted: true),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          gameInfo.description,
          style: TextStyle(color: colors.textMuted, fontSize: 13, height: 1.55),
        ),
      ],
    );
  }
}

class _GameCover extends StatelessWidget {
  const _GameCover({required this.gameInfo, required this.size});

  final GameInfo gameInfo;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    Widget fallback(IconData icon) => Container(
      width: size,
      height: size,
      color: colors.surfaceMuted,
      alignment: Alignment.center,
      child: Icon(icon, color: colors.textMuted),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: gameInfo.imageUrl.isEmpty
          ? fallback(Icons.image_outlined)
          : Image.network(
              gameInfo.imageUrl,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback(Icons.broken_image_outlined),
            ),
    );
  }
}

class _StartingSoonBar extends StatelessWidget {
  const _StartingSoonBar();

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      padding: const EdgeInsets.symmetric(vertical: 17),
      decoration: BoxDecoration(
        color: colors.primarySoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              '곧 시작합니다',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.primary,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WaitingStatusBanner extends StatefulWidget {
  const _WaitingStatusBanner({required this.message});

  final String message;

  @override
  State<_WaitingStatusBanner> createState() => _WaitingStatusBannerState();
}

class _WaitingStatusBannerState extends State<_WaitingStatusBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.primarySoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final activeIndex = (_controller.value * 3).floor().clamp(0, 2);
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  3,
                  (index) => Container(
                    key: ValueKey('waiting-dot-$index'),
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: index == activeIndex
                          ? colors.primary
                          : colors.primary.withValues(alpha: 0.22),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.message,
              style: TextStyle(
                color: colors.primary,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
