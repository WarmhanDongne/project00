import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:game_kit/mosi_ui/mosi_game_art.dart';
import 'package:project00/platform/home/phone/widgets/phone_game_card.dart';
import 'package:game_kit/core/diagnostics/crash_reporting.dart';
import 'package:game_kit/core/layout/app_orientation.dart';
import 'package:game_kit/core/layout/app_system_ui.dart';
import 'package:game_kit/widgets/critical_network_guard.dart';
import 'package:game_kit/core/error/user_error_message.dart';
import 'package:game_kit/template_game.dart';
import 'package:project00/game_assets/game_asset_prepare.dart';
import 'package:project00/platform/home/gamelist/models/game_info.dart';
import 'package:project00/platform/home/room/models/room_player.dart';
import 'package:project00/platform/home/phone/widgets/phone_room_leave_button.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';
import 'package:project00/platform/home/phone/widgets/phone_profile.dart';
import 'package:project00/platform/home/phone/widgets/phone_room_participant_list.dart';
import 'package:project00/platform/home/phone/widgets/controller_reconnect_guard.dart';
import 'package:project00/platform/home/phone/widgets/lobby_reconnect_guard.dart';
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
    // 방이 이미 끝났으면 낡은 playing 값입니다. 종료된 게임을 다시 열지 않습니다.
    if (widget.provider.isRoomFinished) return;
    final selectedGameId = widget.provider.selectedGameId;
    if (selectedGameId == null) return;
    final game = widget.provider.gameCatalog.find(selectedGameId);
    if (game == null) return;
    unawaited(_openGame(roomCode, game));
  }

  void _showStatusError(Object error) {
    if (!mounted) return;
    // 퇴장하면 내 참가자 노드가 사라져 game/public/status 읽기 권한도 함께
    // 사라집니다. 정상 퇴장으로 끝난 구독의 오류는 사용자 오류가 아닙니다.
    if (widget.provider.isLeaving || widget.provider.roomCode == null) return;
    final message = userErrorMessage(
      error,
      context: UserErrorContext.roomSubscription,
    );
    if (message == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openGame(String roomCode, TemplateGame game) async {
    if (_isOpeningGame || !mounted) return;
    _isOpeningGame = true;

    try {
      await prepareGameAssetsForPlay(game);
    } catch (error, stack) {
      CrashReporting.recordError(error, stack, reason: '휴대폰 게임 에셋 확인');
      _isOpeningGame = false;
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('게임 파일을 다운로드하지 못했습니다.')));
      return;
    }
    if (!mounted) {
      _isOpeningGame = false;
      return;
    }

    // 휴대폰 방향은 게임 등록 정보가 단일 기준입니다. 새 게임에서 화면마다
    // 임의로 방향을 정하지 말고 TemplateGame.phoneOrientation을 선언하세요.
    unawaited(AppSystemUi.enterGameFullscreen());
    unawaited(AppOrientation.applyPhoneGame(game.phoneOrientation));

    final leftRoom = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (gameContext) => CriticalNetworkGuard(
          provider: widget.provider,
          exitLabel: '게임과 그룹 나가기',
          onExit: () => unawaited(
            _leaveGameFromReconnect(gameContext: gameContext, game: game),
          ),
          child: ControllerReconnectGuard(
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
    // 시스템 뒤로가기로 이 화면만 닫히면 사용자는 로비에 있는데 서버에는
    // 참가자로 남습니다. 그 뒤 홈의 저장 세션 복원이 대기 화면을 다시 띄워
    // 방을 나온 것도 들어간 것도 아닌 상태가 됩니다. 나가려면 `그룹 나가기`를
    // 써야 하므로 뒤로가기는 삼킵니다(P-02).
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('그룹에서 나가려면 화면 위쪽의 나가기를 눌러주세요.'),
              duration: Duration(seconds: 2),
            ),
          );
      },
      child: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    return CriticalNetworkGuard(
      provider: widget.provider,
      onExit: () {
        unawaited(AppSystemUi.showPlatformSystemBars());
        Navigator.of(context).popUntil((route) => route.isFirst);
      },
      child: LobbyReconnectGuard(
        provider: widget.provider,
        onExit: () async {
          final left = await widget.provider.leaveRoom();
          if (!context.mounted || !left) return left;
          unawaited(AppSystemUi.showPlatformSystemBars());
          Navigator.of(context).popUntil((route) => route.isFirst);
          return true;
        },
        child: AnimatedBuilder(
          animation: widget.provider,
          builder: (context, _) {
            final selectedGameId = widget.provider.selectedGameId;
            // 게임이 끝난 방은 selectedGame이 그대로 남습니다. 종료 경로 어디에서도
            // 지우지 않기 때문입니다. 그 값만 보고 그리면 룰북과 `곧 시작합니다`가
            // 영원히 남아 대기실로 돌아오지 못합니다(P-02).
            //
            // 태블릿이 정리하기 전에도 화면이 갇히지 않도록 방 상태를 우선합니다.
            final hasSelectedGame =
                selectedGameId != null &&
                selectedGameId.isNotEmpty &&
                !widget.provider.isRoomFinished;
            final players = widget.provider.players
                .where((player) => player.isActive)
                .toList(growable: false);

            // 태블릿이 자리를 맞추는 동안에는 시안의 '자리 정하는 동안' 화면을
            // 보여 줍니다. 헤더(나가기)는 그대로 둡니다.
            final isSeating =
                hasSelectedGame && widget.provider.roomStatus == 'seating';
            if (isSeating) {
              return _PhoneSeatingView(
                provider: widget.provider,
                header:
                    widget.headerForTesting ??
                    _PhoneRoomHeader(
                      provider: widget.provider,
                      dark: true,
                      onPressed: () async {
                        final left = await widget.provider.leaveRoom();
                        if (!context.mounted || !left) return;
                        unawaited(AppSystemUi.showPlatformSystemBars());
                        Navigator.of(
                          context,
                        ).popUntil((route) => route.isFirst);
                      },
                    ),
              );
            }

            return Scaffold(
              backgroundColor: MosiColors.cream,
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
      ),
    );
  }
}

class _PhoneRoomHeader extends StatelessWidget {
  const _PhoneRoomHeader({
    required this.provider,
    required this.onPressed,
    this.dark = false,
  });

  final RoomProvider provider;
  final VoidCallback onPressed;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final code = provider.roomCode;
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: dark ? Colors.transparent : MosiColors.white,
        border: dark
            ? null
            : const Border(bottom: BorderSide(color: MosiColors.ink, width: 3)),
      ),
      child: Row(
        children: [
          PhoneRoomLeaveButton(provider: provider, onPressed: onPressed),
          const Spacer(),
          if (code != null) ...[
            Text(
              'ROOM $code',
              style: MosiFonts.grotesk(
                size: 13,
                color: dark ? MosiColors.white : MosiColors.navy,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(width: 12),
          ],
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
      padding: const EdgeInsets.fromLTRB(20, 16, 26, 28),
      children: [
        _WaitingStatusBanner(
          message: provider.isRoomFinished
              ? '게임이 끝났습니다. 태블릿에서 다음 게임을 고르는 중입니다'
              : '태블릿에서 게임을 선택하는 중입니다',
        ),
        const SizedBox(height: 20),
        PhoneRoomParticipantList(players: players),
        const SizedBox(height: 24),
        Text(
          '그룹이 보유 중인 게임',
          style: MosiFonts.sans(
            size: 19,
            weight: FontWeight.w700,
            color: MosiColors.navy,
          ),
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
            PlatformButton(
              label: '다시 시도',
              expand: false,
              style: PlatformButtonStyle.secondary,
              onPressed: provider.retryGroupGames,
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
          PhoneGameCard(gameInfo: game, inset: false),
      ],
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
                PlatformButton(
                  label: '다시 시도',
                  expand: false,
                  style: PlatformButtonStyle.secondary,
                  onPressed: provider.retrySelectedGame,
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
    final rules = gameInfo.rules.trim().isEmpty
        ? '게임 규칙을 준비 중입니다.'
        : gameInfo.rules;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 22, 26, 28),
      children: [
        Text(
          '그룹이 선택한 게임',
          style: MosiFonts.sans(size: 14, color: MosiColors.muted),
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final coverWidth = (constraints.maxWidth * 0.4).clamp(110.0, 170.0);
            final details = _SelectedGameSummary(gameInfo: gameInfo);
            final cover = MosiGameCover(
              gameId: gameInfo.id,
              width: coverWidth,
              fallbackName: gameInfo.name,
              fallbackImageUrl: gameInfo.imageUrl,
            );
            if (constraints.maxWidth < 330) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: cover),
                  const SizedBox(height: 18),
                  details,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                cover,
                const SizedBox(width: 20),
                Expanded(child: details),
              ],
            );
          },
        ),
        const SizedBox(height: 30),
        Text(
          '게임 규칙',
          style: MosiFonts.sans(
            size: 19,
            weight: FontWeight.w700,
            color: MosiColors.navy,
          ),
        ),
        const SizedBox(height: 12),
        MosiBox(
          padding: const EdgeInsets.all(16),
          shadowOffset: 5,
          child: Text(
            rules,
            style: MosiFonts.sans(
              size: 14,
              color: MosiColors.navy,
              height: 1.7,
            ),
          ),
        ),
      ],
    );
  }
}

class _SelectedGameSummary extends StatelessWidget {
  const _SelectedGameSummary({required this.gameInfo});

  final GameInfo gameInfo;

  @override
  Widget build(BuildContext context) {
    final art = MosiGameArt.of(gameInfo.id, fallbackName: gameInfo.name);
    final known = MosiGameArt.isKnown(gameInfo.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          known ? art.koreanName : gameInfo.name,
          style: MosiFonts.sans(
            size: 24,
            height: 1.15,
            weight: FontWeight.w700,
            color: MosiColors.navy,
          ),
        ),
        if (known)
          Text(
            art.englishName,
            style: MosiFonts.grotesk(
              size: 11,
              color: MosiColors.violet,
              letterSpacing: 2.5,
            ),
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            if (gameInfo.playTime > 0)
              PlatformTag(label: '${gameInfo.playTime}분'),
            if (gameInfo.minPlayers > 0)
              PlatformTag(
                label: '${gameInfo.minPlayers}–${gameInfo.maxPlayers}명',
              ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          gameInfo.description,
          style: MosiFonts.sans(
            color: MosiColors.muted,
            size: 13,
            height: 1.55,
          ),
        ),
      ],
    );
  }
}

class _StartingSoonBar extends StatelessWidget {
  const _StartingSoonBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 8, 26, 20),
      padding: const EdgeInsets.symmetric(vertical: 17),
      decoration: BoxDecoration(
        color: MosiColors.lime,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MosiColors.ink, width: 3),
        boxShadow: const [
          BoxShadow(color: MosiColors.navy, offset: Offset(5, 5)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: MosiColors.navy,
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              '곧 시작합니다',
              textAlign: TextAlign.center,
              style: MosiFonts.sans(
                color: MosiColors.navy,
                size: 16,
                weight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

//=======================자리 정하는 동안 (휴대폰)==============================
@immutable
class _SeatTheme {
  const _SeatTheme({
    required this.ground,
    required this.deep,
    required this.soft,
    required this.button,
  });

  final Color ground;
  final Color deep;
  final Color soft;
  final Color button;

  static _SeatTheme of(String? gameId) => switch (gameId) {
    'final_call' => const _SeatTheme(
      ground: Color(0xFF141414),
      deep: Colors.black,
      soft: Color(0xFFC9C6BC),
      button: Color(0xFFE5DB00),
    ),
    'mafia' => const _SeatTheme(
      ground: Color(0xFF10131A),
      deep: Colors.black,
      soft: Color(0xFFB9BDC9),
      button: Color(0xFFFF2A2A),
    ),
    _ => const _SeatTheme(
      ground: Color(0xFF4A1A5E),
      deep: Color(0xFF1B1022),
      soft: Color(0xFFE2D2E8),
      button: Color(0xFFF2C14E),
    ),
  };
}

class _PhoneSeatingView extends StatefulWidget {
  const _PhoneSeatingView({required this.provider, required this.header});

  final RoomProvider provider;
  final Widget header;

  @override
  State<_PhoneSeatingView> createState() => _PhoneSeatingViewState();
}

class _PhoneSeatingViewState extends State<_PhoneSeatingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dots = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _dots.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    final gameId = provider.selectedGameId;
    final theme = _SeatTheme.of(gameId);
    final game = provider.selectedGame;
    final art = MosiGameArt.of(gameId ?? '', fallbackName: game?.name);
    final gameName = gameId != null && MosiGameArt.isKnown(gameId)
        ? art.koreanName
        : game?.name ?? '게임';
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final me = provider.players
        .where((player) => player.uid == uid)
        .firstOrNull;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: theme.ground,
        body: CustomPaint(
          painter: _DotGridPainter(),
          child: SafeArea(
            child: Column(
              children: [
                widget.header,
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                    child: Column(
                      children: [
                        Text(
                          '$gameName · 대기실',
                          style: MosiFonts.sans(size: 14, color: theme.soft),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          '태블릿에서\n자리를 맞추고 있어요',
                          textAlign: TextAlign.center,
                          style: MosiFonts.sans(
                            size: 24,
                            weight: FontWeight.w700,
                            color: MosiColors.white,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 36),
                        MosiBox(
                          width: 240,
                          padding: const EdgeInsets.all(22),
                          radius: 18,
                          shadowOffset: 8,
                          shadowColor: theme.deep,
                          child: Column(
                            children: [
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: theme.deep,
                                      offset: const Offset(5, 5),
                                    ),
                                  ],
                                ),
                                child: MosiFace(
                                  characterId: me?.characterId,
                                  size: 104,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                me?.nickname ?? '',
                                style: MosiFonts.sans(
                                  size: 20,
                                  weight: FontWeight.w700,
                                  color: MosiColors.navy,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          '내 이름 카드가 내가 앉은 쪽에\n오면 돼요',
                          textAlign: TextAlign.center,
                          style: MosiFonts.sans(
                            size: 14,
                            color: theme.soft,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 30, 12),
                  child: MosiButton(
                    label: '태블릿에서 내 자리 찾기',
                    background: theme.button,
                    shadowColor: theme.deep,
                    shadowOffset: 6,
                    height: 60,
                    fontSize: 17,
                    radius: 12,
                    expand: true,
                    leading: const Icon(Icons.wifi_tethering_rounded),
                    onPressed: () => ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        const SnackBar(
                          content: Text('태블릿에서 내 카드 찾기는 준비 중이에요.'),
                        ),
                      ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: AnimatedBuilder(
                    animation: _dots,
                    builder: (context, _) {
                      final active = (_dots.value * 3).floor();
                      return Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(text: '방장이 완료를 누르면 시작해요 '),
                            for (var i = 0; i < 3; i++)
                              TextSpan(
                                text: '·',
                                style: TextStyle(
                                  color: theme.soft.withValues(
                                    alpha: i == active ? 1 : 0.25,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        style: MosiFonts.sans(size: 13, color: theme.soft),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x12FFFFFF);
    for (var y = 15.0; y < size.height; y += 30) {
      for (var x = 15.0; x < size.width; x += 30) {
        canvas.drawCircle(Offset(x, y), 2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
    return MosiDashedBorder(
      radius: 12,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: MosiColors.white,
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
                style: MosiFonts.sans(
                  color: MosiColors.navy,
                  size: 14,
                  weight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
